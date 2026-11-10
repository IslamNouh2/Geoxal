class AppSetting {
  final String key;
  final String? value;
  final String? description;

  const AppSetting({
    required this.key,
    this.value,
    this.description,
  });

  bool get asBool => value?.toUpperCase() == 'O' || value?.toUpperCase() == 'TRUE' || value == '1';

  factory AppSetting.fromMap(Map<String, dynamic> map) {
    return AppSetting(
      key: (map['SETTING_KEY'] ?? '').toString().trim(),
      value: map['SETTING_VALUE']?.toString().trim(),
      description: map['DESCRIPTION']?.toString().trim(),
    );
  }
}

