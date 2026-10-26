class Destination {
  const Destination({
    required this.id,
    required this.name,
    this.localName,
    required this.region,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? localName;
  final String region;
  final String description;
  final double latitude;
  final double longitude;
  final int sortOrder;

  factory Destination.fromMap(Map<String, Object?> map) => Destination(
        id: map['id'] as String,
        name: map['name'] as String,
        localName: map['local_name'] as String?,
        region: map['region'] as String,
        description: map['description'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'local_name': localName,
        'region': region,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'sort_order': sortOrder,
      };
}
