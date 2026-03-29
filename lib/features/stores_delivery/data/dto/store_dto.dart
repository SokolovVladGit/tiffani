class StoreDto {
  final String id;
  final String title;
  final String address;
  final String? phone;
  final String? workingHours;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final int sortOrder;

  const StoreDto({
    required this.id,
    required this.title,
    required this.address,
    required this.isActive,
    required this.sortOrder,
    this.phone,
    this.workingHours,
    this.latitude,
    this.longitude,
  });

  factory StoreDto.fromMap(Map<String, dynamic> map) {
    return StoreDto(
      id: map['id'] as String,
      title: map['title'] as String,
      address: map['address'] as String,
      phone: map['phone'] as String?,
      workingHours: map['working_hours'] as String?,
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      isActive: _toBool(map['is_active']),
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool _toBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}
