class RestaurantSummary {
  const RestaurantSummary({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.budget,
    required this.isHiddenGem,
    required this.labels,
    required this.imageUrl,
    this.rating,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String cuisine;
  final String budget;
  final bool isHiddenGem;
  final List<String> labels;
  final String imageUrl;
  final double? rating;
  final double? distanceKm;
}
