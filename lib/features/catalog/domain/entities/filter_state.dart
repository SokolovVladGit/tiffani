class FilterState {
  final Map<String, Set<String>> selected;

  const FilterState({this.selected = const {}});

  factory FilterState.initial() => const FilterState();

  bool get hasActiveFilters => selected.isNotEmpty;

  bool isSelected(String key, String value) =>
      selected[key]?.contains(value) ?? false;

  FilterState copyWith({
    Map<String, Set<String>>? selected,
  }) {
    return FilterState(selected: selected ?? this.selected);
  }
}
