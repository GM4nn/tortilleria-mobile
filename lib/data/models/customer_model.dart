/// Cliente para el mapa (sincronizado desde el backend a la colección 'customers').
/// Sirve para pintar en gris los clientes de la ruta que aún NO tienen pedido hoy.
class CustomerModel {
  final int id;
  final String name;
  final double? lat;
  final double? lng;
  final String direction;
  final int? routeId;
  final String? routeName;
  final String? routeColor;
  final List<String> routeDealers;
  final Map<int, double> prices; // precios personalizados {product_id: precio}
  final bool active;

  const CustomerModel({
    required this.id,
    required this.name,
    this.lat,
    this.lng,
    this.direction = '',
    this.routeId,
    this.routeName,
    this.routeColor,
    this.routeDealers = const [],
    this.prices = const {},
    this.active = true,
  });

  bool get hasLocation => lat != null && lng != null;

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: (map['id'] as num).toInt(),
      name: map['name'] ?? '',
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      direction: (map['direction'] as String?) ?? '',
      routeId: (map['route_id'] as num?)?.toInt(),
      routeName: map['route_name'] as String?,
      routeColor: map['route_color'] as String?,
      routeDealers: (map['route_dealers'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      prices: ((map['prices'] as Map<dynamic, dynamic>?) ?? {}).map(
        (k, v) => MapEntry(
          int.tryParse(k.toString()) ?? -1,
          (v as num?)?.toDouble() ?? 0,
        ),
      ),
      active: (map['active'] as bool?) ?? true,
    );
  }
}
