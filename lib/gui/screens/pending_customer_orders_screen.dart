import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

class CustomerOrdersScreen extends StatefulWidget {
  final String customerName;
  final List<OrderModel> orders;
  final List<CustomerModel> customers;
  final List<CatalogProduct> catalog;

  const CustomerOrdersScreen({
    super.key,
    required this.customerName,
    required this.orders,
    required this.customers,
    required this.catalog,
  });

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  final _apiService = ApiService();
  final _orderService = OrderService();
  late List<OrderModel> _orders;

  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _statusFilter = 'all';

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  static final _dateFormat = DateFormat("EEEE d 'de' MMMM", 'es_MX');

  @override
  void initState() {
    super.initState();
    _orders = List.from(widget.orders);
  }

  List<OrderModel> get _filteredOrders {
    return _orders.where((o) {
      // Filtro de fecha
      if (_dateFrom != null || _dateTo != null) {
        final created = DateTime.tryParse(o.createdAt);
        if (created == null) return false;
        if (_dateFrom != null && created.isBefore(_dateFrom!)) return false;
        if (_dateTo != null) {
          final endOfDay = _dateTo!.add(const Duration(days: 1));
          if (created.isAfter(endOfDay)) return false;
        }
      }
      // Filtro de estado
      if (_statusFilter != 'all') {
        if (_statusFilter == 'pendiente' && o.status != 'pendiente') return false;
        if (_statusFilter == 'completado' && o.status != 'completado') return false;
        if (_statusFilter == 'cancelado' && o.status != 'cancelado') return false;
        if (_statusFilter == 'pagado' && !o.isFullyPaid) return false;
        if (_statusFilter == 'sin_pagar' && o.amountPaid > 0) return false;
        if (_statusFilter == 'parcial' && (o.amountPaid <= 0 || o.isFullyPaid)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;
    final totalFiltered = filtered.fold<double>(0, (s, o) => s + o.total);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.customerName),
            Text(
              '${filtered.length} de ${_orders.length} pedido${_orders.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No hay pedidos en ese rango.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final o = filtered[i];
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
          ),
          if (filtered.isNotEmpty) _buildBulkBar(filtered, totalFiltered),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(20),
        border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(40))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.date_range, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateFrom,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _dateFrom != null
                        ? 'Desde: ${_dateFormat.format(_dateFrom!)}'
                        : 'Desde',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateTo,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _dateTo != null
                        ? 'Hasta: ${_dateFormat.format(_dateTo!)}'
                        : 'Hasta',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              if (_dateFrom != null || _dateTo != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => setState(() {
                    _dateFrom = null;
                    _dateTo = null;
                  }),
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Limpiar fechas',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.filter_list, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Todos')),
                    ButtonSegment(value: 'pendiente', label: Text('Pendiente')),
                    ButtonSegment(value: 'completado', label: Text('Completado')),
                    ButtonSegment(value: 'pagado', label: Text('Pagado')),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (sel) => setState(() => _statusFilter = sel.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulkBar(List<OrderModel> filtered, double totalFiltered) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.withAlpha(40))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} pedido${filtered.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Total: ${_currencyFormat.format(totalFiltered)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _showCompleteAllModal(filtered, totalFiltered),
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Completar'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateFrom = picked);
  }

  Future<void> _pickDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateTo = picked);
  }

  void _showCompleteAllModal(List<OrderModel> orders, double totalFiltered) {
    final totalKg = orders.fold<double>(0, (s, o) {
      return s + o.items.fold<double>(0, (si, i) => si + i.quantity);
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Completar pedidos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Se completarán ${orders.length} pedido${orders.length == 1 ? '' : 's'}:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _modalRow('Total pedidos', '${orders.length}'),
            _modalRow('Total kilos', '${totalKg.toStringAsFixed(1)} kg'),
            _modalRow('Monto total', _currencyFormat.format(totalFiltered)),
            const Divider(height: 24),
            Text(
              '¿Marcar como completados y pagar todos?',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeCompleteAll(orders);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Widget _modalRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeCompleteAll(List<OrderModel> pending) async {
    final ids = pending.map((o) => o.orderId).toList();

    try {
      await _apiService.completeAllOrders(ids);
      await _orderService.completeAllOrders(ids);
    } on ApiException catch (e) {
      _toast(e.message);
      return;
    } catch (_) {
      _toast('No se pudieron completar los pedidos. Revisa tu conexión.');
      return;
    }

    setState(() {
      for (final o in pending) {
        _orders.removeWhere((x) => x.orderId == o.orderId);
      }
    });
    _toast('${ids.length} pedido${ids.length == 1 ? '' : 's'} completado${ids.length == 1 ? '' : 's'}');
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
