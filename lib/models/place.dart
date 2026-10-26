import 'enums.dart';

class Place {
  const Place({
    required this.id,
    required this.nameEn,
    this.nameLocal,
    required this.destinationId,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.interests,
    required this.description,
    required this.suggestedDurationMinutes,
    this.bestSlots = const {},
    required this.source,
    this.verifiedOn,
    required this.verificationStatus,
    this.imageUrl,
    this.imageCredit,
  });

  final String id;
  final String nameEn;
  final String? nameLocal;
  final String destinationId;

  /// Neighbourhood or zone used to group nearby places on the same day.
  final String area;
  final double latitude;
  final double longitude;
  final PlaceCategory category;
  final Set<Interest> interests;
  final String description;

  /// Reference visit length. Editorial suggestion, not an official figure.
  final int suggestedDurationMinutes;

  /// Slots this place suits. Empty means any slot.
  final Set<DaySlot> bestSlots;
  final String source;
  final DateTime? verifiedOn;
  final VerificationStatus verificationStatus;

  /// Only set for images with a confirmed usage licence.
  final String? imageUrl;
  final String? imageCredit;

  bool suits(DaySlot slot) => bestSlots.isEmpty || bestSlots.contains(slot);

  /// Parses an entry of `assets/data/catalog.json`.
  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String,
        nameEn: json['name_en'] as String,
        nameLocal: json['name_local'] as String?,
        destinationId: json['destination_id'] as String,
        area: json['area'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        category: enumFromName(
            PlaceCategory.values, json['category'] as String?, PlaceCategory.landmark),
        interests: enumSetFromCsv(
            Interest.values, (json['interests'] as List).join(',')),
        description: json['description'] as String,
        suggestedDurationMinutes: (json['suggested_duration_min'] as num).toInt(),
        bestSlots: enumSetFromCsv(
            DaySlot.values, ((json['best_slots'] as List?) ?? const []).join(',')),
        source: json['source'] as String,
        verifiedOn: DateTime.tryParse(json['verified_on'] as String? ?? ''),
        verificationStatus: enumFromName(VerificationStatus.values,
            json['verification_status'] as String?, VerificationStatus.unverified),
        imageUrl: json['image_url'] as String?,
        imageCredit: json['image_credit'] as String?,
      );

  factory Place.fromMap(Map<String, Object?> map) => Place(
        id: map['id'] as String,
        nameEn: map['name_en'] as String,
        nameLocal: map['name_local'] as String?,
        destinationId: map['destination_id'] as String,
        area: map['area'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        category: enumFromName(
            PlaceCategory.values, map['category'] as String?, PlaceCategory.landmark),
        interests: enumSetFromCsv(Interest.values, map['interests'] as String?),
        description: map['description'] as String,
        suggestedDurationMinutes: (map['suggested_duration_min'] as num).toInt(),
        bestSlots: enumSetFromCsv(DaySlot.values, map['best_slots'] as String?),
        source: map['source'] as String,
        verifiedOn: DateTime.tryParse(map['verified_on'] as String? ?? ''),
        verificationStatus: enumFromName(VerificationStatus.values,
            map['verification_status'] as String?, VerificationStatus.unverified),
        imageUrl: map['image_url'] as String?,
        imageCredit: map['image_credit'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name_en': nameEn,
        'name_local': nameLocal,
        'destination_id': destinationId,
        'area': area,
        'latitude': latitude,
        'longitude': longitude,
        'category': category.name,
        'interests': enumSetToCsv(interests),
        'description': description,
        'suggested_duration_min': suggestedDurationMinutes,
        'best_slots': enumSetToCsv(bestSlots),
        'source': source,
        'verified_on': verifiedOn?.toIso8601String().substring(0, 10),
        'verification_status': verificationStatus.name,
        'image_url': imageUrl,
        'image_credit': imageCredit,
      };
}
