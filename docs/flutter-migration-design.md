# Flutter Migration Iteration Tracker

`makanspot-prototype/` is the visual and interaction source of truth. Flutter
uses feature-first Model-View-Controller (MVC); Riverpod provides dependency
injection and state observation and is not an MVVM layer.

## Working method

Each slice follows the same gate:

1. Capture the relevant React states at 320, 375, and 430 logical pixels.
2. Implement typed fixture-backed Flutter models, controller, and views.
3. Verify layout, interaction, accessibility, analysis, and tests.
4. Obtain visual approval.
5. Add the production repository adapter without changing the approved view.

An unchecked visual-approval item blocks golden-baseline creation and the next
slice. Placeholder routes are intentional and must not import superseded UI.

## Iterations

| Order | Slice | Fixture UI | Visual approval | Production data |
| ---: | --- | :---: | :---: | :---: |
| 1 | Foundation and Home | Complete | Approved | Pending |
| 2 | Authentication | Complete | Approved | Pending |
| 3 | Discover and restaurant details | Complete | Pending | Pending |
| 4-6 | Combined customer batch: Community, Journey and achievements, Profile | Complete | Approved | Pending |
| 7 | Administration | Pending | Pending | Pending |

## Iteration 1 acceptance record

- [x] Previous `lib/` and `test/` implementations removed.
- [x] Prototype, Supabase, scripts, datasets, and native projects preserved.
- [x] Exact semantic colour tokens and 448px mobile shell implemented.
- [x] Poppins and Inter configured as bundled assets.
- [x] Lucide-compatible icons used for prototype icon parity.
- [x] Fixture-backed Home MVC boundary implemented.
- [x] Unmigrated routes display explicit placeholders.
- [x] Automated formatting, analysis, and tests pass.
- [x] Reference and Flutter screenshots reviewed at 320x568, 375x812, and
      430x932.
- [ ] Flutter golden baselines approved and stored.
- [ ] Home production repository adapter implemented.

## Route status

All customer routes are implemented, including the Community, Journey,
Achievements, and Profile route families. Administrator routes continue to
render a named **Not migrated yet** state until iteration 7 begins.

## Iteration 2 acceptance record

- [x] Login, registration, forgot-password, and reset-password routes migrated.
- [x] Shared fixture-backed authentication repository and MVC controller added.
- [x] Registration OTP, validation, loading, error, and recovery success states
      implemented.
- [x] Responsive checks pass at 320x568, 375x812, and 430x932.
- [x] Primary 375x812 comparison screenshots captured for every page.
- [x] Formatting, analysis, and the full test suite pass.
- [x] Authentication visual comparison approved.
- [ ] Authentication production repository adapter implemented.

## Iteration 3 acceptance record

- [x] Discover and restaurant-details routes migrated.
- [x] Typed fixture-backed restaurant repository and MVC controllers added.
- [x] Search, filter, sort, bookmark, review-like, map-destination, and route
      interactions implemented.
- [x] Loading, content, empty, error, and not-found states implemented.
- [x] Responsive checks pass at 320x568, 375x812, and 430x932.
- [x] Primary 375x812 comparison screenshots captured for both pages.
- [x] Formatting, analysis, and all 50 tests pass.
- [ ] Discover and restaurant-details visual comparison approved.
- [ ] Discover production repository adapter implemented.

## Combined iterations 4-6 execution scope

Iterations 4, 5, and 6 must run as one continuous implementation goal. Do not
pause for an approval gate between Community, Journey/Achievements, and Profile.
The combined batch has one visual-review gate after all eleven prototype pages
have been migrated and checked.

Pages in this batch:

1. Community
2. Create Review
3. Post Details
4. Edit Post
5. My Posts
6. Journey
7. Visit History
8. Exploration Map
9. Achievements
10. Profile
11. Edit Profile

Combined acceptance criteria:

- [x] Capture and inspect the React reference for every page before migrating
      its Flutter equivalent.
- [x] Implement every page with feature-first MVC and typed fixture-backed
      repository boundaries.
- [x] Replace all eleven corresponding **Not migrated yet** routes.
- [x] Preserve navigation and context between Community, Journey, Profile, and
      their child routes.
- [x] Cover loading, content, empty, error, and applicable not-found states.
- [x] Verify every page at 320x568, 375x812, and 430x932.
- [x] Capture a primary 375x812 React and Flutter screenshot for every page at
      the end of the combined batch.
- [x] Run formatting, `flutter analyze`, and the complete `flutter test` suite.
- [x] Present all eleven screenshot comparisons together for one visual-review
      gate.
- [x] Obtain combined visual approval before creating golden baselines or
      beginning Administration.

## Combined iterations 4-6 implementation record

- [x] Community feed, search, post likes, reports, and post-detail navigation.
- [x] Create Review and Edit Post flows with validation and fixture photos.
- [x] Post Details comments and replies, plus active/archived My Posts tabs.
- [x] Journey overview, Visit History, Exploration Map, and Achievements.
- [x] Profile overview, menu destinations, logout confirmation, and Edit
      Profile validation/save behavior.
- [x] Deterministic typed repositories and Riverpod MVC controllers for all
      three feature families.
- [x] Thirty-three responsive page cases pass across the required viewport
      matrix, with controller and interaction coverage included in the full
      suite.

The Flutter fixture intentionally retains the established Yih Loong identity
used by the earlier migrated pages. The React browser snapshot may show Aisyah
Rahman from local storage. Flutter Visit History also supplies complete typed
restaurant fields where the React seed currently renders blank names and
cuisines. These are fixture-data differences rather than layout deviations.
