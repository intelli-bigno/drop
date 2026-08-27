import 'drop_json.dart';

/// DropCore `Tag.swift` 대응.
class Tag {
  final String id;
  final String name;
  final DateTime createdAt;

  const Tag({required this.id, required this.name, required this.createdAt});

  factory Tag.fromJson(Map<String, Object?> json) => Tag(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: parsePostgresTimestamp(json['created_at'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is Tag &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, createdAt);

  @override
  String toString() => 'Tag($id, $name)';
}
