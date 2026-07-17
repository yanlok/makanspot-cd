class UserModel {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? country;
  final String? favoriteFood;
  final int communityScore;
  final String role;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.country,
    this.favoriteFood,
    this.communityScore = 0,
    this.role = 'user',
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      country: json['country'] as String?,
      favoriteFood: json['favorite_food'] as String?,
      communityScore: json['community_score'] as int? ?? 0,
      role: json['role'] as String? ?? 'user',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'country': country,
      'favorite_food': favoriteFood,
      'community_score': communityScore,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
