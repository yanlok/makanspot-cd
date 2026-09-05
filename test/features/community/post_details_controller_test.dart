import 'package:flutter_test/flutter_test.dart';
import 'package:makanspot/features/community/controllers/post_details_controller.dart';
import 'package:makanspot/features/community/models/fixture_community_repository.dart';

void main() {
  group('PostDetailsController', () {
    test('does not add a top-level comment to the current user’s own post', () async {
      final controller = PostDetailsController(
        FixtureCommunityRepository(),
        'post-1',
      );
      await controller.load();
      final initialCount = controller.state.comments.length;

      expect(controller.state.post!.isOwn, isTrue);

      await controller.addComment('Attempted comment on own post');

      expect(controller.state.comments, hasLength(initialCount));
      expect(controller.state.post!.commentCount, initialCount);
    });

    test('does not add a reply to the current user’s own comment', () async {
      final controller = PostDetailsController(
        FixtureCommunityRepository(),
        'post-2',
      );
      await controller.load();
      expect(controller.state.post!.isOwn, isFalse);

      await controller.addComment('My top-level comment on another post');

      final ownComment = controller.state.comments.first;
      final commentCount = controller.state.comments.length;

      expect(ownComment.isOwn, isTrue);

      await controller.addComment(
        'This reply must not be posted.',
        parentCommentId: ownComment.id,
      );

      expect(controller.state.comments, hasLength(commentCount));
      expect(controller.state.post!.commentCount, commentCount);
    });
  });
}
