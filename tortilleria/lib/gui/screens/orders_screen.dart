import 'package:flutter/material.dart';
import '../../data/models/order_model.dart';
import '../../data/services/order_service.dart';
import '../widgets/order_card.dart';
import '../widgets/order_filter_chips.dart';
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

  static const _statusFilters = {
    'todos': ('Todos', Icons.list, Colors.blue),
    'pendiente': ('Pendientes', Icons.schedule, Colors.orange),
    'completado': ('Completados', Icons.check_circle, Colors.green),
    'cancelado': ('Cancelados', Icons.cancel, Colors.red),
  };

  static const _paymentFilters = {
    'todos': ('Todos', Icons.list, Colors.blue),
    'sin_pagar': ('Sin Pagar', Icons.money_off, Colors.red),
    'parcial': ('Parcial', Icons.payments_outlined, Colors.orange),
    'pagado': ('Pagado', Icons.paid, Colors.green),
  };

  Stream<List<OrderModel>> get _ordersStream => _statusFilter == 'todos'
      ? _orderService.watchOrders()
      : _orderService.watchOrdersByStatus(_statusFilter);

  List<OrderModel> _applyPaymentFilter(List<OrderModel> orders) {
    if (_paymentFilter == 'todos') return orders;

    return orders.where((order) {
      return switch (_paymentFilter) {
        'sin_pagar' => order.amountPaid <= 0,
        'parcial' => order.amountPaid > 0 && !order.isFullyPaid,
        'pagado' => order.isFullyPaid,
        _ => true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                OrderFilterChips(
                  label: 'Entrega',
                  selectedFilter: _statusFilter,
                  filters: _statusFilters,
                  onFilterChanged: (filter) =>
                      setState(() => _statusFilter = filter),
                ),
                const SizedBox(height: 10),
                OrderFilterChips(
                  label: 'Pago',
                  selectedFilter: _paymentFilter,
                  filters: _paymentFilters,
                  onFilterChanged: (filter) =>
                      setState(() => _paymentFilter = filter),
                ),
              ],
            ),
          ),
          Expanded(child: _buildOrdersList()),
        ],
      ),
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

        final orders = _applyPaymentFilter(snapshot.data!);

        if (orders.isEmpty) {
          return _buildMessage(
            Icons.inbox_outlined,
            'No hay pedidos',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
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
