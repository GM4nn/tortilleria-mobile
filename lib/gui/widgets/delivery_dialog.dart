import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/order_item_model.dart';
import '../../data/models/order_model.dart';

class DeliveryResult {
  final List<OrderItemModel> items;
  final double total;
  final double amountPaid; // total pagado tras este cierre (existente + lo de ahora)
  const DeliveryResult(this.items, this.total, this.amountPaid);
}

/// Diálogo para cerrar la entrega: el repartidor ajusta los kilos ENTREGADOS
/// y los DEVUELTOS por producto; el total se cobra neto: (entregado−devuelto)×precio.
class DeliveryDialog extends StatefulWidget {
  final OrderModel order;
  const DeliveryDialog({super.key, required this.order});

  static Future<DeliveryResult?> show(BuildContext context, OrderModel order) {
    return showDialog<DeliveryResult>(
      context: context,
      builder: (_) => DeliveryDialog(order: order),
    );
  }

  @override
  State<DeliveryDialog> createState() => _DeliveryDialogState();
}

class _DeliveryDialogState extends State<DeliveryDialog> {
  late final List<TextEditingController> _delivered;
  late final List<TextEditingController> _returned;
  late final TextEditingController _payCtrl;
  bool _payTouched = false; // true si el repartidor editó el pago a mano

  static final _c = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  // Al cambiar kilos/devueltos: si el pago no se tocó a mano, sincronízalo al restante
  void _onQtyChanged() {
    setState(() {
      if (!_payTouched) {
        final r = _total - widget.order.amountPaid;
        _payCtrl.text = _fmt(r < 0 ? 0 : r);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _delivered = widget.order.items
        .map((i) => TextEditingController(text: _fmt(i.quantity)))
        .toList();
    _returned = widget.order.items
        .map((i) => TextEditingController(text: i.returned > 0 ? _fmt(i.returned) : ''))
        .toList();
    // El campo es el TOTAL pagado por el cliente. Pedido nuevo = paga todo por
    // defecto; si ya tenía un pago (o se está editando), muestra ese total.
    final net = widget.order.items
        .fold<double>(0, (s, i) => s + (i.quantity - i.returned) * i.price);
    final paid = widget.order.amountPaid;
    _payCtrl = TextEditingController(text: _fmt(paid > 0 ? paid : net));
    _payTouched = paid > 0; // no auto-sobrescribas un pago ya existente
  }

  @override
  void dispose() {
    for (final c in _delivered) {
      c.dispose();
    }
    for (final c in _returned) {
      c.dispose();
    }
    _payCtrl.dispose();
    super.dispose();
  }

  String _fmt(double d) =>
      d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  double _lineNet(int i) =>
      (_num(_delivered[i]) - _num(_returned[i])) * widget.order.items[i].price;

  // Fórmula literal en vivo: (entregado − devuelto) × precio = neto
  String _formula(int i) {
    final del = _num(_delivered[i]);
    final ret = _num(_returned[i]);
    final price = widget.order.items[i].price;
    return '(${_fmt(del)} − ${_fmt(ret)} = ${_fmt(del - ret)}) × ${_c.format(price)} = ${_c.format((del - ret) * price)}';
  }

  double get _total {
    var t = 0.0;
    for (var i = 0; i < widget.order.items.length; i++) {
      t += _lineNet(i);
    }
    return t;
  }

  double get _pay => _num(_payCtrl);

  // El campo YA es el total pagado; solo lo topamos entre 0 y el total
  double get _newPaid {
    final n = _pay;
    if (n < 0) return 0;
    return n > _total ? _total : n;
  }

  void _submit() {
    final items = <OrderItemModel>[];
    for (var i = 0; i < widget.order.items.length; i++) {
      items.add(widget.order.items[i].copyWith(
        quantity: _num(_delivered[i]),
        returned: _num(_returned[i]),
      ));
    }
    Navigator.pop(context, DeliveryResult(items, _total, _newPaid));
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order.items;
    return AlertDialog(
      title: Text('Completar / Pago · ${widget.order.customerName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nota de ayuda (punto 4)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withAlpha(60)),
                ),
                child: const Text(
                  '💡 Ajusta los kilos ENTREGADOS si cambiaron.\n'
                  'Si el cliente te DEVUELVE producto, ponlo en "Devuelto".\n'
                  'Se cobra solo lo que se queda: (entregado − devuelto) × precio.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < items.length; i++) ...[
                Text(
                  '${items[i].name}  ·  ${_c.format(items[i].price)}/kg',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _field(_delivered[i], 'Entregado (kg)',
                          onChanged: _onQtyChanged),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _field(_returned[i], 'Devuelto (kg)',
                          onChanged: _onQtyChanged),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Fórmula literal, en vivo: (entregado − devuelto) × precio = neto
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formula(i),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Divider(height: 18),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _c.format(_total),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const Divider(height: 22),
              // ── Pago (en el mismo modal) ──
              const Text('Pago', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      _payCtrl,
                      'Pagado por el cliente (\$)',
                      onChanged: () => setState(() => _payTouched = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _payTouched = false; // vuelve a auto-sincronizar
                        _payCtrl.text = _fmt(_total);
                      });
                    },
                    child: const Text('Todo'),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Restante: ${_c.format(_total - _newPaid)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: (_total - _newPaid) <= 0.001
                        ? Colors.green[700]
                        : Colors.red[700],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Es el TOTAL que ha pagado el cliente. "Todo" = pagó completo; '
                'puedes dejarlo parcial o en 0. Aquí también corriges si te confundiste.',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Completar')),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {VoidCallback? onChanged}) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => onChanged != null ? onChanged() : setState(() {}),
    );
  }
}
