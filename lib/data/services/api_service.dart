import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_config.dart';
import '../models/order_item_model.dart';
import 'session.dart';

/// Llamadas HTTP a la API del backend. Guardan en SQLite (fuente de verdad).
/// Tras un OK, la móvil actualiza también Firestore para el mapa en tiempo real.
class ApiService {
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final b = res.body.isEmpty ? {} : jsonDecode(res.body);
      return Map<String, dynamic>.from(b as Map);
    }
    throw ApiException(_detail(res));
  }

  String _detail(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['detail'] != null) return j['detail'].toString();
    } catch (_) {}
    return 'Error ${res.statusCode}';
  }

  /// Genera el pedido de HOY para un cliente (al tocarlo en gris en el mapa).
  /// Manda el repartidor (username) para que quede asignado.
  Future<Map<String, dynamic>> generateOrder(int customerId) =>
      _post('/mobile/generate-order', {
        'customer_id': customerId,
        'dealer': Session.instance.username,
      });

  /// Guarda las notas del pedido.
  Future<Map<String, dynamic>> updateNotes(int orderId, String notes) =>
      _post('/mobile/orders/$orderId/notes', {'notes': notes});

  /// Fija el total pagado del pedido.
  Future<Map<String, dynamic>> registerPayment(int orderId, double amountPaid) =>
      _post('/mobile/orders/$orderId/payment', {'amount_paid': amountPaid});

  /// Guarda la entrega: kilos entregados/devueltos, total neto y pago.
  /// [complete] true = marca completado; false = solo guarda (sigue pendiente).
  Future<Map<String, dynamic>> completeDelivery(
    int orderId,
    List<OrderItemModel> items,
    double total,
    double amountPaid, {
    bool complete = true,
  }) =>
      _post('/mobile/orders/$orderId/complete', {
        'items': items.map((i) => i.toMap()).toList(),
        'total': total,
        'amount_paid': amountPaid,
        'complete': complete,
      });

  /// Órdenes pendientes de entrega o pago parcial (semanas anteriores).
  Future<List<Map<String, dynamic>>> getPendingOrders() =>
      _get('/mobile/pending-orders');

  /// Completa y paga todas las órdenes indicadas.
  Future<Map<String, dynamic>> completeAllOrders(List<int> orderIds) =>
      _post('/mobile/complete-all', {'order_ids': orderIds});

  Future<List<Map<String, dynamic>>> _get(String path) async {
    final res = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}$path'),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = res.body.isEmpty ? [] : jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(body as List);
    }
    throw ApiException(_detail(res));
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
