# Discovery Journey Week 12

## Integration

The journey controller is shared for the app session. Publishing a new review calls `recordReview` after the community repository succeeds, so the journey dashboard, visit history, achievements, and score history observe the same state.

A review always increments the review count and adds score history. A restaurant is added to visit history only once. A first review at a restaurant earns 15 points (10 review points plus 5 visit points); later reviews at that restaurant earn 10 points.

## Verification

Run the following from the repository root:

```text
dart format .
flutter analyze
flutter test
```

The focused regression suite is `test/features/journey/journey_controller_test.dart` and covers new reviews, repeat reviews, visit filtering, and load failures.
