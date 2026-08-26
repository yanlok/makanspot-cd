class Badge {
  const Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.requirement,
    required this.requirementType,
    required this.requirementValue,
    this.imageUrl,
    this.iconName,
    this.points = 0,
  });

  final String id;
  final String name;
  final String description;
  final String requirement;
  final String requirementType;
  final int requirementValue;
  final String? imageUrl;
  final String? iconName;
  final int points;

  bool isUnlocked({required int progress}) {
    return progress >= requirementValue;
  }
}
