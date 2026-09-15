/// URL base de la API del backend.
///
/// Producción (Fly): https://tortilleria-backend.fly.dev/api
/// Para probar contra un backend local, cambia esto por tu IP de LAN, p.ej:
///   http://192.168.100.91:8000/api
class ApiConfig {
  // PRODUCCIÓN (Fly).
  static const String baseUrl = 'https://tortilleria-backend.fly.dev/api';

  // LOCAL (mismo WiFi): descomenta esta y comenta la de arriba para probar local.
  // static const String baseUrl = 'http://192.168.100.91:8000/api';
}
