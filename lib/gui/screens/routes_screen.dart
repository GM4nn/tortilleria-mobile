import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/models/order_model.dart';
import '../../data/models/route_model.dart';
import '../../data/services/order_service.dart';
import '../../data/services/route_service.dart';
import '../../data/services/session.dart';
import 'login_screen.dart';
import 'orders_screen.dart';

/// Agrupación de los pedidos de hoy por ruta.
class _RouteGroup {
  final String name;
  final String? color;
  int total = 0;
  int pending = 0;
  _RouteGroup(this.name, this.color);
}

/// Pantalla inicial del repartidor: lista de rutas (con los pedidos de hoy).
/// Muestra también las rutas asignadas aunque no tengan pedidos hoy, para poder
/// abrir el mapa y generar pedidos tocando a los clientes en gris.
class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final _orderService = OrderService();
  final _routeService = RouteService();

  StreamSubscription<List<OrderModel>>? _orderSub;
  StreamSubscription<List<RouteModel>>? _routeSub;
  List<OrderModel> _orders = [];
  List<RouteModel> _routes = [];
  bool _ordersReady = false;

  @override
  void initState() {
    super.initState();
    final me = Session.instance.username;
    _orderSub = _orderService.watchOrders().listen((data) {
      setState(() {
        _orders = data.where((o) => o.visibleTo(me)).toList();
        _ordersReady = true;
      });
    });
    if (me != null) {
      _routeSub = _routeService.watchMyRoutes(me).listen((data) {
        setState(() => _routes = data);
      });
    }
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _routeSub?.cancel();
    super.dispose();
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF4CC9F0);
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    if (value == null) return const Color(0xFF4CC9F0);
    return Color(value + 0xFF000000);
  }

  List<_RouteGroup> _group() {
    final map = <String, _RouteGroup>{};
    // Semilla: mis rutas asignadas (aunque no tengan pedidos hoy)
    for (final r in _routes) {
      map[r.name] = _RouteGroup(r.name, r.color);
    }
    // Pedidos de hoy
    for (final o in _orders) {
      final name = (o.routeName == null || o.routeName!.isEmpty)
          ? 'Sin ruta'
          : o.routeName!;
      final group = map.putIfAbsent(name, () => _RouteGroup(name, o.routeColor));
      group.total++;
      if (!o.isFullyDone && o.status != 'cancelado') group.pending++;
    }
    final list = map.values.toList();
    list.sort((a, b) {
      if (a.name == 'Sin ruta') return 1;
      if (b.name == 'Sin ruta') return -1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  void _logout() async {
    await Session.instance.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutas'),
        actions: [
          if (Session.instance.displayName != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(Session.instance.displayName!),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_ordersReady && _routes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final groups = _group();
    if (groups.isEmpty) {
      return _buildMessage(Icons.inbox_outlined, 'No tienes rutas asignadas');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: groups.length,
      itemBuilder: (_, index) {
        final group = groups[index];
        final color = _parseColor(group.color);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color,
              child: Text(
                '${group.total}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              group.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              group.total == 0
                  ? 'Sin pedidos hoy · toca para generar'
                  : '${group.total} pedido${group.total == 1 ? '' : 's'} · '
                      '${group.pending} pendiente${group.pending == 1 ? '' : 's'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrdersScreen(
                  routeName: group.name,
                  routeColor: group.color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessage(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }
}
