import 'dart:math' as math;
import '../../data/models/order_model.dart';

// Ubicación de la tortillería (fallback si el pedido no trae shop_lat/lng).
const double kShopLat = 20.560312;
const double kShopLng = -100.3981438;

/// Ordena los pedidos por "vecino más cercano" empezando desde la tortillería,
/// para que el repartidor haga menos vueltas. Los pedidos sin ubicación van al final.
List<OrderModel> orderByNearest(List<OrderModel> orders) {
  final withLoc = orders.where((o) => o.hasLocation).toList();
  final without = orders.where((o) => !o.hasLocation).toList();
  if (withLoc.isEmpty) return orders;

  double curLat = withLoc.first.shopLat ?? kShopLat;
  double curLng = withLoc.first.shopLng ?? kShopLng;
  final cos = math.cos(curLat * math.pi / 180);

  final remaining = List<OrderModel>.from(withLoc);
  final result = <OrderModel>[];

  while (remaining.isNotEmpty) {
    var bestIdx = 0;
    var bestD = double.infinity;
    for (var i = 0; i < remaining.length; i++) {
      final dLat = remaining[i].customerLat! - curLat;
      final dLng = (remaining[i].customerLng! - curLng) * cos;
      final d = dLat * dLat + dLng * dLng;
      if (d < bestD) {
        bestD = d;
        bestIdx = i;
      }
    }
    final next = remaining.removeAt(bestIdx);
    result.add(next);
    curLat = next.customerLat!;
    curLng = next.customerLng!;
  }

  return [...result, ...without];
}
