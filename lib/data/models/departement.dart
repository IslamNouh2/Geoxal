class Departement {
  final String id;
  final String code;
  final String nom;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;

  const Departement({
    required this.id,
    required this.code,
    required this.nom,
    this.description,
    this.isActive = true,
    this.createdAt,
  });

  factory Departement.fromMap(Map<String, dynamic> map) {
    final activeVal = (map['IS_ACTIVE'] ?? 'O').toString().trim().toUpperCase();
    return Departement(
      id: map['ID'].toString().trim(),
      code: (map['CODE'] ?? '').toString().trim(),
      nom: (map['NOM'] ?? '').toString().trim(),
      description: map['DESCRIPTION']?.toString().trim(),
      isActive: activeVal == 'O' || activeVal == '1',
      createdAt: map['CREATED_AT'] == null
          ? null
          : DateTime.tryParse(map['CREATED_AT'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'CODE': code,
      'NOM': nom,
      'DESCRIPTION': description,
      'IS_ACTIVE': isActive ? 'O' : 'N',
    };
  }
}

