import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/catalog_product.dart';
import '../../data/models/order_item_model.dart';
import '../../data/models/order_model.dart';

class DeliveryResult {
  final List<OrderItemModel> items;
  final double total;
  final double amountPaid; // total pagado tras este cierre (existente + lo de ahora)
  const DeliveryResult(this.items, this.total, this.amountPaid);
}

/// Una línea editable del cierre (producto + kilos entregados/devueltos).
class _Line {
  final int productId;
  final String name;
  final double price;
  final TextEditingController delivered;
  final TextEditingController returned;
  _Line({
    required this.productId,
    required this.name,
    required this.price,
    required this.delivered,
    required this.returned,
  });
  void dispose() {
    delivered.dispose();
    returned.dispose();
  }
}

/// Diálogo para cerrar la entrega: el repartidor ajusta los kilos ENTREGADOS
/// y los DEVUELTOS por producto; puede AGREGAR productos del catálogo del cliente;
/// el total se cobra neto: (entregado−devuelto)×precio.
class DeliveryDialog extends StatefulWidget {
  final OrderModel order;
  final List<CatalogProduct> catalog; // productos disponibles (por endpoint)
  const DeliveryDialog({
    super.key,
    required this.order,
    this.catalog = const [],
  });

  static Future<DeliveryResult?> show(
    BuildContext context,
    OrderModel order, {
    List<CatalogProduct> catalog = const [],
  }) {
    return showDialog<DeliveryResult>(
      context: context,
      builder: (_) => DeliveryDialog(order: order, catalog: catalog),
    );
  }

  @override
  State<DeliveryDialog> createState() => _DeliveryDialogState();
}

class _DeliveryDialogState extends State<DeliveryDialog> {
  final List<_Line> _lines = [];
  late final TextEditingController _payCtrl;
  bool _payTouched = false; // true si el repartidor editó el pago a mano
  bool _showAdd = false; // muestra la lista para agregar producto (inline)

  static final _c = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    for (final i in widget.order.items) {
      _lines.add(_Line(
        productId: i.productId,
        name: i.name,
        price: i.price,
        delivered: TextEditingController(text: _fmt(i.quantity)),
        returned:
            TextEditingController(text: i.returned > 0 ? _fmt(i.returned) : ''),
      ));
    }
    final paid = widget.order.amountPaid;
    _payCtrl = TextEditingController(text: _fmt(paid > 0 ? paid : _total));
    _payTouched = paid > 0; // no auto-sobrescribas un pago ya existente
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _payCtrl.dispose();
    super.dispose();
  }

  String _fmt(double d) =>
      d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  double _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  double _lineNet(_Line l) => (_num(l.delivered) - _num(l.returned)) * l.price;

  // Fórmula literal en vivo: (entregado − devuelto) × precio = neto
  String _formula(_Line l) {
    final del = _num(l.delivered), ret = _num(l.returned);
    return '(${_fmt(del)} − ${_fmt(ret)} = ${_fmt(del - ret)}) × '
        '${_c.format(l.price)} = ${_c.format((del - ret) * l.price)}';
  }

  double get _total {
    var t = 0.0;
    for (final l in _lines) {
      t += _lineNet(l);
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

  // Al cambiar kilos/devueltos: si el pago no se tocó a mano, sincronízalo al restante
  void _onQtyChanged() {
    setState(() {
      if (!_payTouched) {
        final r = _total - widget.order.amountPaid;
        _payCtrl.text = _fmt(r < 0 ? 0 : r);
      }
    });
  }

  // Productos disponibles para agregar (catálogo con precio del cliente, por
  // endpoint) que aún no están en el pedido.
  List<CatalogProduct> get _addable {
    final ids = _lines.map((l) => l.productId).toSet();
    return widget.catalog.where((p) => !ids.contains(p.productId)).toList();
  }

  void _addLine(CatalogProduct p) {
    setState(() {
      _lines.add(_Line(
        productId: p.productId,
        name: p.name,
        price: p.price,
        delivered: TextEditingController(text: '1'), // arranca en 1 (editable)
        returned: TextEditingController(),
      ));
      _showAdd = false;
      _onQtyChanged();
    });
  }

  // "Agregar producto" INLINE: despliega la lista dentro del mismo modal (sin
  // abrir otra hoja encima). Al tocar un producto se agrega como línea.
  Widget _buildAddProduct() {
    final options = _addable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showAdd = !_showAdd),
            icon: Icon(_showAdd ? Icons.close : Icons.add, size: 18),
            label: Text(_showAdd ? 'Cerrar' : 'Agregar producto'),
          ),
        ),
        if (_showAdd) ...[
          const SizedBox(height: 6),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                widget.catalog.isEmpty
                    ? 'No se pudo cargar el catálogo.'
                    : 'Ya están todos los productos en el pedido.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withAlpha(60)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  for (final p in options)
                    InkWell(
                      onTap: () => _addLine(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        child: Row(
                          children: [
                            Text(p.icon, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(p.name)),
                            Text('${_c.format(p.price)}/kg',
                                style: TextStyle(color: Colors.grey[700])),
                            const SizedBox(width: 6),
                            const Icon(Icons.add_circle_outline,
                                size: 18, color: Colors.green),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  void _submit() {
    final items = <OrderItemModel>[];
    for (final l in _lines) {
      final del = _num(l.delivered), ret = _num(l.returned);
      items.add(OrderItemModel(
        productId: l.productId,
        name: l.name,
        price: l.price,
        quantity: del,
        returned: ret,
        subtotal: del * l.price,
      ));
    }
    Navigator.pop(context, DeliveryResult(items, _total, _newPaid));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Completar / Pago · ${widget.order.customerName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nota de ayuda
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
              for (final l in _lines) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l.name}  ·  ${_c.format(l.price)}/kg',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Quitar',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        _lines.remove(l);
                        l.dispose();
                        _onQtyChanged();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _field(l.delivered, 'Entregado (kg)',
                          onChanged: _onQtyChanged),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _field(l.returned, 'Devuelto (kg)',
                          onChanged: _onQtyChanged),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formula(l),
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
              // Agregar producto (inline, sin abrir otro modal encima)
              _buildAddProduct(),
              const SizedBox(height: 8),
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
                        _payTouched = false;
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
