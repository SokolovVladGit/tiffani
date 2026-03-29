class StoreEntity {
  final String id;
  final String title;
  final String address;
  final String? phone;
  final String? workingHours;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final int sortOrder;

  const StoreEntity({
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
}
