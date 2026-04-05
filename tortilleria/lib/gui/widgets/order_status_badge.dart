import 'package:flutter/material.dart';

class OrderStatusBadge extends StatelessWidget {
  final String label;
  final String status;

  const OrderStatusBadge({
    super.key,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _statusStyle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $status',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData) get _statusStyle => switch (status) {
        'pendiente' || 'Sin Pagar' => (Colors.orange, Icons.schedule),
        'completado' || 'Pagado' => (Colors.green, Icons.check_circle),
        'cancelado' => (Colors.red, Icons.cancel),
        'Parcialmente Pagado' => (Colors.blue, Icons.payments_outlined),
        _ => (Colors.grey, Icons.help_outline),
      };
}
