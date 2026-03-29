class DeliveryRuleDto {
  final String id;
  final String title;
  final String? description;
  final String? region;
  final bool isActive;
  final int sortOrder;

  const DeliveryRuleDto({
    required this.id,
    required this.title,
    required this.isActive,
    required this.sortOrder,
    this.description,
    this.region,
  });

  factory DeliveryRuleDto.fromMap(Map<String, dynamic> map) {
    return DeliveryRuleDto(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      region: map['region'] as String?,
      isActive: _toBool(map['is_active']),
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}

bool _toBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}
