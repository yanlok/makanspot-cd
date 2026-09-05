import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makanspot/features/community/controllers/community_controller.dart';
import 'package:makanspot/features/community/models/fixture_community_repository.dart';
import 'package:makanspot/features/community/views/post_details_screen.dart';
import 'package:makanspot/features/profile/controllers/profile_controller.dart';
import 'package:makanspot/features/profile/models/fixture_profile_repository.dart';
import 'package:makanspot/shared/widgets/makan_network_image.dart';

Widget createPostDetailsTestWidget(String postId) {
  return ProviderScope(
    overrides: [
      communityRepositoryProvider.overrideWithValue(FixtureCommunityRepository()),
      profileRepositoryProvider.overrideWithValue(FixtureProfileRepository()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: PostDetailsScreen(postId: postId),
      ),
    ),
  );
}

void main() {
  group('PostDetailsScreen', () {
    testWidgets('hides comment composer when viewing own post', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createPostDetailsTestWidget('post-1'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('No comments yet.'), findsNothing); // post-1 has 2 comments
      expect(find.text('Write a comment...'), findsNothing);
    });

    testWidgets('shows comment composer when viewing another user post', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createPostDetailsTestWidget('post-2'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Write a comment...'), findsOneWidget);
    });

    testWidgets('renders network avatar in comment composer when user has a profile picture', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final customProfileRepo = FixtureProfileRepository();
      await customProfileRepo.saveProfile(
        username: 'Yih Loong',
        bio: 'Bio',
        profileAsset: 'https://example.com/custom-avatar.jpg',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            communityRepositoryProvider.overrideWithValue(FixtureCommunityRepository()),
            profileRepositoryProvider.overrideWithValue(customProfileRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PostDetailsScreen(postId: 'post-2'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(MakanNetworkImage), findsWidgets);
    });
  });
}
