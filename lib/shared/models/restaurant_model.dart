class RestaurantModel {
  final String id;
  final String name;
  final String? description;
  final String address;
  final double latitude;
  final double longitude;
  final String priceRange;
  final double rating;
  final int reviewCount;
  final Map<String, dynamic>? operatingHours;
  final String? phoneNumber;
  final String? socialMediaSource;
  final String? postUrl;
  final int popularityScore;
  final bool isHiddenGem;
  final bool isTrending;
  final bool isApproved;
  final DateTime? lastUpdated;
  final List<String>? imageUrls;

  RestaurantModel({
    required this.id,
    required this.name,
    this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.priceRange,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.operatingHours,
    this.phoneNumber,
    this.socialMediaSource,
    this.postUrl,
    this.popularityScore = 0,
    this.isHiddenGem = false,
    this.isTrending = false,
    this.isApproved = false,
    this.lastUpdated,
    this.imageUrls,
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    return RestaurantModel(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      priceRange: json['price_range'] as String,
      rating: (json['rating'] as num? ?? 0.0).toDouble(),
      reviewCount: json['review_count'] as int? ?? 0,
      operatingHours: json['operating_hours'] as Map<String, dynamic>?,
      phoneNumber: json['phone_number'] as String?,
      socialMediaSource: json['social_media_source'] as String?,
      postUrl: json['post_url'] as String?,
      popularityScore: json['popularity_score'] as int? ?? 0,
      isHiddenGem: json['is_hidden_gem'] as bool? ?? false,
      isTrending: json['is_trending'] as bool? ?? false,
      isApproved: json['is_approved'] as bool? ?? false,
      lastUpdated: json['last_updated'] != null ? DateTime.parse(json['last_updated'] as String) : null,
      imageUrls: json['imageUrls'] != null ? List<String>.from(json['imageUrls'] as List) : null,
    );
  }
}
