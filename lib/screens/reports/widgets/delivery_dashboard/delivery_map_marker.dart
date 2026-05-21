class DeliveryMapMarker {
  final String id;
  final double latitude;
  final double longitude;
  final String title;
  final String? snippet;

  const DeliveryMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.snippet,
  });
}
