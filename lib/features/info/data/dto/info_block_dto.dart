import 'dart:convert';

class InfoBlockDto {
  final String id;
  final String blockType;
  final int sortOrder;
  final String? title;
  final String? subtitle;
  final String? textContent;
  final String? imageUrl;
  final Map<String, dynamic>? itemsJson;
  final bool isActive;

  const InfoBlockDto({
    required this.id,
    required this.blockType,
    required this.sortOrder,
    this.title,
    this.subtitle,
    this.textContent,
    this.imageUrl,
    this.itemsJson,
    this.isActive = true,
  });

  factory InfoBlockDto.fromMap(Map<String, dynamic> map) {
    return InfoBlockDto(
      id: map['id'] as String,
      blockType: map['block_type'] as String,
      sortOrder: (map['sort_order'] as num).toInt(),
      title: map['title'] as String?,
      subtitle: map['subtitle'] as String?,
      textContent: map['text_content'] as String?,
      imageUrl: map['image_url'] as String?,
      itemsJson: _safeJsonMap(map['items_json']),
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  /// Handles JSONB arriving as decoded Map, raw Map, JSON-encoded String, or null.
  static Map<String, dynamic>? _safeJsonMap(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
