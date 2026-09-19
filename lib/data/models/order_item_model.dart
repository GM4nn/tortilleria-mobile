class OrderItemModel {
  final int productId;
  final String name;
  final double price;
  final double quantity; // kilos entregados
  final double returned; // kilos devueltos
  final double subtotal; // bruto = quantity * price
  final double grammage; // gramos por paquete (0 = no especificado)

  const OrderItemModel({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.returned = 0,
    required this.subtotal,
    this.grammage = 0,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      productId: (map['product_id'] as num).toInt(),
      name: map['name'] ?? '',
      price: (map['price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      returned: (map['returned'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num).toDouble(),
      grammage: (map['grammage'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Neto a cobrar de esta línea: (entregado − devuelto) × precio.
  double get net => (quantity - returned) * price;

  /// Número de paquetes equivalente (solo si hay gramaje configurado).
  double get packages => grammage > 0 ? quantity * 1000 / grammage : 0;

  /// Texto de conversión: "X paquetes de Yg" (solo si hay gramaje).
  String get grammageText =>
      grammage > 0 ? '(${packages.toStringAsFixed(0)} paquetes de ${grammage.toStringAsFixed(0)}g)' : '';

  /// Copia con nuevos kilos entregados/devueltos (recalcula el subtotal bruto).
  OrderItemModel copyWith({double? quantity, double? returned, double? grammage}) {
    final q = quantity ?? this.quantity;
    final g = grammage ?? this.grammage;
    return OrderItemModel(
      productId: productId,
      name: name,
      price: price,
      quantity: q,
      returned: returned ?? this.returned,
      subtotal: q * price,
      grammage: g,
    );
  }

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'returned': returned,
        'subtotal': subtotal,
        'grammage': grammage,
      };
}
