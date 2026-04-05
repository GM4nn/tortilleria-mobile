import 'package:flutter/material.dart';
import '../../data/models/order_model.dart';
import '../../data/services/order_service.dart';
import '../widgets/order_card.dart';
import '../widgets/order_filters_drawer.dart';
import '../widgets/payment_dialog.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _orderService = OrderService();

  String _statusFilter = 'todos';
  String _paymentFilter = 'todos';
  String _orderIdSearch = '';
  String _customerSearch = '';
  TimeOfDay? _timeFrom;
  TimeOfDay? _timeTo;

  Stream<List<OrderModel>> get _ordersStream => _statusFilter == 'todos'
      ? _orderService.watchOrders()
      : _orderService.watchOrdersByStatus(_statusFilter);

  int get _activeFiltersCount {
    int count = 0;
    if (_statusFilter != 'todos') count++;
    if (_paymentFilter != 'todos') count++;
    if (_orderIdSearch.isNotEmpty) count++;
    if (_customerSearch.isNotEmpty) count++;
    if (_timeFrom != null || _timeTo != null) count++;
    return count;
  }

  List<OrderModel> _applyLocalFilters(List<OrderModel> orders) {
    var filtered = orders;

    if (_paymentFilter != 'todos') {
      filtered = filtered.where((order) {
        return switch (_paymentFilter) {
          'sin_pagar' => order.amountPaid <= 0,
          'parcial' => order.amountPaid > 0 && !order.isFullyPaid,
          'pagado' => order.isFullyPaid,
          _ => true,
        };
      }).toList();
    }

    if (_orderIdSearch.isNotEmpty) {
      filtered = filtered
          .where((o) => o.orderId.toString().contains(_orderIdSearch))
          .toList();
    }

    if (_customerSearch.isNotEmpty) {
      final search = _customerSearch.toLowerCase();
      filtered = filtered
          .where((o) => o.customerName.toLowerCase().contains(search))
          .toList();
    }

    if (_timeFrom != null || _timeTo != null) {
      filtered = filtered.where((order) {
        try {
          final date = DateTime.parse(order.createdAt);
          final orderMinutes = date.hour * 60 + date.minute;

          if (_timeFrom != null) {
            final fromMinutes = _timeFrom!.hour * 60 + _timeFrom!.minute;
            if (orderMinutes < fromMinutes) return false;
          }

          if (_timeTo != null) {
            final toMinutes = _timeTo!.hour * 60 + _timeTo!.minute;
            if (orderMinutes > toMinutes) return false;
          }

          return true;
        } catch (_) {
          return true;
        }
      }).toList();
    }

    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = 'todos';
      _paymentFilter = 'todos';
      _orderIdSearch = '';
      _customerSearch = '';
      _timeFrom = null;
      _timeTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Badge(
              isLabelVisible: _activeFiltersCount > 0,
              label: Text('$_activeFiltersCount'),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: OrderFiltersDrawer(
        statusFilter: _statusFilter,
        paymentFilter: _paymentFilter,
        orderIdSearch: _orderIdSearch,
        customerSearch: _customerSearch,
        timeFrom: _timeFrom,
        timeTo: _timeTo,
        onStatusChanged: (v) => setState(() => _statusFilter = v),
        onPaymentChanged: (v) => setState(() => _paymentFilter = v),
        onOrderIdChanged: (v) => setState(() => _orderIdSearch = v),
        onCustomerChanged: (v) => setState(() => _customerSearch = v),
        onTimeFromChanged: (v) => setState(() => _timeFrom = v),
        onTimeToChanged: (v) => setState(() => _timeTo = v),
        onClearFilters: _clearFilters,
      ),
      body: _buildOrdersList(),
    );
  }

  Widget _buildOrdersList() {
    return StreamBuilder<List<OrderModel>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildMessage(
            Icons.error_outline,
            'Error al cargar pedidos',
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = _applyLocalFilters(snapshot.data!);

        if (orders.isEmpty) {
          return _buildMessage(
            Icons.inbox_outlined,
            'No hay pedidos',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: orders.length,
          itemBuilder: (_, index) => OrderCard(
            order: orders[index],
            onComplete: () => _completeOrder(orders[index]),
            onPayment: () => _registerPayment(orders[index]),
          ),
        );
      },
    );
  }

  void _registerPayment(OrderModel order) async {
    final amount = await PaymentDialog.show(context, order);

    if (amount != null) {
      await _orderService.registerPayment(
        order.orderId,
        order.amountPaid + amount,
      );
    }
  }

  void _completeOrder(OrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Completar Pedido'),
        content: Text('Marcar pedido #${order.orderId} como completado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Completar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _orderService.completeOrder(order.orderId);
    }
  }

  Widget _buildMessage(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }
}
