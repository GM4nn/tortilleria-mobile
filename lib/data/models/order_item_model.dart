class OrderItemModel {
  final int productId;
  final String name;
  final double price;
  final double quantity; // kilos entregados
  final double returned; // kilos devueltos
  final double subtotal; // bruto = quantity * price

  const OrderItemModel({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.returned = 0,
    required this.subtotal,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      productId: (map['product_id'] as num).toInt(),
      name: map['name'] ?? '',
      price: (map['price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      returned: (map['returned'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }

  /// Neto a cobrar de esta línea: (entregado − devuelto) × precio.
  double get net => (quantity - returned) * price;

  /// Copia con nuevos kilos entregados/devueltos (recalcula el subtotal bruto).
  OrderItemModel copyWith({double? quantity, double? returned}) {
    final q = quantity ?? this.quantity;
    return OrderItemModel(
      productId: productId,
      name: name,
      price: price,
      quantity: q,
      returned: returned ?? this.returned,
      subtotal: q * price,
    );
  }

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'returned': returned,
        'subtotal': subtotal,
      };
}
