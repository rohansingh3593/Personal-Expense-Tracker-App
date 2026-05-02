import 'package:flutter/material.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({
    super.key,
    required this.incomeCategories,
    required this.expenseCategories,
    required this.activeExpenseCategories,
    required this.onUpdateArchivedExpenseCategories,
    required this.subcategories,
    required this.budgets,
    required this.onUpdateIncomeCategories,
    required this.onUpdateExpenseCategories,
    required this.onUpdateSubcategories,
    required this.onUpdateBudgets,
    required this.selectedThemePalette,
    required this.onThemeChanged,
  });

  final List<String> incomeCategories;
  final List<String> expenseCategories;
  final List<String> activeExpenseCategories;
  final Map<String, List<String>> subcategories;
  final Map<String, double> budgets;
  final ValueChanged<List<String>> onUpdateIncomeCategories;
  final ValueChanged<List<String>> onUpdateExpenseCategories;
  final ValueChanged<Map<String, List<String>>> onUpdateSubcategories;
  final ValueChanged<Map<String, double>> onUpdateBudgets;
  final ValueChanged<Set<String>> onUpdateArchivedExpenseCategories;
  final String selectedThemePalette;
  final ValueChanged<String> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final current = _themeInfo(selectedThemePalette);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _SectionTitle(
          title: 'Income Categories',
          onAdd: () => _addCategoryDialog(
            context,
            'income',
            onAdd: (name) {
              final updated = [...incomeCategories, name];
              onUpdateIncomeCategories(updated);
            },
          ),
        ),
        _ReorderableCategoryList(
          items: incomeCategories,
          onReorder: onUpdateIncomeCategories,
          onDelete: (name) {
            final updated = [...incomeCategories]..remove(name);
            onUpdateIncomeCategories(updated);
          },
        ),
        const SizedBox(height: 12),
        _SectionTitle(
          title: 'Expense Categories',
          onAdd: () => _addCategoryDialog(
            context,
            'expense',
            onAdd: (name) {
              final updated = [...expenseCategories, _toTitleCase(name)];
              onUpdateExpenseCategories(updated);
            },
          ),
        ),
        _ReorderableCategoryList(
          items: activeExpenseCategories,
          onReorder: onUpdateExpenseCategories,
          onDelete: (name) {
            final archived = expenseCategories.where((category) => !activeExpenseCategories.contains(category)).toSet();
            archived.add(name);
            onUpdateArchivedExpenseCategories(archived);
          },
        ),
        const SizedBox(height: 12),
        const Text('Subcategories', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...expenseCategories.map(
          (category) {
            final items = subcategories[category] ?? const <String>[];
            return Card(
              child: ExpansionTile(
                title: Text(category),
                subtitle: Text(items.isEmpty ? 'No subcategories' : items.join(', ')),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addSubcategoryDialog(
                    context,
                    category,
                    onAdd: (name) {
                      final updatedSub = Map<String, List<String>>.from(subcategories);
                      final list = [...(updatedSub[category] ?? const <String>[])];
                      list.add(name);
                      updatedSub[category] = list;
                      onUpdateSubcategories(updatedSub);
                    },
                  ),
                ),
                children: items
                    .map(
                      (s) => ListTile(
                        dense: true,
                        title: Text(s),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            final updatedSub = Map<String, List<String>>.from(subcategories);
                            final list = [...(updatedSub[category] ?? const <String>[])];
                            list.remove(s);
                            updatedSub[category] = list;
                            onUpdateSubcategories(updatedSub);
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        const Text('Theme', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Card(
          child: ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Change App Theme'),
            subtitle: Text('Current: ${current.name} (${current.colors.join(', ')})'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemePicker(context),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Budget Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...expenseCategories.map(
          (category) {
            final value = budgets[category] ?? 0;
            return Card(
              child: ListTile(
                title: Text(category),
                subtitle: Text('Current budget: ₹${value.toStringAsFixed(0)}'),
                trailing: const Icon(Icons.edit),
                onTap: () => _setBudgetDialog(
                  context,
                  category,
                  value,
                  onSave: (amount) {
                    final updated = Map<String, double>.from(budgets);
                    updated[category] = amount;
                    onUpdateBudgets(updated);
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showThemePicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ..._themePickerKeys.map((key) => _themeOptionTile(context, key)),
          ],
        ),
      ),
    );
    if (selected != null && selected != selectedThemePalette) {
      onThemeChanged(selected);
    }
  }

  Widget _themeOptionTile(BuildContext context, String key) {
    final info = _themeInfo(key);
    final isSelected = selectedThemePalette == key;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(info.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: info.colors
                .map(
                  (hex) => Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _hexToColor(hex),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          Text(info.colors.join('  ')),
        ],
      ),
      isThreeLine: true,
      onTap: () => Navigator.of(context).pop(key),
    );
  }
}

ThemePaletteInfo _themeInfo(String key) {
  switch (key) {
    case 'legacy_green':
      return const ThemePaletteInfo(
        name: 'Green palette',
        colors: ['#468432', '#9AD872', '#FEF9E7', '#FAA02E'],
      );
    case 'legacy_blue':
      return const ThemePaletteInfo(
        name: 'Blue palette',
        colors: ['#2F2FE4', '#162E93', '#1A1953', '#080616'],
      );
    case 'legacy_orange':
      return const ThemePaletteInfo(
        name: 'Orange palette',
        colors: ['#FF5A5A', '#FF8B5A', '#FFA95A', '#FFD45A'],
      );
    case 'legacy_red':
      return const ThemePaletteInfo(
        name: 'Red palette',
        colors: ['#BF1A1A', '#FF6C0C', '#FEE08F', '#060771'],
      );
    case 'legacy_mono':
      return const ThemePaletteInfo(
        name: 'Black/White palette',
        colors: ['#202940', '#4B4038', '#9A8678', '#CAAA98'],
      );
    case 'blue':
      return const ThemePaletteInfo(
        name: 'Stormy Morning',
        colors: ['#6A89A7', '#BDDDFC', '#88BDF2', '#384959'],
      );
    case 'green':
      return const ThemePaletteInfo(
        name: 'Mossy Hollow',
        colors: ['#636B2F', '#BAC095', '#D4DE95', '#3D4127'],
      );
    case 'blue_eclipse':
      return const ThemePaletteInfo(
        name: 'Blue eclipse',
        colors: ['#272757', '#8686AC', '#505081', '#0F0E47'],
      );
    case 'lush_forest':
      return const ThemePaletteInfo(
        name: 'Lush forest',
        colors: ['#2E6F40', '#CFFFDC', '#68BA7F', '#253D2C'],
      );
    case 'green_juice':
      return const ThemePaletteInfo(
        name: 'Green juice',
        colors: ['#4CBB17', '#48872B', '#39542C', '#293325'],
      );
    case 'orange':
      return const ThemePaletteInfo(
        name: 'Chocolate Truffle',
        colors: ['#713600', '#C05800', '#FDFBD4', '#38240D'],
      );
    case 'red':
      return const ThemePaletteInfo(
        name: 'Chili Spice',
        colors: ['#CD1C18', '#FFA896', '#9B1313', '#38000A'],
      );
    case 'wisteria_bloom':
      return const ThemePaletteInfo(
        name: 'Wisteria bloom',
        colors: ['#D3D3FF', '#9400D3', '#D8BFD8', '#ED80E9'],
      );
    case 'blooming_romance':
      return const ThemePaletteInfo(
        name: 'Blooming romance',
        colors: ['#660033', '#E673AC', '#469110', '#00520A'],
      );
    case 'lavender_fields':
      return const ThemePaletteInfo(
        name: 'Lavender fields',
        colors: ['#FDFBD4', '#BDB96A', '#C1BFFF', '#CF6DFC'],
      );
    case 'mono':
    case 'stormy_ink':
      return const ThemePaletteInfo(
        name: 'Stormy Ink',
        colors: ['#202940', '#4B4038', '#9A8678', '#CAAA98'],
      );
    default:
      return const ThemePaletteInfo(
        name: 'Stormy Morning',
        colors: ['#6A89A7', '#BDDDFC', '#88BDF2', '#384959'],
      );
  }
}

const List<String> _themePickerKeys = [
  'legacy_green',
  'legacy_blue',
  'legacy_orange',
  'legacy_red',
  'legacy_mono',
  'blue',
  'green',
  'blue_eclipse',
  'lush_forest',
  'green_juice',
  'orange',
  'red',
  'wisteria_bloom',
  'blooming_romance',
  'lavender_fields',
];

Color _hexToColor(String hex) {
  final normalized = hex.replaceAll('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}

class ThemePaletteInfo {
  const ThemePaletteInfo({
    required this.name,
    required this.colors,
  });

  final String name;
  final List<String> colors;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline)),
      ],
    );
  }
}

class _ReorderableCategoryList extends StatelessWidget {
  const _ReorderableCategoryList({
    required this.items,
    required this.onReorder,
    required this.onDelete,
  });

  final List<String> items;
  final ValueChanged<List<String>> onReorder;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No categories yet.');

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) {
        final updated = [...items];
        if (newIndex > oldIndex) newIndex -= 1;
        final item = updated.removeAt(oldIndex);
        updated.insert(newIndex, item);
        onReorder(updated);
      },
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          key: ValueKey(item),
          title: Text(item),
          leading: const Icon(Icons.drag_indicator),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => onDelete(item),
          ),
        );
      },
    );
  }
}

Future<void> _addCategoryDialog(
  BuildContext context,
  String type, {
  required ValueChanged<String> onAdd,
}) async {
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Add $type category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final value = _toTitleCase(controller.text.trim());
              if (value.isNotEmpty) onAdd(value);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
}

Future<void> _addSubcategoryDialog(
  BuildContext context,
  String category, {
  required ValueChanged<String> onAdd,
}) async {
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Add subcategory to $category'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Subcategory name'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final value = _toTitleCase(controller.text.trim());
            if (value.isNotEmpty) onAdd(value);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}

String _toTitleCase(String raw) {
  final words = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}');
  return words.join(' ');
}

Future<void> _setBudgetDialog(
  BuildContext context,
  String category,
  double current, {
  required ValueChanged<double> onSave,
}) async {
  final controller = TextEditingController(text: current == 0 ? '' : current.toStringAsFixed(0));
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Set budget for $category'),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '5000'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final value = double.tryParse(controller.text.trim());
            if (value != null && value >= 0) onSave(value);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
