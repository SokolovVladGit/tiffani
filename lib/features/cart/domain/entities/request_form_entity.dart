class RequestFormEntity {
  final String name;
  final String phone;
  final String? comment;

  const RequestFormEntity({
    required this.name,
    required this.phone,
    this.comment,
  });
}
