import 'package:flutter/material.dart';
import '../../data/models/order_model.dart';

/// Diálogo con un input grande para escribir la descripción / notas del pedido.
/// Devuelve el texto guardado (o null si se canceló).
class NotesDialog extends StatefulWidget {
  final OrderModel order;
  const NotesDialog({super.key, required this.order});

  static Future<String?> show(BuildContext context, OrderModel order) {
    return showDialog<String>(
      context: context,
      builder: (_) => NotesDialog(order: order),
    );
  }

  @override
  State<NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<NotesDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.order.notes ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Notas · ${widget.order.customerName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escribe cualquier detalle del pedido (indicaciones de entrega, '
              'referencias, pendientes, etc.).',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 8,
              minLines: 6,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: 'Ej. Dejar en la puerta de atrás, preguntar por Doña Mari…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
