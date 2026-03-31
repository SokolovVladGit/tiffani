import '../../domain/entities/recently_viewed_item.dart';

class RecentlyViewedState {
  final List<RecentlyViewedItem> items;
  final bool isLoading;

  const RecentlyViewedState({
    this.items = const [],
    this.isLoading = false,
  });

  bool get hasItems => items.isNotEmpty;

  RecentlyViewedState copyWith({
    List<RecentlyViewedItem>? items,
    bool? isLoading,
  }) {
    return RecentlyViewedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
