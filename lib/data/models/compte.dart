enum CompteType {
  caisse('Caisse'),
  banque('Banque'),
  recette('Recette'),
  depense('Dépense'),
  recetteDepense('Recette / Dépense');

  final String label;
  const CompteType(this.label);

  static CompteType? fromString(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final normalized = val.trim().toLowerCase();
    switch (normalized) {
      case 'caisse':
        return CompteType.caisse;
      case 'banque':
        return CompteType.banque;
      case 'recette':
        return CompteType.recette;
      case 'depense':
      case 'dépense':
      case 'depance':
      case 'dépance':
        return CompteType.depense;
      case 'recettedepense':
      case 'recette_depense':
      case 'recette/depense':
      case 'recette/depance':
        return CompteType.recetteDepense;
      default:
        return null;
    }
  }

  String toDbValue() {
    switch (this) {
      case CompteType.caisse:
        return 'caisse';
      case CompteType.banque:
        return 'banque';
      case CompteType.recette:
        return 'recette';
      case CompteType.depense:
        return 'depense';
      case CompteType.recetteDepense:
        return 'recette_depense';
    }
  }
}

/// Chart of accounts entry — uses the Nested Set Model (NSM).
/// BG = Borne Gauche (left bound), BD = Borne Droite (right bound).
/// A compte is an ancestor of another if its BG < child.BG && BD > child.BD.
/// A leaf compte has BD - BG == 1 (no children).
class Compte {
  final String id;
  final String code;
  final String libelle;
  final String? compteFr;
  final int niveau;
  final int bg;
  final int bd;
  final bool active;
  final String? userId;
  final CompteType? typeCompte;
  final bool isDevise;
  final String? codeDevise;

  const Compte({
    required this.id,
    required this.code,
    required this.libelle,
    this.compteFr,
    required this.niveau,
    required this.bg,
    required this.bd,
    this.active = true,
    this.userId,
    this.typeCompte,
    this.isDevise = false,
    this.codeDevise,
  });

  /// True if this compte has no children (leaf node in the tree).
  bool get isLeaf => bd - bg == 1;

  /// True if this compte has children (group/parent node).
  bool get isParent => bd - bg > 1;

  /// True if [other] is a direct or indirect descendant of this compte.
  bool isAncestorOf(Compte other) => bg < other.bg && bd > other.bd;

  /// True if [other] is an immediate child of this compte.
  bool isDirectParentOf(Compte other) =>
      isAncestorOf(other) && other.niveau == niveau + 1;

  /// Determines the effective type of the compte.
  /// If [typeCompte] is explicitly set, it takes precedence.
  /// Otherwise, uses NSM tree boundaries relative to known parent nodes in [allAccounts].
  CompteType resolveEffectiveType(List<Compte> allAccounts) {
    if (typeCompte != null) return typeCompte!;

    // 1. Check if enclosed inside Charges
    final chargesNode = allAccounts.firstWhere(
      (a) => a.code.trim() == '6' || a.libelle.toLowerCase().trim() == 'charges',
      orElse: () => const Compte(id: '', code: '', libelle: '', niveau: 0, bg: -1, bd: -1),
    );
    if (chargesNode.bg != -1 && chargesNode.isAncestorOf(this)) {
      return CompteType.depense;
    }

    // 2. Check if enclosed inside Caisse
    final caisseNode = allAccounts.firstWhere(
      (a) => a.code.trim() == '53' || (a.libelle.toLowerCase().trim() == 'caisse' && a.code != '5'),
      orElse: () => const Compte(id: '', code: '', libelle: '', niveau: 0, bg: -1, bd: -1),
    );
    if (caisseNode.bg != -1 && caisseNode.isAncestorOf(this)) {
      return CompteType.caisse;
    }

    // 3. Check if enclosed inside Banque
    final banqueNode = allAccounts.firstWhere(
      (a) => a.typeCompte == CompteType.banque || a.libelle.toLowerCase().trim() == 'banque',
      orElse: () => const Compte(id: '', code: '', libelle: '', niveau: 0, bg: -1, bd: -1),
    );
    if (banqueNode.bg != -1 && banqueNode.isAncestorOf(this)) {
      return CompteType.banque;
    }

    // 4. Check if enclosed inside Caisse et banque (general)
    final caisseBanqueRoot = allAccounts.firstWhere(
      (a) => a.code.trim() == '5' || a.libelle.toLowerCase().contains('caisse et banque'),
      orElse: () => const Compte(id: '', code: '', libelle: '', niveau: 0, bg: -1, bd: -1),
    );
    if (caisseBanqueRoot.bg != -1 && caisseBanqueRoot.isAncestorOf(this)) {
      if (libelle.toLowerCase().contains('banque')) return CompteType.banque;
      return CompteType.caisse;
    }

    // 5. Check if enclosed inside Achat et Vente
    final achatVenteNode = allAccounts.firstWhere(
      (a) => a.code.trim() == '7' || a.libelle.toLowerCase().contains('achat et vent'),
      orElse: () => const Compte(id: '', code: '', libelle: '', niveau: 0, bg: -1, bd: -1),
    );
    if (achatVenteNode.bg != -1 && achatVenteNode.isAncestorOf(this)) {
      if (libelle.toLowerCase().contains('achat') || code.startsWith('70')) {
        return CompteType.depense;
      }
      if (libelle.toLowerCase().contains('vente') || code.startsWith('71')) {
        return CompteType.recette;
      }
    }

    // Default fallback based on code or name
    final nameLower = libelle.toLowerCase();
    if (nameLower.contains('caisse')) return CompteType.caisse;
    if (nameLower.contains('banque') || nameLower.contains('banck')) return CompteType.banque;
    if (nameLower.contains('vente') || nameLower.contains('recette')) return CompteType.recette;
    return CompteType.depense;
  }

  /// Display name: prefer compteFr if available.
  String get displayName =>
      compteFr?.isNotEmpty == true ? '$code - $compteFr' : '$code - $libelle';
}
