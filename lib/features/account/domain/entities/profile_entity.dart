class ProfileEntity {
  final String id;
  final String? name;
  final String? phone;
  final String? loyaltyCard;

  const ProfileEntity({
    required this.id,
    this.name,
    this.phone,
    this.loyaltyCard,
  });

  ProfileEntity copyWith({
    String? name,
    String? phone,
    String? loyaltyCard,
  }) {
    return ProfileEntity(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      loyaltyCard: loyaltyCard ?? this.loyaltyCard,
    );
  }
}
