class DeliveryRuleEntity {
  final String id;
  final String title;
  final String? description;
  final String? region;
  final bool isActive;
  final int sortOrder;

  const DeliveryRuleEntity({
    required this.id,
    required this.title,
    required this.isActive,
    required this.sortOrder,
    this.description,
    this.region,
  });
}
