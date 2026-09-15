/// Ruta sincronizada desde el backend (colección 'routes'). Permite listar en la
/// móvil las rutas del repartidor aunque no tengan pedidos hoy.
class RouteModel {
  final int id;
  final String name;
  final String? color;
  final List<String> dealers;
  final bool active;

  const RouteModel({
    required this.id,
    required this.name,
    this.color,
    this.dealers = const [],
    this.active = true,
  });

  factory RouteModel.fromMap(Map<String, dynamic> map) {
    return RouteModel(
      id: (map['id'] as num).toInt(),
      name: map['name'] ?? '',
      color: map['color'] as String?,
      dealers: (map['dealers'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      active: (map['active'] as bool?) ?? true,
    );
  }
}
