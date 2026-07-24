class DealerModel {
  final String username;
  final String pin;
  final String displayName;

  const DealerModel({
    required this.username,
    required this.pin,
    required this.displayName,
  });

  factory DealerModel.fromMap(Map<String, dynamic> map) {
    final username = map['username'] ?? '';
    return DealerModel(
      username: username,
      pin: (map['pin'] ?? '').toString(),
      displayName: map['display_name']?.toString().isNotEmpty == true
          ? map['display_name']
          : username,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DealerModel && other.username == username;

  @override
  int get hashCode => username.hashCode;
}
