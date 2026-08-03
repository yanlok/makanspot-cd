# Flutter Migration Handoff

Last updated: 3 August 2026 (Asia/Kuala_Lumpur)

## Goal

Rebuild the Flutter application incrementally from
`makanspot-prototype/`, treating the React prototype as the source of truth for
visual design, copy, content hierarchy, and interactions.

The Flutter application uses feature-first Model-View-Controller (MVC):

```text
View -> Controller -> Model/Repository
```

Riverpod is used for dependency injection and state observation. It must not be
treated as an MVVM layer, and ViewModels must not be introduced.

## Completed in iteration 1

- Deleted the previous contents of `lib/` and `test/`.
- Recreated the Flutter application from a minimal bootstrap.
- Preserved `makanspot-prototype/`, `supabase/`, `scripts/`, `datasets/`,
  `android/`, `ios/`, and `docs/coding-standards.md`.
- Removed dependencies belonging to later slices, including maps, location,
  image picking, cached images, and Google Fonts runtime loading.
- Added the Lucide-compatible Flutter icon package.
- Bundled Poppins and Inter font files and their OFL license notices.
- Reused the prototype's default profile image as a local asset.
- Implemented the 448px maximum-width mobile shell and fixed bottom navigation.
- Implemented the fixture-backed Home screen with:
  - greeting, user, location, and profile image;
  - search field and filter chips;
  - Recommended for You;
  - Hidden Gems Sekitar Anda;
  - Sedap Dekat Sini;
  - Newest Listings;
  - restaurant cards, status badges, bookmarks, image loading/error states,
    and skeleton loading states.
- Added named **Not migrated yet** placeholders for all remaining customer,
  authentication, and administrator routes.
- Replaced the old migration design document with an iteration tracker at
  `docs/flutter-migration-design.md`.

## Current Home architecture

The Home slice contains these public boundaries:

- `RestaurantSummary`: typed restaurant card data.
- `HomeFeed`: typed user/header and section data.
- `HomeRepository.loadHome()`: data-source boundary.
- `FixtureHomeRepository`: deterministic prototype-like fixture data.
- `HomeState`: immutable loading, content, empty, and error state.
- `HomeController`: loading, greeting, search/filter destinations, and
  bookmark coordination.
- `homeRepositoryProvider`: override point for tests and the future production
  repository.

The Home View imports the controller and models but does not query a backend or
repository directly.

## Verification completed

The final verification commands passed:

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Results:

- Formatter: 25 files checked, no changes required.
- Analyzer: no issues found.
- Tests: 14 tests passed.
- Responsive widget tests passed at:
  - 320x568;
  - 375x812;
  - 430x932.

## Completed in iteration 2

- Recorded the user's Home visual approval.
- Migrated the customer authentication routes:
  - `/login`;
  - `/register`, including the email-verification state;
  - `/forgot-password`, including the privacy-preserving sent state; and
  - `/reset-password`, including invalid-link and new-password states.
- Added a shared fixture-backed `AuthRepository`, immutable `AuthState`, and
  `AuthController` following feature-first MVC.
- Added validation, stable user-facing failures, loading states, route
  navigation, and accessible controls.
- Added responsive and interaction coverage for the authentication slice.

The latest verification commands passed:

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Results:

- Formatter: 37 files checked, no changes required.
- Analyzer: no issues found.
- Tests: 35 tests passed.
- Authentication pages passed at 320x568, 375x812, and 430x932 without
  horizontal overflow.

The user approved the authentication visual iteration and asked to continue to
the next pages.

## Completed in iteration 3

- Migrated `/discover` with fixture-backed search, filter, cuisine, budget,
  sorting, bookmark, loading, empty, and error behavior.
- Migrated `/restaurant/:id` with typed restaurant details, image fallback,
  restaurant information, deterministic map preview, review cards, review
  likes, write-review routing, and not-found/error behavior.
- Replaced the old Discover and restaurant-detail placeholders with real typed
  routes, including Home search, filter, bottom-navigation, and restaurant-card
  destinations.
- Added responsive and interaction coverage for both screens.
- Updated stale Home route tests to assert the migrated Discover destination.

The latest verification commands passed:

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Results:

- Formatter: 53 files checked, no changes required.
- Analyzer: no issues found.
- Tests: all 50 tests passed.
- Discover and restaurant details passed at 320x568, 375x812, and 430x932
  without horizontal overflow.

## Discover visual comparison

