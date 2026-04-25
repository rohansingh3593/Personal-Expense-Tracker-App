import 'package:flutter/material.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({
    super.key,
    required this.incomeCategories,
    required this.expenseCategories,
    required this.subcategories,
    required this.budgets,
    required this.onUpdateIncomeCategories,
    required this.onUpdateExpenseCategories,
    required this.onUpdateSubcategories,
    required this.onUpdateBudgets,
  });

  final List<String> incomeCategories;
  final List<String> expenseCategories;
  final Map<String, List<String>> subcategories;
  final Map<String, double> budgets;
  final ValueChanged<List<String>> onUpdateIncomeCategories;
  final ValueChanged<List<String>> onUpdateExpenseCategories;
  final ValueChanged<Map<String, List<String>>> onUpdateSubcategories;
  final ValueChanged<Map<String, double>> onUpdateBudgets;

  @override
  Widget build(BuildContext context) {
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
              final updated = [...expenseCategories, name];
              onUpdateExpenseCategories(updated);
            },
          ),
        ),
        _ReorderableCategoryList(
          items: expenseCategories,
          onReorder: onUpdateExpenseCategories,
          onDelete: (name) {
            final updated = [...expenseCategories]..remove(name);
            final updatedSub = Map<String, List<String>>.from(subcategories)..remove(name);
            final updatedBudgets = Map<String, double>.from(budgets)..remove(name);
            onUpdateExpenseCategories(updated);
            onUpdateSubcategories(updatedSub);
            onUpdateBudgets(updatedBudgets);
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
              final value = controller.text.trim();
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
            final value = controller.text.trim();
            if (value.isNotEmpty) onAdd(value);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
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
