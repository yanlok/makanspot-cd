import 'dart:convert';

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
    this.googleMapsUrl,
    this.city,
    this.categories = const [],
    this.popularityScore = 0,
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
  final String? googleMapsUrl;
  final String? city;
  final List<String> categories;
  final int popularityScore;
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

/// Formats raw operating hours (JSON string, Map, List, or text) into a clean,
/// human-readable multi-line string. Returns '-' if missing or unavailable.
String formatOperatingHours(Object? raw) {
  if (raw == null) return '-';

  Object? parsed = raw;
  if (raw is String) {
    var text = raw.trim();
    if (text.isEmpty ||
        text == '-' ||
        text == '{}' ||
        text == '[]' ||
        text == '""') {
      return '-';
    }
    while ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']')) ||
        (text.startsWith('"') && text.endsWith('"') && text.length >= 2)) {
      try {
        parsed = jsonDecode(text);
        if (parsed is String) {
          text = parsed.trim();
        } else {
          break;
        }
      } catch (_) {
        break;
      }
    }
  }

  if (parsed is Map) {
    if (parsed.isEmpty) return '-';
    if (parsed.containsKey('status')) {
      final res = formatOperatingHours(parsed['status']);
      if (res != '-') return res;
    }
    if (parsed.containsKey('hours')) {
      final res = formatOperatingHours(parsed['hours']);
      if (res != '-') return res;
    }
    if (parsed.containsKey('periods')) {
      final res = formatOperatingHours(parsed['periods']);
      if (res != '-') return res;
    }
    final lines = <String>[];
    for (final entry in parsed.entries) {
      final key = entry.key.toString().trim();
      final val = entry.value;
      if (val is List) {
        final joinedTimes = val
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .join(', ');
        if (joinedTimes.isNotEmpty) {
          lines.add('$key: $joinedTimes');
        }
      } else if (val != null) {
        final strVal = val.toString().trim();
        if (strVal.isNotEmpty && strVal != '{}' && strVal != '[]') {
          lines.add('$key: $strVal');
        }
      }
    }
    if (lines.isNotEmpty) {
      return lines.join('\n');
    }
    return '-';
  }

  if (parsed is List) {
    if (parsed.isEmpty) return '-';
    final lines = parsed
        .map((item) {
          if (item is Map || item is List) {
            return formatOperatingHours(item);
          }
          return item?.toString().trim() ?? '';
        })
        .where(
          (item) =>
              item.isNotEmpty &&
              item != '-' &&
              item != '{}' &&
              item != '[]',
        )
        .toList();
    if (lines.isEmpty) return '-';
    return lines.join('\n');
  }

  final text = parsed.toString().trim();
  if (text.isEmpty || text == '-' || text == '{}' || text == '[]') {
    return '-';
  }

  return _splitIntoCleanLines(text);
}

String _splitIntoCleanLines(String text) {
  if (text.contains('\n')) return text;

  final daySplitRegex = RegExp(
    r',\s*(?=(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun|Daily|Closed)\b)',
    caseSensitive: false,
  );
  if (daySplitRegex.hasMatch(text)) {
    return text
        .split(daySplitRegex)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
  }

  return text;
}
