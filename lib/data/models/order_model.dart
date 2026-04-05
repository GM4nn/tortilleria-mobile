import 'order_item_model.dart';

class OrderModel {
  final int orderId;
  final String customerName;
  final List<OrderItemModel> items;
  final double total;
  final double amountPaid;
  final String status;
  final String createdAt;

  const OrderModel({
    required this.orderId,
    required this.customerName,
    required this.items,
    required this.total,
    required this.amountPaid,
    required this.status,
    required this.createdAt,
  });

  double get remainingBalance => total - amountPaid;
  bool get isFullyPaid => amountPaid >= total;

  String get paymentStatus {
    if (amountPaid <= 0) return 'Sin Pagar';
    if (amountPaid < total) return 'Parcialmente Pagado';
    return 'Pagado';
  }

  bool get isFullyDone => status == 'completado' && isFullyPaid;

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];

    return OrderModel(
      orderId: (map['order_id'] as num).toInt(),
      customerName: map['customer_name'] ?? '',
      items: rawItems
          .map((item) => OrderItemModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      total: (map['total'] as num).toDouble(),
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pendiente',
      createdAt: map['created_at'] ?? '',
    );
  }
}
