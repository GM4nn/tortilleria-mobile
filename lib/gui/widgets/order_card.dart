import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/order_model.dart';
import 'order_status_badge.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onComplete;
  final VoidCallback? onPayment;

  const OrderCard({
    super.key,
    required this.order,
    this.onComplete,
    this.onPayment,
  });

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: order.isFullyDone
              ? Colors.green.withAlpha(80)
              : order.status == 'cancelado'
                  ? Colors.grey.withAlpha(60)
                  : Colors.orange.withAlpha(60),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const Divider(height: 20),
            _buildItemsList(theme),
            const Divider(height: 20),
            _buildFooter(theme),
            if (!order.isFullyDone && order.status != 'cancelado') ...[
              const SizedBox(height: 12),
              _buildActionButtons(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pedido #${order.orderId}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.person_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              order.customerName,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            OrderStatusBadge(label: 'Entrega', status: order.status),
            OrderStatusBadge(label: 'Pago', status: order.paymentStatus),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsList(ThemeData theme) {
    return Column(
      children: order.items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} x ${item.name}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                _currencyFormat.format(item.subtotal),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(order.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            if (order.amountPaid > 0 && !order.isFullyPaid)
              Text(
                'Anticipo: ${_currencyFormat.format(order.amountPaid)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        Text(
          _currencyFormat.format(order.total),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    final showPayment = onPayment != null && !order.isFullyPaid;
    final showComplete = onComplete != null && order.status == 'pendiente';

    return Row(
      children: [
        if (showPayment)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPayment,
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Registrar Pago'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        if (showPayment && showComplete)
          const SizedBox(width: 8),
        if (showComplete)
          Expanded(
            child: FilledButton.icon(
              onPressed: onComplete,
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
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy, HH:mm', 'es_MX').format(date);
    } catch (_) {
      return isoDate;
    }
  }
}
