import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/order_model.dart';
import 'order_status_badge.dart';

class OrderCard extends StatefulWidget {
  final OrderModel order;
  final String? currentDealer;
  final VoidCallback? onComplete;
  final VoidCallback? onPayment;
  final VoidCallback? onTake;
  final VoidCallback? onNotes;
  final VoidCallback? onNavigate;

  const OrderCard({
    super.key,
    required this.order,
    this.currentDealer,
    this.onComplete,
    this.onPayment,
    this.onTake,
    this.onNotes,
    this.onNavigate,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  final GlobalKey _shareKey = GlobalKey();
  bool _sharing = false;

  OrderModel get order => widget.order;

  // Cualquier repartidor de la ruta puede operar el pedido (sin "tomar")
  bool get _isMine => order.visibleTo(widget.currentDealer);

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  // Captura la parte informativa de la card como PNG y abre el compartir
  // de Android (WhatsApp, etc.).
  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 20));
      final boundary =
          _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pedido_${order.orderId}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Pedido de ${order.customerName}',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo compartir el pedido')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: order.isFullyDone
              ? Colors.green.withAlpha(80)
              : order.status == 'cancelado'
                  ? Colors.grey.withAlpha(60)
                  : Colors.orange.withAlpha(60),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // Lo que entra en la imagen a compartir (con su propio margen)
              RepaintBoundary(
                key: _shareKey,
                child: Container(
                  width: double.infinity,
                  color: theme.cardColor,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(theme),
                      const Divider(height: 20),
                      _buildItemsList(theme),
                      const Divider(height: 20),
                      _buildFooter(theme),
                      const SizedBox(height: 10),
                      _buildPayment(theme),
                      const SizedBox(height: 10),
                      _buildNotes(theme),
                    ],
                  ),
                ),
              ),
              // Ícono de compartir (esquina superior derecha, fuera de la imagen)
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: _sharing ? null : _share,
                  tooltip: 'Compartir',
                  icon: _sharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share, color: Color(0xFF25D366)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                if (order.hasLocation && widget.onNavigate != null) ...[
                  _buildNavigate(theme),
                  const SizedBox(height: 10),
                ],
                if (order.status != 'cancelado') _buildActionButtons(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pedido #${order.orderId}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.person_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              order.customerName,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            OrderStatusBadge(label: 'Entrega', status: order.status),
            OrderStatusBadge(label: 'Pago', status: order.paymentStatus),
          ],
        ),
        const SizedBox(height: 8),
        _buildDealer(theme),
      ],
    );
  }

  Widget _buildDealer(ThemeData theme) {
    final dealer = order.defaultDealer;
    final assigned = dealer != null;

    return Row(
      children: [
        Icon(
          Icons.delivery_dining,
          size: 16,
          color: _isMine ? Colors.green[700] : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(
          assigned ? dealer : 'Sin asignar',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _isMine ? Colors.green[700] : Colors.grey[700],
            fontWeight: _isMine ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        if (_isMine) ...[
          const SizedBox(width: 4),
          Text(
            '(tú)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  String _qty(double d) => d.toStringAsFixed(d == d.roundToDouble() ? 0 : 2);

  Widget _row(ThemeData theme, String label, String value,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(ThemeData theme) {
    return Column(
      children: order.items.map((item) {
        final netKg = item.quantity - item.returned;
        final net = netKg * item.price;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.withAlpha(16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withAlpha(40)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              _row(theme, 'Entregado', '${_qty(item.quantity)} kg'),
              _row(theme, 'Devueltos', '${_qty(item.returned)} kg',
                  color: item.returned > 0 ? Colors.orange[800] : null),
              _row(theme, 'Total kilos', '${_qty(netKg)} kg'),
              if (item.grammage > 0) ...[
                _row(theme, 'Gramaje/paq', '${item.grammage.toStringAsFixed(0)}g'),
                _row(theme, 'Paquetes', '${item.packages.toStringAsFixed(0)}'),
              ],
              const Divider(height: 14),
              _row(theme, 'Total', _currencyFormat.format(net),
                  color: Colors.green[800], bold: true),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(order.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            if (order.amountPaid > 0 && !order.isFullyPaid)
              Text(
                'Anticipo: ${_currencyFormat.format(order.amountPaid)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        Text(
          _currencyFormat.format(order.total),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPayment(ThemeData theme) {
    final remaining = order.total - order.amountPaid;
    final done = remaining <= 0.001;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: (done ? Colors.green : Colors.red).withAlpha(18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Pagado: ${_currencyFormat.format(order.amountPaid)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.green[800],
            ),
          ),
          Text(
            done ? 'Pagado completo' : 'Restante: ${_currencyFormat.format(remaining)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: done ? Colors.green[800] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigate(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: widget.onNavigate,
        icon: const Icon(Icons.directions, size: 18),
        label: const Text('Cómo llegar (Google Maps)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1a73e8),
          side: const BorderSide(color: Color(0xFF1a73e8)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildNotes(ThemeData theme) {
    final note = order.notes;
    final hasNote = note != null && note.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(hasNote ? 30 : 14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  size: 16, color: Colors.amber[800]),
              const SizedBox(width: 4),
              Text(
                'Notas',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.amber[900],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.onNotes,
                icon: Icon(hasNote ? Icons.edit : Icons.add, size: 16),
                label: Text(hasNote ? 'Editar' : 'Agregar'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amber[900],
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          if (hasNote)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(note.trim(), style: theme.textTheme.bodyMedium),
            )
          else
            Text(
              'Sin notas. Toca "Agregar" para escribir una.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    if (!_isMine) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: widget.onTake,
          icon: const Icon(Icons.pan_tool_alt_outlined, size: 18),
          label: const Text('Tomar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepOrange,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    // Un solo botón: abre el modal con la entrega (kilos/devoluciones) y el pago.
    // Si ya está completo y pagado, sirve para EDITAR/corregir.
    final done = order.isFullyDone;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: widget.onComplete,
        icon: Icon(done ? Icons.edit : Icons.check_circle, size: 18),
        label: Text(done ? 'Editar entrega / pago' : 'Completar / Pago'),
        style: FilledButton.styleFrom(
          backgroundColor: done ? Colors.blueGrey : Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy, HH:mm', 'es_MX').format(date);
    } catch (_) {
      return isoDate;
    }
  }
}
