import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/models/order_model.dart';

/// Mapa de la ruta del día: carga un HTML con Leaflet (assets/route_map.html)
/// y le inyecta los pedidos con ubicación. Agrupa por ruta y ordena por cercanía.
class RouteMapScreen extends StatefulWidget {
  final List<OrderModel> orders;
  const RouteMapScreen({super.key, required this.orders});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  late final WebViewController _controller;
  late final int _count;

  @override
  void initState() {
    super.initState();
    final stops =
        widget.orders.where((o) => o.hasLocation).map((o) => o.toMapStop()).toList();
    _count = stops.length;
    final payload = jsonEncode(jsonEncode(stops)); // string JS: setStops("[...]")

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0A10))
      ..addJavaScriptChannel(
        'MapChannel',
        onMessageReceived: (msg) {
          final uri = Uri.tryParse(msg.message);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _controller.runJavaScript('setStops($payload);'),
        ),
      )
      ..loadFlutterAsset('assets/route_map.html');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta del día'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$_count paradas', style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
