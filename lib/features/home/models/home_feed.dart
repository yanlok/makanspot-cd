import 'restaurant_summary.dart';

class HomeFeed {
  const HomeFeed({
    required this.firstName,
    required this.location,
    required this.profileAsset,
    required this.recommended,
    required this.hiddenGems,
    required this.nearby,
    required this.newest,
  });

  const HomeFeed.empty()
    : firstName = '',
      location = '',
      profileAsset = '',
      recommended = const [],
      hiddenGems = const [],
      nearby = const [],
      newest = const [];

  final String firstName;
  final String location;
  final String profileAsset;
  final List<RestaurantSummary> recommended;
  final List<RestaurantSummary> hiddenGems;
  final List<RestaurantSummary> nearby;
  final List<RestaurantSummary> newest;

  bool get isEmpty =>
      recommended.isEmpty &&
      hiddenGems.isEmpty &&
      nearby.isEmpty &&
      newest.isEmpty;
}
