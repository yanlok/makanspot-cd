import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makanspot/features/home/controllers/home_controller.dart';
import 'package:makanspot/features/home/models/fixture_home_repository.dart';
import 'package:makanspot/features/home/views/home_screen.dart';
import 'package:makanspot/features/home/views/widgets/home_header.dart';
import 'package:makanspot/features/profile/controllers/profile_controller.dart';
import 'package:makanspot/features/profile/models/fixture_profile_repository.dart';

void main() {
  group('HomeHeader', () {
    testWidgets('renders network image when profileAsset is a URL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeHeader(
              greeting: 'Good morning',
              firstName: 'Yih Loong',
              location: 'Kuala Lumpur',
              profileAsset: 'https://example.com/profile.jpg',
              onProfile: () {},
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<NetworkImage>());
      expect((imageWidget.image as NetworkImage).url, 'https://example.com/profile.jpg');
    });

    testWidgets('renders asset image when profileAsset is a local asset', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeHeader(
              greeting: 'Good morning',
              firstName: 'Yih Loong',
              location: 'Kuala Lumpur',
              profileAsset: 'assets/images/default_icon.jpg',
              onProfile: () {},
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<AssetImage>());
      expect((imageWidget.image as AssetImage).assetName, 'assets/images/default_icon.jpg');
    });
  });

  group('HomeScreen', () {
    testWidgets('uses real profile image from profile provider when available', (tester) async {
      final profileRepo = FixtureProfileRepository();
      await profileRepo.saveProfile(
        username: 'Yih Loong',
        bio: 'Food lover',
        profileAsset: 'https://cdn.example.com/my-photo.jpg',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeRepositoryProvider.overrideWithValue(const FixtureHomeRepository()),
            profileRepositoryProvider.overrideWithValue(profileRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HomeScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final networkImageFinder = find.descendant(
        of: find.bySemanticsLabel('Open profile'),
        matching: find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage),
      );
      expect(networkImageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(networkImageFinder);
      expect((imageWidget.image as NetworkImage).url, 'https://cdn.example.com/my-photo.jpg');
    });
  });
}
