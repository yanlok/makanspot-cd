/// Demo accounts used for development and testing.
///
/// Single source of truth for the quick-login shortcuts on the Login screen
/// and the fixture repository seeds. The admin account is also mirrored in
/// the Supabase backend
/// `supabase/migrations/202608050000128_create_admin_account.sql`).
abstract final class DemoAccounts {
  const DemoAccounts._();

  static const userEmail = 'test@gmail.com';
  static const userPassword = '12345678';

  static const adminEmail = 'admin@makanspot.my';
  static const adminPassword = 'admin123';
}
