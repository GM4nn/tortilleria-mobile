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
          setState(() => _pendingMode = m == 'on');
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

  void _onGenerate(String jsonData) {
    try {
      final data = Map<String, dynamic>.from(
        // ignore: avoid_dynamic_calls
        (jsonDecode(jsonData) as Map).map((k, v) => MapEntry(k.toString(), v)),
      );
      final id = (data['customer_id'] as num?)?.toInt();
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      final name = data['name'] as String? ?? 'este cliente';
      if (id == null) return;
      if (_pendingMode) {
        _openCustomerHistory(id);
      } else {
        _showGreyCustomerDialog(id, name, lat, lng);
      }
    } catch (_) {
      // Fallback: parse as plain customer_id
      final id = int.tryParse(jsonData);
      if (id == null) return;
      if (_pendingMode) {
        _openCustomerHistory(id);
        return;
      }
      final c = _customers.firstWhere((x) => x.id == id, orElse: () => _customers.first);
      _showGreyCustomerDialog(id, c.name, c.lat, c.lng);
    }
  }

  void _showGreyCustomerDialog(int customerId, String name, double? lat, double? lng) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name),
        content: const Text('Este cliente no tiene pedido hoy.'),
        actions: [
          if (lat != null && lng != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                final uri = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1&travelmode=driving'
                  '&destination=$lat,$lng',
                );
                launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.directions, size: 18),
              label: const Text('Cómo llegar'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmGenerate(customerId, name);
            },
            child: const Text('Generar pedido'),
          ),
        ],
      ),
    );
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

  void _onPinTapped(String customerIdStr) {
    final id = int.tryParse(customerIdStr);
    if (id == null) return;

    if (_pendingMode) {
      _openCustomerHistory(id);
    } else {
      final customerOrders = _orders.where((o) => o.customerId == id).toList();
      if (customerOrders.isEmpty) {
        _toast('No hay pedido activo para este cliente');
        return;
      }
      _showCurrentOrder(customerOrders.first);
    }
  }

  Future<void> _openCustomerHistory(int customerId) async {
    final customers = _customers.where((c) => c.id == customerId).toList();
    final customerName = customers.isNotEmpty ? customers.first.name : 'Cliente';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final allOrders = await _orderService.fetchOrdersByCustomer(customerId);
      if (!mounted) return;
      Navigator.pop(context); // quitar loading

      if (allOrders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontraron pedidos para este cliente')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerOrdersScreen(
            customerName: customerName,
            orders: allOrders,
            customers: _customers,
            catalog: _catalogFor(allOrders.first),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar pedidos del cliente')),
      );
    }
  }

  void _showCurrentOrder(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CurrentOrderSheet(
        order: order,
        currentDealer: Session.instance.username,
        customers: _customers,
        catalog: _catalogFor(order),
      ),
    );
  }

  void _togglePendingMode() {
    setState(() => _pendingMode = !_pendingMode);
    _controller!.runJavaScript('togglePendingMode()');
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
}

/// Bottom sheet que muestra la OrderCard del pedido actual con sus acciones
/// (completar, pagar, tomar, notas).
class _CurrentOrderSheet extends StatefulWidget {
  final OrderModel order;
  final String? currentDealer;
  final List<CustomerModel> customers;
  final List<CatalogProduct> catalog;

  const _CurrentOrderSheet({
    required this.order,
    required this.currentDealer,
    required this.customers,
    required this.catalog,
  });

  @override
  State<_CurrentOrderSheet> createState() => _CurrentOrderSheetState();
}

class _CurrentOrderSheetState extends State<_CurrentOrderSheet> {
  late OrderModel _order;
  final _apiService = ApiService();
  final _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  OrderModel get _current => _order;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(12),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            OrderCard(
              order: _current,
              currentDealer: widget.currentDealer,
              onComplete: () => _completeOrder(),
              onPayment: () => _registerPayment(),
              onTake: () => _takeOrder(),
              onNotes: () => _editNotes(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<CatalogProduct> get _catalog {
    CustomerModel? c;
    for (final x in widget.customers) {
      if (x.id == _current.customerId) {
        c = x;
        break;
      }
    }
    final prices = c?.prices ?? const {};
    return widget.catalog
        .map((p) => CatalogProduct(
              productId: p.productId,
              name: p.name,
              icon: p.icon,
              price: prices[p.productId] ?? p.price,
            ))
        .toList();
  }

  Future<void> _takeOrder() async {
    final username = Session.instance.username;
    if (username == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tomar Pedido'),
        content: Text('¿Tomar el pedido de ${_current.customerName} y asignártelo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, tomar')),
        ],
      ),
    );

