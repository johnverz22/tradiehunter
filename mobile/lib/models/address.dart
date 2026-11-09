class AddressCandidate {
  final String id;
  final String address;
  final String? suburb;
  final String? city;
  final double latitude;
  final double longitude;

  const AddressCandidate({
    required this.id,
    required this.address,
    this.suburb,
    this.city,
    required this.latitude,
    required this.longitude,
  });

  factory AddressCandidate.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num).toDouble();
    final longitude = (json['longitude'] as num).toDouble();
    final id = json['id'] as String;
    final address = json['address'] as String;
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        id.trim().isEmpty ||
        address.trim().isEmpty) {
      throw const FormatException('Invalid address result');
    }
    return AddressCandidate(
      id: id,
      address: address,
      suburb: json['suburb'] as String?,
      city: json['city'] as String?,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class AddressSearchResult {
  final String provider;
  final String attribution;
  final String attributionUrl;
  final List<AddressCandidate> items;

  const AddressSearchResult({
    required this.provider,
    required this.attribution,
    required this.attributionUrl,
    required this.items,
  });

  factory AddressSearchResult.fromJson(Map<String, dynamic> json) =>
      AddressSearchResult(
        provider: json['provider'] as String,
        attribution: json['attribution'] as String,
        attributionUrl: json['attributionUrl'] as String,
        items: (json['items'] as List)
            .map(
              (item) => AddressCandidate.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}
