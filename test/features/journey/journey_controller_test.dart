import 'package:flutter_test/flutter_test.dart';
import 'package:makanspot/features/community/models/community_models.dart';
import 'package:makanspot/features/journey/controllers/journey_controller.dart';
import 'package:makanspot/features/journey/models/journey_models.dart';
import 'package:makanspot/features/journey/models/journey_repository.dart';

void main() {
  group('JourneyController', () {
    test('records a new review across journey metrics', () async {
      final controller = JourneyController(_FixtureRepository());
      await controller.load();
      final before = controller.state.data!;
      final post = _post(restaurantId: 'rest-new');

      controller.recordReview(post, cuisine: 'Japanese');

      final data = controller.state.data!;
      expect(data.visits, hasLength(before.visits.length + 1));
      expect(data.visits.last.restaurantId, 'rest-new');
      expect(data.visits.last.cuisine, 'Japanese');
      expect(data.reviewCount, before.reviewCount + 1);
      expect(data.user.communityScore, before.user.communityScore + 15);
      expect(data.scoreHistory.first.description, contains('New Place'));
      expect(data.scoreHistory.first.points, 15);
    });

    test('counts a second review without duplicating the visit', () async {
      final controller = JourneyController(_FixtureRepository());
      await controller.load();
      final before = controller.state.data!;

      controller.recordReview(
        _post(restaurantId: 'rest-1'),
        cuisine: 'Malaysian',
      );

      expect(controller.state.data!.visits, hasLength(before.visits.length));
      expect(controller.state.data!.reviewCount, before.reviewCount + 1);
      expect(
        controller.state.data!.user.communityScore,
        before.user.communityScore + 10,
      );
      expect(controller.state.data!.scoreHistory, hasLength(1));
    });

    test('filters visits by restaurant and cuisine', () async {
      final controller = JourneyController(_FixtureRepository());
      await controller.load();

      controller.updateVisitSearch('chinese');

      expect(controller.state.filteredVisits, hasLength(1));
      expect(controller.state.filteredVisits.single.cuisine, 'Chinese');
    });

    test('exposes a recoverable error when loading fails', () async {
      final controller = JourneyController(_FailingRepository());

      await controller.load();

      expect(controller.state.status, JourneyStatus.error);
      expect(controller.state.errorMessage, isNotEmpty);
    });
  });
}

CommunityPost _post({required String restaurantId}) {
  return CommunityPost(
    id: 'post-new',
    userId: 'demo-user',
    username: 'Yih Loong',
    userAvatar: '',
    profileTitle: 'Hidden Gem Hunter',
    restaurantId: restaurantId,
    restaurantName: 'New Place',
    restaurantImage: 'image',
    reviewText: 'Great food',
    rating: 5,
    mediaUrls: const [],
    likes: 0,
    isLiked: false,
    status: 'active',
    createdAt: DateTime(2026, 8, 3),
  );
}

class _FixtureRepository implements JourneyRepository {
  @override
  Future<JourneyData> loadJourney() async => JourneyData(
    user: const JourneyUser(
      username: 'User',
      email: 'user@example.com',
      profileTitle: 'Explorer',
      communityScore: 20,
      profileAsset: 'asset',
    ),
    visits: [
      JourneyVisit(
        id: 'visit-1',
        restaurantId: 'rest-1',
        restaurantName: 'Malaysian Place',
        restaurantImage: 'image',
        cuisine: 'Malaysian',
        visitDate: DateTime(2026, 8, 1),
        postId: 'post-1',
      ),
      JourneyVisit(
        id: 'visit-2',
        restaurantId: 'rest-2',
        restaurantName: 'Chinese Place',
        restaurantImage: 'image',
        cuisine: 'Chinese',
        visitDate: DateTime(2026, 8, 2),
        postId: 'post-2',
      ),
    ],
    locations: const [],
    reviewCount: 2,
    totalLikes: 0,
    achievements: const [],
    scoreHistory: const [],
  );
}

class _FailingRepository implements JourneyRepository {
  @override
  Future<JourneyData> loadJourney() async => throw StateError('offline');
}
