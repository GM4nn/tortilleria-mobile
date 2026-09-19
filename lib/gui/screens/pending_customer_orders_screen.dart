import 'package:flutter/material.dart';

import '../../data/models/catalog_product.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/order_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/order_service.dart';
import '../../data/services/session.dart';
import '../widgets/delivery_dialog.dart';
import '../widgets/notes_dialog.dart';
import '../widgets/order_card.dart';
import '../widgets/payment_dialog.dart';

class PendingCustomerOrdersScreen extends StatefulWidget {
  final String customerName;
  final List<OrderModel> orders;
  final List<CustomerModel> customers;
  final List<CatalogProduct> catalog;

  const PendingCustomerOrdersScreen({
    super.key,
    required this.customerName,
    required this.orders,
    required this.customers,
    required this.catalog,
  });

  @override
  State<PendingCustomerOrdersScreen> createState() =>
      _PendingCustomerOrdersScreenState();
}

class _PendingCustomerOrdersScreenState
    extends State<PendingCustomerOrdersScreen> {
  final _apiService = ApiService();
  final _orderService = OrderService();
  late List<OrderModel> _orders;

  @override
  void initState() {
    super.initState();
    _orders = List.from(widget.orders);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.customerName),
            Text(
              '${_orders.length} pendiente${_orders.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: _orders.isEmpty
          ? const Center(child: Text('No hay órdenes pendientes.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _orders.length,
              itemBuilder: (ctx, i) {
                final o = _orders[i];
                return OrderCard(
                  order: o,
                  currentDealer: Session.instance.username,
                  onComplete: () => _completeOrder(o),
                  onPayment: () => _registerPayment(o),
                  onTake: () => _takeOrder(o),
                  onNotes: () => _editNotes(o),
                );
              },
            ),
    );
  }

  List<CatalogProduct> _catalogFor(OrderModel order) {
    CustomerModel? c;
    for (final x in widget.customers) {
      if (x.id == order.customerId) {
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

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _takeOrder(OrderModel order) async {
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
    _toast('Pedido tomado');
  }

  Future<void> _registerPayment(OrderModel order) async {
    final amount = await PaymentDialog.show(context, order);
    if (amount == null) return;

    final newTotal = order.amountPaid + amount;
    try {
      await _apiService.registerPayment(order.orderId, newTotal);
      await _orderService.registerPayment(order.orderId, newTotal);
    } on ApiException catch (e) {
      _toast(e.message);
      return;
    } catch (_) {
      _toast('No se pudo registrar el pago. Revisa tu conexión.');
      return;
    }
    setState(() {
      final idx = _orders.indexWhere((o) => o.orderId == order.orderId);
      if (idx >= 0) {
        _orders[idx] = OrderModel(
          orderId: order.orderId,
          customerName: order.customerName,
          customerId: order.customerId,
          items: order.items,
          total: order.total,
          amountPaid: newTotal,
          status: order.status,
          createdAt: order.createdAt,
          notes: order.notes,
          defaultDealer: order.defaultDealer,
          customerLat: order.customerLat,
          customerLng: order.customerLng,
          customerDirection: order.customerDirection,
          routeId: order.routeId,
          routeName: order.routeName,
          routeColor: order.routeColor,
          routeDealers: order.routeDealers,
          deliveryTime: order.deliveryTime,
          shopLat: order.shopLat,
          shopLng: order.shopLng,
        );
      }
    });
    _toast('Pago registrado');
  }

  Future<void> _editNotes(OrderModel order) async {
    final notes = await NotesDialog.show(context, order);
    if (notes == null) return;

    try {
      await _apiService.updateNotes(order.orderId, notes);
      await _orderService.updateNotes(order.orderId, notes);
    } on ApiException catch (e) {
      _toast(e.message);
      return;
    } catch (_) {
      _toast('No se pudo guardar la nota. Revisa tu conexión.');
      return;
    }
    setState(() {
      final idx = _orders.indexWhere((o) => o.orderId == order.orderId);
      if (idx >= 0) {
        _orders[idx] = OrderModel(
          orderId: order.orderId,
          customerName: order.customerName,
          customerId: order.customerId,
          items: order.items,
          total: order.total,
          amountPaid: order.amountPaid,
          status: order.status,
          createdAt: order.createdAt,
          notes: notes,
          defaultDealer: order.defaultDealer,
          customerLat: order.customerLat,
          customerLng: order.customerLng,
          customerDirection: order.customerDirection,
          routeId: order.routeId,
          routeName: order.routeName,
          routeColor: order.routeColor,
          routeDealers: order.routeDealers,
          deliveryTime: order.deliveryTime,
          shopLat: order.shopLat,
          shopLng: order.shopLng,
        );
      }
    });
    _toast('Nota guardada');
  }

  Future<void> _completeOrder(OrderModel order) async {
    final result = await DeliveryDialog.show(
      context,
      order,
      catalog: _catalogFor(order),
    );
    if (result == null) return;

    try {
      await _apiService.completeDelivery(
        order.orderId,
        result.items,
        result.total,
        result.amountPaid,
        complete: result.complete,
      );
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
    if (result.complete) {
      setState(() {
        _orders.removeWhere((o) => o.orderId == order.orderId);
      });
    }
    _toast(result.complete ? 'Entrega y pago guardados' : 'Info guardada');
  }
}
