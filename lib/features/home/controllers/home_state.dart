import 'package:flutter/foundation.dart';

import '../models/home_feed.dart';

enum HomeStatus { loading, content, empty, error }

@immutable
class HomeState {
  const HomeState({
    required this.status,
    required this.greeting,
    required this.bookmarkedIds,
    this.feed,
    this.errorMessage,
  });

  const HomeState.loading({required String greeting})
    : this(
        status: HomeStatus.loading,
        greeting: greeting,
        bookmarkedIds: const {},
      );

  final HomeStatus status;
  final String greeting;
  final HomeFeed? feed;
  final Set<String> bookmarkedIds;
  final String? errorMessage;

  HomeState copyWith({
    HomeStatus? status,
    HomeFeed? feed,
    Set<String>? bookmarkedIds,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      greeting: greeting,
      feed: feed ?? this.feed,
      bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
      errorMessage: errorMessage,
    );
  }
}
