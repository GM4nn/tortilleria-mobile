import 'package:flutter/material.dart';

class OrderFilterChips extends StatelessWidget {
  final String label;
  final String selectedFilter;
  final Map<String, (String, IconData, Color)> filters;
  final ValueChanged<String> onFilterChanged;

  const OrderFilterChips({
    super.key,
    required this.label,
    required this.selectedFilter,
    required this.filters,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final entry = filters.entries.elementAt(index);
              final key = entry.key;
              final (text, icon, color) = entry.value;
              final isSelected = selectedFilter == key;

              return FilterChip(
                selected: isSelected,
                label: Text(text, style: const TextStyle(fontSize: 12)),
                avatar: Icon(icon, size: 14),
                selectedColor: color.withAlpha(40),
                checkmarkColor: color,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onFilterChanged(key),
              );
            },
          ),
        ),
      ],
    );
  }
}
