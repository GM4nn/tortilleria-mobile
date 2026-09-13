import 'order_item_model.dart';

class OrderModel {
  final int orderId;
  final String customerName;
  final List<OrderItemModel> items;
  final double total;
  final double amountPaid;
  final String status;
  final String createdAt;
  final String? defaultDealer;
  // Ubicación + ruta (para el mapa)
  final double? customerLat;
  final double? customerLng;
  final String? customerDirection;
  final int? routeId;
  final String? routeName;
  final String? routeColor;
  final String? deliveryTime;
  // Ubicación de la tortillería (para ordenar la ruta por cercanía)
  final double? shopLat;
  final double? shopLng;

  const OrderModel({
    required this.orderId,
    required this.customerName,
    required this.items,
    required this.total,
    required this.amountPaid,
    required this.status,
    required this.createdAt,
    this.defaultDealer,
    this.customerLat,
    this.customerLng,
    this.customerDirection,
    this.routeId,
    this.routeName,
    this.routeColor,
    this.deliveryTime,
    this.shopLat,
    this.shopLng,
  });

  bool get hasLocation => customerLat != null && customerLng != null;

  double get remainingBalance => total - amountPaid;
  bool get isFullyPaid => amountPaid >= total;

  String get paymentStatus {
    if (amountPaid <= 0) return 'Sin Pagar';
    if (amountPaid < total) return 'Parcialmente Pagado';
    return 'Pagado';
  }

  bool get isFullyDone => status == 'completado' && isFullyPaid;

  bool ownedBy(String? username) =>
      username != null && defaultDealer == username;

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
      defaultDealer: (map['default_dealer'] as String?)?.isNotEmpty == true
          ? map['default_dealer']
          : null,
      customerLat: (map['customer_lat'] as num?)?.toDouble(),
      customerLng: (map['customer_lng'] as num?)?.toDouble(),
      customerDirection: map['customer_direction'] as String?,
      routeId: (map['route_id'] as num?)?.toInt(),
      routeName: map['route_name'] as String?,
      routeColor: map['route_color'] as String?,
      deliveryTime: map['delivery_time'] as String?,
      shopLat: (map['shop_lat'] as num?)?.toDouble(),
      shopLng: (map['shop_lng'] as num?)?.toDouble(),
    );
  }

  /// Representación ligera para inyectar al mapa (WebView).
  Map<String, dynamic> toMapStop() => {
        'order_id': orderId,
        'name': customerName,
        'lat': customerLat,
        'lng': customerLng,
        'direction': customerDirection ?? '',
        'route_id': routeId,
        'route_name': routeName ?? 'Sin ruta',
        'route_color': routeColor ?? '#4cc9f0',
        'time': deliveryTime ?? '',
        'items': items
            .map((i) => '${i.name} ×${i.quantity}')
            .join(', '),
        'status': status,
        // Verde solo cuando está completado Y totalmente pagado
        'done': isFullyDone,
      };
}