Primary 375x812 screenshots are stored outside the repository in:

```text
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-discover-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-discover-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-restaurant-details-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-restaurant-details-375x812.png
```

## Authentication visual comparison

Primary 375x812 screenshots are stored outside the repository in:

```text
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-login-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-login-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-register-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-register-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-forgot-password-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-forgot-password-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-reset-password-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-reset-password-375x812.png
```

Automated coverage includes controller content/error/empty states, immutable
bookmarks, search and filter routing, loading skeletons, image fallback,
navigation placeholders, accessibility labels, and horizontal-overflow checks.

## Completed in combined iterations 4-6

- Migrated all eleven customer pages in the combined batch: Community, Create
  Review, Post Details, Edit Post, My Posts, Journey, Visit History,
  Exploration Map, Achievements, Profile, and Edit Profile.
- Added typed fixture-backed repositories, immutable state, and Riverpod MVC
  controllers for the Community, Journey, and Profile feature families.
- Replaced every corresponding customer placeholder route and preserved typed
  context through create/edit/detail and journey/profile child navigation.
- Added search, likes, report confirmation, comments/replies, active/archived
  posts, achievement progress, deterministic map/visit content, profile
  validation, save, and logout-confirmation behavior.
- Covered loading, content, empty, error, and applicable not-found states.
- Passed the full 11-page responsive matrix at 320x568, 375x812, and 430x932.
- Captured one React and one Flutter 375x812 screenshot for every page.

Final combined-batch verification:

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

- Formatter: 86 files checked, no changes required.
- Analyzer: no issues found.
- Tests: all 97 tests passed.

The Flutter fixture keeps the Yih Loong identity used throughout the earlier
migrated Flutter pages. The React browser may show Aisyah Rahman from its local
storage. Visit History intentionally uses complete typed restaurant data where
the current React seed leaves restaurant names and cuisines blank.

## Combined iterations 4-6 visual comparison

All 22 primary screenshots are stored outside the repository in:

```text
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-community-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-community-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-create-review-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-create-review-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-post-details-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-post-details-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-edit-post-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-edit-post-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-my-posts-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-my-posts-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-journey-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-journey-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-visit-history-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-visit-history-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-exploration-map-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-exploration-map-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-achievements-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-achievements-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-profile-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-profile-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\prototype-edit-profile-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\02\019fc1b1-1be7-7e00-b597-e9098d0f2c36\flutter-edit-profile-375x812.png
```

## Visual comparison

Primary 375x812 screenshots are stored outside the repository at:

```text
C:\Users\tayer\.codex\visualizations\2026\08\01\019fbe11-f99a-7a91-a5b7-6dd494cea338\prototype-home-375x812.png
C:\Users\tayer\.codex\visualizations\2026\08\01\019fbe11-f99a-7a91-a5b7-6dd494cea338\flutter-home-375x812.png
```

The implementation was adjusted after comparison to match the prototype's
newest-first restaurant ordering and compact section-header spacing.

The prototype screenshot may display a browser-stored profile named Aisyah.
Flutter intentionally uses the deterministic source fixture named Yih. This is
a data difference, not a layout difference.

## Current gate and remaining work

Combined iterations 4-6 were visually approved by the user after reviewing all
eleven React/Flutter comparisons. Their shared visual gate is complete.
Administration remains the next unmigrated slice; combined golden baselines and
production repository adapters remain separately pending.

The Home, authentication, Discover, Community, Journey, and Profile production
repositories have not been implemented. Supabase infrastructure is preserved
but is not imported or initialized by the current Flutter app. Production
adapters remain tracked separately from visual page migration.

## Important constraints for the next session

- Read `AGENTS.md` and `docs/coding-standards.md` before application work.
- Preserve all unrelated user changes in the dirty working tree.
- Keep `makanspot-prototype/` as the visual authority.
- Do not restore or reuse the deleted Flutter implementation.
- The combined batch approval gate has passed; Administration may be planned as
  the next migration slice.
- Keep fixture and production repositories behind the same MVC interface.
- Do not introduce ViewModels.
- Combined visual approval is recorded. Create golden baselines only when they
  are explicitly included in the next goal.

## Suggested continuation prompt

```text
Read AGENTS.md, docs/coding-standards.md,
docs/flutter-migration-design.md, and
docs/flutter-migration-handoff.md. Plan and execute the Administration migration
as the next slice. Preserve the approved customer visuals and keep production
repository adapters and golden baselines tracked separately.
```
