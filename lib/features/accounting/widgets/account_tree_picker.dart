import 'package:flutter/material.dart';

import '../../../../data/models/compte.dart';

Future<Compte?> showAccountTreePickerDialog(
  BuildContext context, {
  required List<Compte> accounts,
  String? excludeAccountId,
  Compte? selectedAccount,
  bool Function(Compte)? filterPredicate,
}) {
  return showDialog<Compte?>(
    context: context,
    builder: (context) => AccountTreePickerDialog(
      accounts: accounts,
      excludeAccountId: excludeAccountId,
      initialSelected: selectedAccount,
      filterPredicate: filterPredicate,
    ),
  );
}

class AccountTreePickerDialog extends StatefulWidget {
  const AccountTreePickerDialog({
    super.key,
    required this.accounts,
    this.excludeAccountId,
    this.initialSelected,
    this.filterPredicate,
  });

  final List<Compte> accounts;
  final String? excludeAccountId;
  final Compte? initialSelected;
  final bool Function(Compte)? filterPredicate;

  @override
  State<AccountTreePickerDialog> createState() =>
      _AccountTreePickerDialogState();
}

List<Compte> getDirectChildren(Compte parent, List<Compte> accounts) {
  final children = accounts.where((account) {
    return parent.isAncestorOf(account) && account.niveau == parent.niveau + 1;
  }).toList();

  children.sort((a, b) => a.bg.compareTo(b.bg));
  return children;
}

class _AccountTreePickerDialogState extends State<AccountTreePickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedIds = {};
  Compte? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
    // Auto-expand all parent accounts using NSM.
    for (final account in widget.accounts) {
      if (account.isParent) {
        _expandedIds.add(account.id);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Set<String> get _parentIds => {
    for (final account in widget.accounts)
      if (account.isParent) account.id,
  };

  List<Compte> _getChildren(String? parentAccountId) {
    final List<Compte> children;

    if (parentAccountId == null) {
      if (widget.accounts.isEmpty) return [];

      final minNiveau = widget.accounts
          .map((account) => account.niveau)
          .reduce((a, b) => a < b ? a : b);

      children = widget.accounts
          .where(
            (account) =>
                account.niveau == minNiveau &&
                account.id != widget.excludeAccountId,
          )
          .toList();
    } else {
      Compte? parent;

      for (final account in widget.accounts) {
        if (account.id == parentAccountId) {
          parent = account;
          break;
        }
      }

      if (parent == null) return [];

      children = widget.accounts
          .where(
            (account) =>
                parent!.isDirectParentOf(account) &&
                account.id != widget.excludeAccountId,
          )
          .toList();
    }

    children.sort((a, b) => a.bg.compareTo(b.bg));
    return children;
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final search = _searchController.text.trim().toLowerCase();
    // final parentIds = _parentIds;

    // Filtered mode vs Tree mode
    final isSearching = search.isNotEmpty;
    final searchMatches = isSearching
        ? widget.accounts.where((a) {
            if (a.id == widget.excludeAccountId) return false;
            final isLeaf = a.isLeaf;
            if (!isLeaf) return false; // Only leaf accounts are selectable destinations
            if (widget.filterPredicate != null && !widget.filterPredicate!(a)) {
              return false;
            }
            return a.code.toLowerCase().contains(search) ||
                a.libelle.toLowerCase().contains(search) ||
                (a.compteFr?.toLowerCase().contains(search) ?? false);
          }).toList()
        : <Compte>[];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_tree_rounded,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sélectionner le Compte Destination',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Parcourez l\'arborescence pour choisir le compte crédité (feuille)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Search bar
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Filtrer par code ou nom...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Tree view
              Expanded(
                child: isSearching
                    ? (searchMatches.isEmpty
                          ? const Center(child: Text('Aucun compte trouvé.'))
                          : ListView.separated(
                              itemCount: searchMatches.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final acc = searchMatches[index];
                                final isSelected = _selected?.id == acc.id;
                                return ListTile(
                                  leading: const Icon(
                                    Icons.description_outlined,
                                    size: 20,
                                    color: Color(0xFF10B981),
                                  ),
                                  title: Text(
                                    acc.displayName,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF10B981),
                                        )
                                      : null,
                                  selected: isSelected,
                                  selectedTileColor: const Color(0xFFECFDF5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onTap: () => setState(() => _selected = acc),
                                );
                              },
                            ))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildTreeNodes(null, 0),
                        ),
                      ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Footer
              Row(
                children: [
                  Expanded(
                    child: _selected == null
                        ? const Text(
                            'Aucun compte sélectionné',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          )
                        : Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF10B981),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Choisi: ${_selected!.displayName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _selected == null
                        ? null
                        : () => Navigator.of(context).pop(_selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Sélectionner'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTreeNodes(String? parentId, int depth) {
    final children = _getChildren(parentId);
    final parentIds = _parentIds;
    final widgets = <Widget>[];

    for (final child in children) {
      final isParent = parentIds.contains(child.id);
      final isExpanded = _expandedIds.contains(child.id);
      final isSelected = _selected?.id == child.id;
      final isSelectable = !isParent && (widget.filterPredicate == null || widget.filterPredicate!(child));

      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: depth * 18.0),
          child: InkWell(
            onTap: () {
              if (isParent) {
                _toggleExpand(child.id);
              } else if (isSelectable) {
                setState(() => _selected = child);
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFECFDF5)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? Border.all(color: const Color(0xFF10B981))
                    : null,
              ),
              child: Row(
                children: [
                  if (isParent)
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 18,
                      color: const Color(0xFF6B7280),
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 4),
                  Icon(
                    isParent
                        ? (isExpanded
                              ? Icons.folder_open_rounded
                              : Icons.folder_rounded)
                        : Icons.description_outlined,
                    size: 18,
                    color: isParent
                        ? const Color(0xFF3B82F6)
                        : (isSelected
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      child.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isParent
                            ? FontWeight.w600
                            : (isSelected ? FontWeight.w700 : FontWeight.w400),
                        color: isParent
                            ? const Color(0xFF1F2937)
                            : (isSelected
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF374151)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildPickerTypeBadge(child.resolveEffectiveType(widget.accounts)),
                  if (!isParent && isSelected) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

      if (isParent && isExpanded) {
        widgets.addAll(_buildTreeNodes(child.id, depth + 1));
      }
    }

    return widgets;
  }

  Widget _buildPickerTypeBadge(CompteType type) {
    Color bg;
    Color fg;
    switch (type) {
      case CompteType.caisse:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case CompteType.banque:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case CompteType.recette:
        bg = const Color(0xFFEDE9FE);
        fg = const Color(0xFF6D28D9);
        break;
      case CompteType.depense:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
      case CompteType.recetteDepense:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
