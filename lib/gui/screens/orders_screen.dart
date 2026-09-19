import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/utils/route_order.dart';
import '../../data/models/catalog_product.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/order_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/customer_service.dart';
import '../../data/services/order_service.dart';
import '../../data/services/product_service.dart';
import '../../data/services/session.dart';
import '../widgets/delivery_dialog.dart';
import '../widgets/notes_dialog.dart';
import '../widgets/order_card.dart';
import '../widgets/payment_dialog.dart';
import 'pending_customer_orders_screen.dart';

/// Vista principal de una ruta: el MAPA con las paradas en orden (más cercano →
/// más lejano desde la tortillería). Traza la ruta desde el GPS del repartidor,
/// abre la ruta completa en Google Maps, y al tocar un pin muestra la card del
/// pedido (con sus acciones de completar/pagar).
class OrdersScreen extends StatefulWidget {
  final String routeName;
  final String? routeColor;

  const OrdersScreen({super.key, required this.routeName, this.routeColor});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _orderService = OrderService();
  final _customerService = CustomerService();
  final _productService = ProductService();
  final _apiService = ApiService();

  WebViewController? _controller;
  StreamSubscription<List<OrderModel>>? _sub;
  StreamSubscription<List<CustomerModel>>? _custSub;
  StreamSubscription<List<CatalogProduct>>? _prodSub;
  StreamSubscription<Position>? _posSub;
  List<OrderModel> _orders = [];
  List<CustomerModel> _customers = [];
  List<CatalogProduct> _products = [];
  Position? _gps;
  bool _mapReady = false;
  bool _pendingMode = false;

