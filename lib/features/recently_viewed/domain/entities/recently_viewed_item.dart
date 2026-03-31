class RecentlyViewedItem {
  final String id;
  final String title;
  final String? imageUrl;
  final double? price;
  final double? oldPrice;
  final String? brand;

  const RecentlyViewedItem({
    required this.id,
    required this.title,
    this.imageUrl,
    this.price,
    this.oldPrice,
    this.brand,
  });
}
