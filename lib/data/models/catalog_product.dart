/// Producto disponible (con el precio del cliente) para AGREGAR a un pedido
/// desde la app móvil. Viaja en el doc del pedido en el campo 'catalog'.
class CatalogProduct {
  final int productId;
  final String name;
  final String icon;
  final double price;

  const CatalogProduct({
    required this.productId,
    required this.name,
    this.icon = '🍴',
    required this.price,
  });

  factory CatalogProduct.fromMap(Map<String, dynamic> map) {
    return CatalogProduct(
      productId: (map['product_id'] as num).toInt(),
      name: map['name'] ?? '',
      icon: (map['icon'] as String?) ?? '🍴',
      price: (map['price'] as num?)?.toDouble() ?? 0,
    );
  }
}