  @override
  void initState() {
    super.initState();
    _initMap();
    _initGps();
    _sub = _orderService.watchOrders().listen((data) {
      _orders = _applyLocalFilters(data);
      _pushStops();
      _pushPending();
    });
    _custSub = _customerService.watchCustomers().listen((data) {
      _customers = data;
      _pushPending();
    });
    _prodSub = _productService.watchProducts().listen((data) {
      _products = data;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _custSub?.cancel();
    _prodSub?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  // Solo los pedidos de este repartidor y de esta ruta, ordenados por cercanía.
  List<OrderModel> _applyLocalFilters(List<OrderModel> orders) {
    final me = Session.instance.username;
    final noRoute = widget.routeName == 'Sin ruta';
    final filtered = orders.where((o) {
      if (!o.visibleTo(me)) return false;
      final rn = (o.routeName == null || o.routeName!.isEmpty)
          ? 'Sin ruta'
          : o.routeName!;
      return noRoute ? rn == 'Sin ruta' : rn == widget.routeName;
    }).toList();
    return orderByNearest(filtered);
  }

  void _initMap() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFE5E7EB))
      ..addJavaScriptChannel(
        'MapChannel',
        onMessageReceived: (msg) {
          final uri = Uri.tryParse(msg.message);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      )
      ..addJavaScriptChannel(
        'OrderChannel',
        onMessageReceived: (msg) => _onPinTapped(msg.message),
      )
      ..addJavaScriptChannel(
        'GenerateChannel',
        onMessageReceived: (msg) => _onGenerate(msg.message),
      )
      ..addJavaScriptChannel(
        'PendingChannel',
        onMessageReceived: (msg) {
          final m = msg.message;
          if (m == 'on' || m == 'off') {
            setState(() => _pendingMode = m == 'on');
          } else {
            _onPendingTapped(m);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _mapReady = true;
            _pushStops();
            _pushPending();
            _pushStart();
          },
        ),
      )
      ..loadFlutterAsset('assets/route_map.html');
  }

  Future<void> _initGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      // Posición inicial
      _gps = await Geolocator.getCurrentPosition();
      _pushStart();

      // Seguimiento en vivo: mueve el punto azul mientras el repartidor avanza
      _posSub?.cancel();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15, // solo actualiza al moverse ~15 m (cuida batería)
        ),
      ).listen((pos) {
        _gps = pos;
        _pushStart();
      });
    } catch (_) {
      // Sin GPS: el mapa sigue funcionando; Google Maps usará la ubicación del teléfono
    }
  }

  void _pushStops() {
    if (!_mapReady || _controller == null) return;
    final stops =
        _orders.where((o) => o.hasLocation).map((o) => o.toMapStop()).toList();
    final payload = jsonEncode(jsonEncode(stops));
    _controller!.runJavaScript('setStops($payload);');
  }

  void _pushStart() {
    if (!_mapReady || _controller == null || _gps == null) return;
    _controller!.runJavaScript(
      'setStart(${_gps!.latitude}, ${_gps!.longitude});',
    );
  }

  // Clientes de esta ruta que aún NO tienen pedido hoy → pines grises
  void _pushPending() {
    if (!_mapReady || _controller == null) return;
    final me = Session.instance.username;
    final noRoute = widget.routeName == 'Sin ruta';
    // Clientes que YA tienen pedido hoy: por id y, como respaldo, por nombre
    // (para pedidos viejos cuyo doc aún no traía customer_id).
    final withOrderIds =
        _orders.map((o) => o.customerId).whereType<int>().toSet();
    final withOrderNames = _orders
        .map((o) => o.customerName.trim().toLowerCase())
        .where((n) => n.isNotEmpty)
        .toSet();
    final pending = _customers.where((c) {
      if (!c.hasLocation) return false;
      if (withOrderIds.contains(c.id)) return false;
      if (withOrderNames.contains(c.name.trim().toLowerCase())) return false;
      final rn = (c.routeName == null || c.routeName!.isEmpty)
          ? 'Sin ruta'
          : c.routeName!;
      if (noRoute) return rn == 'Sin ruta';
      return rn == widget.routeName && c.routeDealers.contains(me);
    }).map((c) => {
          'customer_id': c.id,
          'name': c.name,
          'lat': c.lat,
          'lng': c.lng,
        }).toList();
    final payload = jsonEncode(jsonEncode(pending));
    _controller!.runJavaScript('setPending($payload);');
  }

  void _onGenerate(String customerIdStr) {
    final id = int.tryParse(customerIdStr);
    if (id == null) return;
    CustomerModel? customer;
    for (final c in _customers) {
      if (c.id == id) {
        customer = c;
        break;
      }
    }
    _confirmGenerate(id, customer?.name ?? 'este cliente');
  }

  Future<void> _confirmGenerate(int customerId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generar pedido de hoy'),
        content: Text('¿Crear el pedido de hoy para $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, crear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _toast('Generando pedido de $name...');
    try {
      await _apiService.generateOrder(customerId);
      // El pedido aparece solo en el mapa vía el stream de Firestore
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('No se pudo generar el pedido. Revisa tu conexión.');
    }
  }

  void _onPinTapped(String orderIdStr) {
    final id = int.tryParse(orderIdStr);
    if (id == null) return;
    OrderModel? order;
    for (final o in _orders) {
      if (o.orderId == id) {
        order = o;
        break;
      }
    }
    if (order == null) return;
    _showCard(order);
  }

  void _onPendingTapped(String customerIdStr) {
    final id = int.tryParse(customerIdStr);
    if (id == null) return;
    final pendingOrders = _orders.where((o) =>
        o.customerId == id &&
        o.status == 'pendiente' &&
        o.amountPaid < o.total).toList();
    if (pendingOrders.isEmpty) return;
    final customerName = pendingOrders.first.customerName;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PendingCustomerOrdersScreen(
          customerName: customerName,
          orders: pendingOrders,
          customers: _customers,
          catalog: _catalogFor(pendingOrders.first),
        ),
      ),
    );
  }

  void _togglePendingMode() {
    setState(() => _pendingMode = !_pendingMode);
    _controller!.runJavaScript('togglePendingMode()');
  }

  void _showCard(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => SingleChildScrollView(
        // Respeta la barra de gestos/área segura para que la card no quede pegada
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          24 + MediaQuery.of(sheetCtx).viewPadding.bottom,
        ),
        child: OrderCard(
          order: order,
          currentDealer: Session.instance.username,
          onComplete: () => _completeOrder(order, sheetCtx),
          onPayment: () => _registerPayment(order, sheetCtx),
          onTake: () => _takeOrder(order, sheetCtx),
          onNotes: () => _editNotes(order, sheetCtx),
          onNavigate: () => _navigateTo(order),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routeName),
        actions: [
          IconButton(
            icon: Icon(
              Icons.pending_actions,
              color: _pendingMode ? Colors.orange : null,
            ),
            tooltip: 'Pendientes',
            onPressed: _togglePendingMode,
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Mi ubicación',
            onPressed: _initGps,
          ),
        ],
      ),
      body: _controller == null
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _controller!),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _takeOrder(OrderModel order, BuildContext sheetCtx) async {
    final username = Session.instance.username;
    if (username == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tomar Pedido'),
        content: Text('¿Tomar el pedido de ${order.customerName} y asignártelo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, tomar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _orderService.takeOrder(order.orderId, username);
    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
    _toast('Pedido tomado');
  }

  Future<void> _registerPayment(OrderModel order, BuildContext sheetCtx) async {
    final amount = await PaymentDialog.show(context, order);
    if (amount == null) return;

    final newTotal = order.amountPaid + amount;
    try {
      await _apiService.registerPayment(order.orderId, newTotal); // SQLite
      await _orderService.registerPayment(order.orderId, newTotal); // Firestore
    } on ApiException catch (e) {
      _toast(e.message);
      return;
    } catch (_) {
      _toast('No se pudo registrar el pago. Revisa tu conexión.');
      return;
    }
    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
    _toast('Pago registrado');
  }

  // Ruta a un solo cliente en Google Maps (coordenada exacta desde tu ubicación)
  Future<void> _navigateTo(OrderModel order) async {
    if (!order.hasLocation) {
      _toast('Este cliente no tiene ubicación');
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&travelmode=driving'
      '&destination=${order.customerLat},${order.customerLng}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _editNotes(OrderModel order, BuildContext sheetCtx) async {
    final notes = await NotesDialog.show(context, order);
    if (notes == null) return; // canceló

    try {
      await _apiService.updateNotes(order.orderId, notes); // SQLite
      await _orderService.updateNotes(order.orderId, notes); // Firestore
    } on ApiException catch (e) {
      _toast(e.message);
      return;
    } catch (_) {
      _toast('No se pudo guardar la nota. Revisa tu conexión.');
      return;
    }
    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
    _toast('Nota guardada');
  }

  // Catálogo para "Agregar producto": productos globales con el precio del
  // cliente (mapa 'prices' del cliente); si no tiene, precio base.
  List<CatalogProduct> _catalogFor(OrderModel order) {
    CustomerModel? c;
    for (final x in _customers) {
      if (x.id == order.customerId) {
        c = x;
        break;
      }
    }
    final prices = c?.prices ?? const {};
    return _products
        .map((p) => CatalogProduct(
              productId: p.productId,
              name: p.name,
              icon: p.icon,
              price: prices[p.productId] ?? p.price,
            ))
        .toList();
  }

  Future<void> _completeOrder(OrderModel order, BuildContext sheetCtx) async {
    // Cierre de entrega: ajustar kilos entregados/devueltos y cobrar el neto
    final result =
        await DeliveryDialog.show(context, order, catalog: _catalogFor(order));
    if (result == null) return;

    try {
      // SQLite (fuente de verdad)
      await _apiService.completeDelivery(
        order.orderId,
        result.items,
        result.total,
        result.amountPaid,
        complete: result.complete,
      );
      // Firestore (mapa en tiempo real)
      if (result.complete) {
        await _orderService.completeWithDelivery(
          order.orderId,
          result.items,
          result.total,
          result.amountPaid,
        );
      } else {
        await _orderService.saveDelivery(
          order.orderId,
          result.items,
          result.total,
          result.amountPaid,
        );
      }
    } on ApiException catch (e) {
      _toast(e.message);
      return;
    } catch (_) {
      _toast('No se pudo guardar. Revisa tu conexión.');
      return;
    }
    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
    _toast(result.complete ? 'Entrega y pago guardados' : 'Info guardada');
  }
}
