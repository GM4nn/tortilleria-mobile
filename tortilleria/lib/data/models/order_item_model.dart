class OrderItemModel {
  final int productId;
  final String name;
  final double price;
  final double quantity;
  final double subtotal;

  const OrderItemModel({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.subtotal,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      productId: (map['product_id'] as num).toInt(),
      name: map['name'] ?? '',
      price: (map['price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }
}
