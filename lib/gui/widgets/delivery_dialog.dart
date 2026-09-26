import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/catalog_product.dart';
import '../../data/models/order_item_model.dart';
import '../../data/models/order_model.dart';

class DeliveryResult {
  final List<OrderItemModel> items;
  final double total;
  final double amountPaid;
  final bool complete;
  const DeliveryResult(this.items, this.total, this.amountPaid,
      {this.complete = true});
}

class _Line {
  final int productId;
  final String name;
  final double price;
  final TextEditingController deliveredCtrl;
  final TextEditingController returnedCtrl;
  final TextEditingController paquetesCtrl;
  final TextEditingController gramajeCtrl;
  final TextEditingController kgCalcCtrl;
  bool byGramaje;

  _Line({
    required this.productId,
    required this.name,
    required this.price,
    required this.deliveredCtrl,
    required this.returnedCtrl,
    required this.paquetesCtrl,
    required this.gramajeCtrl,
    required this.kgCalcCtrl,
    this.byGramaje = false,
  });

  void dispose() {
    deliveredCtrl.dispose();
    returnedCtrl.dispose();
    paquetesCtrl.dispose();
    gramajeCtrl.dispose();
    kgCalcCtrl.dispose();
  }
}

class DeliveryDialog extends StatefulWidget {
  final OrderModel order;
  final List<CatalogProduct> catalog;
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
  bool _payTouched = false;
  bool _showAdd = false;

