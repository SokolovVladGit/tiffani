import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/filter_state.dart';

class FilterCubit extends Cubit<FilterState> {
  FilterCubit() : super(FilterState.initial());

  void toggle(String key, String value) {
    final current = {
      for (final e in state.selected.entries) e.key: Set<String>.from(e.value),
    };
    final values = current[key] ?? {};

    if (values.contains(value)) {
      values.remove(value);
      if (values.isEmpty) {
        current.remove(key);
      } else {
        current[key] = values;
      }
    } else {
      current[key] = {...values, value};
    }

    emit(FilterState(selected: current));
  }

  void clear() => emit(FilterState.initial());
}
