/// Derives a user's profile title from their community score.
///
/// The thresholds are shared by every feature that shows a "profile title"
/// (profile, journey, and community screens) so the title is consistent
/// wherever the user is displayed.
String profileTitleForScore(int score) {
  if (score >= 500) return 'Makan Legend';
  if (score >= 100) return 'Hidden Gem Hunter';
  return 'Food Explorer';
}