  static final _c = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  @override
  void initState() {
    super.initState();
    for (final i in widget.order.items) {
      _lines.add(_Line(
        productId: i.productId,
        name: i.name,
        price: i.price,
        deliveredCtrl: TextEditingController(text: _fmt(i.quantity)),
        returnedCtrl:
            TextEditingController(text: i.returned > 0 ? _fmt(i.returned) : ''),
        paquetesCtrl: TextEditingController(
            text: i.grammage > 0 ? _fmt(i.quantity * 1000 / i.grammage) : '1'),
        gramajeCtrl: TextEditingController(
            text: i.grammage > 0 ? i.grammage.toStringAsFixed(0) : ''),
        kgCalcCtrl: TextEditingController(text: _fmt(i.quantity)),
        byGramaje: i.grammage > 0,
      ));
    }
    final paid = widget.order.amountPaid;
    _payCtrl = TextEditingController(text: _fmt(paid > 0 ? paid : _total));
    _payTouched = paid > 0;
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

  double _lineNet(_Line l) =>
      (_num(l.deliveredCtrl) - _num(l.returnedCtrl)) * l.price;

  String _formula(_Line l) {
    final del = _num(l.byGramaje ? l.kgCalcCtrl : l.deliveredCtrl);
    final ret = _num(l.returnedCtrl);
    return '(${_fmt(del)} − ${_fmt(ret)} = ${_fmt(del - ret)}) × '
        '${_c.format(l.price)} = ${_c.format((del - ret) * l.price)}';
  }

  void _recalcKg(_Line l) {
    final g = _num(l.gramajeCtrl);
    final p = _num(l.paquetesCtrl);
    if (l.byGramaje && g > 0 && p > 0) {
      final kg = p * g / 1000;
      l.kgCalcCtrl.text = _fmt(kg);
      l.deliveredCtrl.text = _fmt(kg);
      if (!_payTouched) {
        final r = _total - widget.order.amountPaid;
        _payCtrl.text = _fmt(r < 0 ? 0 : r);
      }
    }
  }

  void _toggleGramaje(_Line l) {
    setState(() {
      l.byGramaje = !l.byGramaje;
      if (l.byGramaje) {
        l.paquetesCtrl.text = _fmt(_num(l.deliveredCtrl));
        l.gramajeCtrl.text = '';
        l.kgCalcCtrl.text = _fmt(_num(l.deliveredCtrl));
      } else {
        l.deliveredCtrl.text = l.kgCalcCtrl.text;
      }
      _recalcKg(l);
      _onQtyChanged();
    });
  }

  double get _total {
    var t = 0.0;
    for (final l in _lines) {
      t += _lineNet(l);
    }
    return t;
  }

  double get _pay => _num(_payCtrl);

  double get _newPaid {
    final n = _pay;
    if (n < 0) return 0;
    return n;
  }

  void _onQtyChanged() {
    setState(() {
      if (!_payTouched) {
        final r = _total - widget.order.amountPaid;
        _payCtrl.text = _fmt(r < 0 ? 0 : r);
      }
    });
  }

  List<CatalogProduct> get _addable => widget.catalog;

  Future<double> _getResolvedPrice(int productId) async {
    double price = 0;
    // Buscar el producto en el catálogo para obtener el precio base
    for (final product in widget.catalog) {
      if (product.productId == productId) {
        price = product.price;
        break;
      }
    }

    try {
      final customerId = widget.order.customerId;
      if (customerId != null) {
        final customerDoc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(customerId.toString())
            .get();

        if (customerDoc.exists) {
          final prices = customerDoc.data()?['prices'] as Map<String, dynamic>?;
          if (prices != null) {
            final customPrice = prices[productId.toString()];
            if (customPrice != null) {
              return (customPrice as num).toDouble();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error al obtener precio: $e');
    }

    return price;
  }

  void _addLine(CatalogProduct p) {
    _getResolvedPrice(p.productId).then((resolvedPrice) {
      setState(() {
        _lines.add(_Line(
          productId: p.productId,
          name: p.name,
          price: resolvedPrice,
          deliveredCtrl: TextEditingController(text: '1'),
          returnedCtrl: TextEditingController(),
          paquetesCtrl: TextEditingController(text: '1'),
          gramajeCtrl: TextEditingController(),
          kgCalcCtrl: TextEditingController(text: '1'),
          byGramaje: false,
        ));
        _showAdd = false;
        _onQtyChanged();
      });
    });
  }

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

  void _submit({required bool complete}) {
    final items = <OrderItemModel>[];
    for (final l in _lines) {
      final ret = _num(l.returnedCtrl);
      final gramaje = _num(l.gramajeCtrl);
      final kg = l.byGramaje
          ? _num(l.kgCalcCtrl)
          : _num(l.deliveredCtrl);
      final finalKg = kg > 0 ? kg : (_num(l.deliveredCtrl));
      items.add(OrderItemModel(
        productId: l.productId,
        name: l.name,
        price: l.price,
        quantity: finalKg,
        returned: ret,
        subtotal: finalKg * l.price,
        grammage: l.byGramaje ? gramaje : 0,
      ));
    }
    Navigator.pop(
      context,
      DeliveryResult(items, _total, _newPaid, complete: complete),
    );
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withAlpha(60)),
                ),
                child: const Text(
                  '💡 Pedido por kg o por paquetes.\n'
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
                    Switch(
                      value: l.byGramaje,
                      onChanged: (_) => _toggleGramaje(l),
                      activeThumbColor: Colors.orange,
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
                if (!l.byGramaje)
                  Row(
                    children: [
                      Expanded(
                        child: _field(l.deliveredCtrl, 'Entregado (kg)',
                            onChanged: _onQtyChanged),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(l.returnedCtrl, 'Devuelto (kg)',
                            onChanged: _onQtyChanged),
                      ),
                    ],
                  ),
                if (l.byGramaje) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _field(l.paquetesCtrl, 'Paquetes',
                            onChanged: () {
                              _recalcKg(l);
                              _onQtyChanged();
                            }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(l.gramajeCtrl, 'Gramaje (g)',
                            onChanged: () {
                              _recalcKg(l);
                              _onQtyChanged();
                            }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '≈ ${_fmt(_num(l.kgCalcCtrl))} kg',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _field(l.returnedCtrl, 'Devuelto (kg)',
                      onChanged: _onQtyChanged),
                ],
                if (!l.byGramaje) ...[
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
                ],
                const Divider(height: 18),
              ],
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
                  _newPaid > _total
                      ? 'Cambio: ${_c.format(_newPaid - _total)}'
                      : 'Restante: ${_c.format(_total - _newPaid)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _newPaid >= _total - 0.001
                        ? Colors.blue[700]
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () => _submit(complete: false),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Guardar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _submit(complete: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Completar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
