/// Returns a user-facing error message for [email], or null when valid.
String? validateEmail(String email) {
  if (email.isEmpty) {
    return 'Email is required.';
  }
  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailPattern.hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

/// Returns a user-facing error message for [password], or null when valid.
String? validatePassword(String password) {
  if (password.isEmpty) {
    return 'Password is required.';
  }
  if (password.length < 6) {
    return 'Password must be at least 6 characters.';
  }
  return null;
}
