import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/order_model.dart';

class PaymentDialog extends StatefulWidget {
  final OrderModel order;

  const PaymentDialog({super.key, required this.order});

  static Future<double?> show(BuildContext context, OrderModel order) {
    return showDialog<double>(
      context: context,
      builder: (_) => PaymentDialog(order: order),
    );
  }

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late final TextEditingController _controller;
  String? _error;

  double get _remaining => widget.order.remainingBalance;

  static final _currency = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return AlertDialog(
      title: Text('Registrar pago · ${order.customerName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow('Total', order.total),
          _buildRow('Pagado', order.amountPaid, color: Colors.green),
          _buildRow('Restante', _remaining, color: Colors.red, bold: true),
          const Divider(height: 24),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Monto a abonar',
              prefixText: '\$ ',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Registrar Abono'),
        ),
      ],
    );
  }

  Widget _buildRow(
    String label,
    double amount, {
    Color? color,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            _currency.format(amount),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _confirm() {
    final parsed = double.tryParse(_controller.text);

    if (parsed == null || parsed <= 0) {
      setState(() => _error = 'Ingrese un monto válido');
      return;
    }

    // El dinero se maneja a 2 decimales: evita que un tercer decimal (ej. 70.501)
    // se cuele y termine excediendo el total del pedido.
    final amount = (parsed * 100).round() / 100;

    if (amount > _remaining + 0.001) {
      setState(() => _error = 'No puede exceder ${_currency.format(_remaining)}');
      return;
    }

    Navigator.pop(context, amount);
  }
}