    if (confirm != true) return;
    await _orderService.takeOrder(_current.orderId, username);
    setState(() {
      _order = OrderModel(
        orderId: _order.orderId,
        customerName: _order.customerName,
        customerId: _order.customerId,
        items: _order.items,
        total: _order.total,
        amountPaid: _order.amountPaid,
        status: _order.status,
        createdAt: _order.createdAt,
        notes: _order.notes,
        defaultDealer: username,
        customerLat: _order.customerLat,
        customerLng: _order.customerLng,
        customerDirection: _order.customerDirection,
        routeId: _order.routeId,
        routeName: _order.routeName,
        routeColor: _order.routeColor,
        routeDealers: _order.routeDealers,
        deliveryTime: _order.deliveryTime,
        shopLat: _order.shopLat,
        shopLng: _order.shopLng,
      );
    });
    _toast('Pedido tomado');
  }

  Future<void> _registerPayment() async {
    final amount = await PaymentDialog.show(context, _current);
    if (amount == null) return;

    final newTotal = _current.amountPaid + amount;
    try {
      await _apiService.registerPayment(_current.orderId, newTotal);
      await _orderService.registerPayment(_current.orderId, newTotal);
    } on ApiException catch (e) {
      _toast(e.message);
      return;
    } catch (_) {
      _toast('No se pudo registrar el pago. Revisa tu conexión.');
      return;
    }
    setState(() {
      _order = OrderModel(
        orderId: _order.orderId,
        customerName: _order.customerName,
        customerId: _order.customerId,
        items: _order.items,
        total: _order.total,
        amountPaid: newTotal,
        status: _order.status,
        createdAt: _order.createdAt,
        notes: _order.notes,
        defaultDealer: _order.defaultDealer,
        customerLat: _order.customerLat,
        customerLng: _order.customerLng,
        customerDirection: _order.customerDirection,
        routeId: _order.routeId,
        routeName: _order.routeName,
        routeColor: _order.routeColor,
        routeDealers: _order.routeDealers,
        deliveryTime: _order.deliveryTime,
        shopLat: _order.shopLat,
        shopLng: _order.shopLng,
      );
    });
    _toast('Pago registrado');
  }

  Future<void> _editNotes() async {
    final notes = await NotesDialog.show(context, _current);
    if (notes == null) return;

    try {
      await _apiService.updateNotes(_current.orderId, notes);
      await _orderService.updateNotes(_current.orderId, notes);
    } on ApiException catch (e) {
      _toast(e.message);
      return;
    } catch (_) {
      _toast('No se pudo guardar la nota. Revisa tu conexión.');
      return;
    }
    setState(() {
      _order = OrderModel(
        orderId: _order.orderId,
        customerName: _order.customerName,
        customerId: _order.customerId,
        items: _order.items,
        total: _order.total,
        amountPaid: _order.amountPaid,
        status: _order.status,
        createdAt: _order.createdAt,
        notes: notes,
        defaultDealer: _order.defaultDealer,
        customerLat: _order.customerLat,
        customerLng: _order.customerLng,
        customerDirection: _order.customerDirection,
        routeId: _order.routeId,
        routeName: _order.routeName,
        routeColor: _order.routeColor,
        routeDealers: _order.routeDealers,
        deliveryTime: _order.deliveryTime,
        shopLat: _order.shopLat,
        shopLng: _order.shopLng,
      );
    });
    _toast('Nota guardada');
  }

  Future<void> _completeOrder() async {
    final result = await DeliveryDialog.show(
      context,
      _current,
      catalog: _catalog,
    );
    if (result == null) return;

    try {
      await _apiService.completeDelivery(
        _current.orderId,
        result.items,
        result.total,
        result.amountPaid,
        complete: result.complete,
      );
      if (result.complete) {
        await _orderService.completeWithDelivery(
          _current.orderId,
          result.items,
          result.total,
          result.amountPaid,
        );
      } else {
        await _orderService.saveDelivery(
          _current.orderId,
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
    if (result.complete) {
      if (mounted) Navigator.pop(context);
    }
    _toast(result.complete ? 'Entrega y pago guardados' : 'Info guardada');
  }
}
