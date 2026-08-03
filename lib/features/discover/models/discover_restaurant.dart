import 'package:flutter/foundation.dart';

@immutable
class DiscoverRestaurant {
  const DiscoverRestaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.budget,
    required this.isHiddenGem,
    required this.labels,
    required this.imageUrl,
    required this.createdAt,
    required this.address,
    required this.description,
    required this.operatingHours,
    this.contact,
    this.rating,
    this.distanceKm,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String cuisine;
  final String budget;
  final bool isHiddenGem;
  final List<String> labels;
  final String imageUrl;
  final DateTime createdAt;
  final String address;
  final String description;
  final String operatingHours;
  final String? contact;
  final double? rating;
  final double? distanceKm;
  final double? latitude;
  final double? longitude;
}

@immutable
class RestaurantReview {
  const RestaurantReview({
    required this.id,
    required this.username,
    required this.profileTitle,
    required this.reviewText,
    required this.avatarUrl,
    required this.imageUrl,
    required this.likes,
    required this.isLiked,
  });

  final String id;
  final String username;
  final String profileTitle;
  final String reviewText;
  final String avatarUrl;
  final String imageUrl;
  final int likes;
  final bool isLiked;

  RestaurantReview copyWith({int? likes, bool? isLiked}) {
    return RestaurantReview(
      id: id,
      username: username,
      profileTitle: profileTitle,
      reviewText: reviewText,
      avatarUrl: avatarUrl,
      imageUrl: imageUrl,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

@immutable
class RestaurantDetailsData {
  const RestaurantDetailsData({
    required this.restaurant,
    required this.reviews,
  });

  final DiscoverRestaurant restaurant;
  final List<RestaurantReview> reviews;
}
