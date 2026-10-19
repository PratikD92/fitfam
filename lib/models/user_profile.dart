class UserProfile {
  final String name;
  final String gender; // 'Male' | 'Female'
  final int age;
  final double weightKg;
  final int heightFt;
  final int heightIn;
  final double heightCm; // derived from ft/in on save
  final double targetWeightKg;
  final String activityLevelId;

  const UserProfile({
    required this.name,
    required this.gender,
    required this.age,
    required this.weightKg,
    required this.heightFt,
    required this.heightIn,
    required this.heightCm,
    required this.targetWeightKg,
    required this.activityLevelId,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'gender': gender,
        'age': age,
        'weightKg': weightKg,
        'heightFt': heightFt,
        'heightIn': heightIn,
        'heightCm': heightCm,
        'targetWeightKg': targetWeightKg,
        'activityLevelId': activityLevelId,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] as String,
        gender: j['gender'] as String,
        age: j['age'] as int,
        weightKg: (j['weightKg'] as num).toDouble(),
        heightFt: j['heightFt'] as int,
        heightIn: j['heightIn'] as int,
        heightCm: (j['heightCm'] as num).toDouble(),
        targetWeightKg: (j['targetWeightKg'] as num).toDouble(),
        activityLevelId: j['activityLevelId'] as String,
      );
}
