import 'package:flutter_test/flutter_test.dart';
import 'package:makanspot/features/community/controllers/user_posts_controller.dart';
import 'package:makanspot/features/community/models/fixture_community_repository.dart';

void main() {
  group('UserPostsController', () {
    test('loads only the selected member’s active posts', () async {
      final controller = UserPostsController(
        FixtureCommunityRepository(),
        'demo-user',
      );

      await controller.load();

      expect(controller.state.status, UserPostsStatus.content);
      expect(controller.state.posts, hasLength(1));
      expect(controller.state.posts.single.id, 'post-1');
      expect(controller.state.posts.single.status, 'active');
    });
  });
}
