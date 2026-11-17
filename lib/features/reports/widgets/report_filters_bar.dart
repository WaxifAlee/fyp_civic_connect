import 'package:flutter/material.dart';
import '../domain/report_filters.dart';

/// A quiet search row with secondary controls disclosed only when needed.
class ReportFiltersBar extends StatelessWidget {
  const ReportFiltersBar(
      {super.key,
      required this.search,
      required this.category,
      required this.status,
      required this.sort,
      required this.onSearchChanged,
      required this.onChanged,
      required this.onReset});
  final TextEditingController search;
  final String? category;
  final ReportStatus? status;
  final ReportSort sort;
  final ValueChanged<String> onSearchChanged;
  final void Function(String?, ReportStatus?, ReportSort) onChanged;
  final VoidCallback onReset;
  int get _active =>
      (category != null ? 1 : 0) +
      (status != null ? 1 : 0) +
      (sort != ReportSort.newest ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final searchField = TextField(
        controller: search,
        onChanged: onSearchChanged,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
            labelText: 'Search reports',
            hintText: 'Title or reference',
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      search.clear();
                      onSearchChanged('');
                    })));
    final filters = OutlinedButton.icon(
        onPressed: () => _showFilters(context),
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14)),
        icon: const Icon(Icons.tune, size: 18),
        label: Text(_active == 0 ? 'Filters' : 'Filters · $_active'));
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (MediaQuery.textScalerOf(context).scale(1) > 1.4) ...[
            searchField,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: filters),
          ] else
            Row(children: [
              Expanded(child: searchField),
              const SizedBox(width: 8),
              filters
            ]),
          if (_active > 0) ...[
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (category != null)
                    _summary(context, categoryLabel(category)),
                  if (status != null) _summary(context, status!.label),
                  if (sort != ReportSort.newest)
                    _summary(context, _sortLabel(sort)),
                  TextButton(onPressed: onReset, child: const Text('Reset')),
                ]),
          ],
        ]);
  }

  Widget _summary(BuildContext context, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall));
  static String _sortLabel(ReportSort value) => switch (value) {
        ReportSort.newest => 'Newest first',
        ReportSort.oldest => 'Oldest first',
        ReportSort.mostSupported => 'Most supported',
      };
  Future<void> _showFilters(BuildContext context) async {
    var draftCategory = category;
    var draftStatus = status;
    var draftSort = sort;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (context) => StatefulBuilder(
            builder: (context, update) => SafeArea(
                top: false,
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text('Filter reports',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge)),
                            IconButton(
                                tooltip: 'Close filters',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close))
                          ]),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                              key: ValueKey('category-$draftCategory'),
                              initialValue: draftCategory ?? '',
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Category'),
                              items: [
                                const DropdownMenuItem(
                                    value: '', child: Text('All categories')),
                                for (final c in reportCategories)
                                  DropdownMenuItem(
                                      value: c.value,
                                      child: Text(c.label,
                                          overflow: TextOverflow.ellipsis))
                              ],
                              onChanged: (value) => update(() =>
                                  draftCategory = value == '' ? null : value)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<ReportStatus>(
                              key: const ValueKey('filter-status'),
                              initialValue: draftStatus ?? ReportStatus.unknown,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Status'),
                              items: [
                                const DropdownMenuItem(
                                    value: ReportStatus.unknown,
                                    child: Text('All statuses')),
                                for (final s in ReportStatus.values
                                    .where((s) => s != ReportStatus.unknown))
                                  DropdownMenuItem(
                                      value: s, child: Text(s.label))
                              ],
                              onChanged: (value) => update(() => draftStatus =
                                  value == ReportStatus.unknown
                                      ? null
                                      : value)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<ReportSort>(
                              key: ValueKey('sort-$draftSort'),
                              initialValue: draftSort,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Sort by'),
                              items: [
                                for (final s in ReportSort.values)
                                  DropdownMenuItem(
                                      value: s, child: Text(_sortLabel(s)))
                              ],
                              onChanged: (value) => update(() =>
                                  draftSort = value ?? ReportSort.newest)),
                          const SizedBox(height: 24),
                          Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                TextButton(
                                    onPressed: () => update(() {
                                          draftCategory = null;
                                          draftStatus = null;
                                          draftSort = ReportSort.newest;
                                        }),
                                    child: const Text('Reset filters')),
                                FilledButton(
                                    onPressed: () {
                                      onChanged(draftCategory, draftStatus,
                                          draftSort);
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Show reports')),
                              ]),
                        ])))));
  }
}
