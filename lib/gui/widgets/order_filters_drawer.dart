import 'package:flutter/material.dart';

class OrderFiltersDrawer extends StatefulWidget {
  final String statusFilter;
  final String paymentFilter;
  final String orderIdSearch;
  final String customerSearch;
  final TimeOfDay? timeFrom;
  final TimeOfDay? timeTo;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onOrderIdChanged;
  final ValueChanged<String> onCustomerChanged;
  final ValueChanged<TimeOfDay?> onTimeFromChanged;
  final ValueChanged<TimeOfDay?> onTimeToChanged;
  final VoidCallback onClearFilters;

  const OrderFiltersDrawer({
    super.key,
    required this.statusFilter,
    required this.paymentFilter,
    required this.orderIdSearch,
    required this.customerSearch,
    required this.timeFrom,
    required this.timeTo,
    required this.onStatusChanged,
    required this.onPaymentChanged,
    required this.onOrderIdChanged,
    required this.onCustomerChanged,
    required this.onTimeFromChanged,
    required this.onTimeToChanged,
    required this.onClearFilters,
  });

  @override
  State<OrderFiltersDrawer> createState() => _OrderFiltersDrawerState();
}

class _OrderFiltersDrawerState extends State<OrderFiltersDrawer> {
  late TextEditingController _orderIdController;
  late TextEditingController _customerController;

  static const _statusOptions = [
    ('todos', 'Todos', Icons.list, Colors.blue),
    ('pendiente', 'Pendientes', Icons.schedule, Colors.orange),
    ('completado', 'Completados', Icons.check_circle, Colors.green),
    ('cancelado', 'Cancelados', Icons.cancel, Colors.red),
  ];

  static const _paymentOptions = [
    ('todos', 'Todos', Icons.list, Colors.blue),
    ('sin_pagar', 'Sin Pagar', Icons.money_off, Colors.red),
    ('parcial', 'Parcial', Icons.payments_outlined, Colors.orange),
    ('pagado', 'Pagado', Icons.paid, Colors.green),
  ];

  @override
  void initState() {
    super.initState();
    _orderIdController = TextEditingController(text: widget.orderIdSearch);
    _customerController = TextEditingController(text: widget.customerSearch);
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: theme.colorScheme.primary,
              child: const Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.white, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Filtros',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSearchField(
                    controller: _orderIdController,
                    label: 'Buscar por # de orden',
                    icon: Icons.tag,
                    keyboardType: TextInputType.number,
                    onChanged: widget.onOrderIdChanged,
                  ),
                  const SizedBox(height: 14),
                  _buildSearchField(
                    controller: _customerController,
                    label: 'Buscar por cliente',
                    icon: Icons.person_search,
                    onChanged: widget.onCustomerChanged,
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Rango de Horas'),
                  const SizedBox(height: 8),
                  _buildTimeRange(context),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Estado de Entrega'),
                  const SizedBox(height: 8),
                  _buildChipGroup(
                    _statusOptions,
                    widget.statusFilter,
                    widget.onStatusChanged,
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Estado de Pago'),
                  const SizedBox(height: 8),
                  _buildChipGroup(
                    _paymentOptions,
                    widget.paymentFilter,
                    widget.onPaymentChanged,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _orderIdController.clear();
                    _customerController.clear();
                    widget.onClearFilters();
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Limpiar Filtros'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.grey[700],
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildTimeRange(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildTimePicker(
            context,
            label: 'Desde',
            value: widget.timeFrom,
            onChanged: widget.onTimeFromChanged,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
        ),
        Expanded(
          child: _buildTimePicker(
            context,
            label: 'Hasta',
            value: widget.timeTo,
            onChanged: widget.onTimeToChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(
    BuildContext context, {
    required String label,
    required TimeOfDay? value,
    required ValueChanged<TimeOfDay?> onChanged,
  }) {
    final text = value != null
        ? '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}'
        : label;

    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value ?? TimeOfDay.now(),
        );
        if (picked != null) onChanged(picked);
      },
      onLongPress: () => onChanged(null),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(10),
          color: value != null ? Colors.blue.withAlpha(15) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time,
              size: 16,
              color: value != null ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: value != null ? Colors.blue[700] : Colors.grey[600],
                fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipGroup(
    List<(String, String, IconData, Color)> options,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: options.map((option) {
        final (key, label, icon, color) = option;
        final isSelected = selected == key;

        return ChoiceChip(
          selected: isSelected,
          label: Text(label, style: const TextStyle(fontSize: 12)),
          avatar: Icon(icon, size: 16),
          selectedColor: color.withAlpha(40),
          checkmarkColor: color,
          onSelected: (_) => onChanged(key),
        );
      }).toList(),
    );
  }
}
