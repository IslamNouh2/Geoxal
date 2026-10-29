import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../data/models/compte.dart';

/// Left panel showing the accounts tree. Selecting a node filters the
/// movements; "All accounts" resets the filter.
class AccountTreePanel extends StatefulWidget {
  const AccountTreePanel({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onSelect,
    required this.onAddAccount,
  });

  final List<Compte> accounts;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onAddAccount;

  @override
  State<AccountTreePanel> createState() => _AccountTreePanelState();
}

class _AccountTreePanelState extends State<AccountTreePanel> {
  late Set<String> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = _parentIdsOf(widget.accounts);
  }

  @override
  void didUpdateWidget(covariant AccountTreePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.accounts, widget.accounts)) {
      _expanded.addAll(_parentIdsOf(widget.accounts));
    }
  }

  Set<String> _parentIdsOf(List<Compte> accounts) {
    return accounts
        .where((account) => account.isParent)
        .map((account) => account.id)
        .toSet();
  }

  Map<String, List<Compte>> _childrenByParent() {
    final map = <String, List<Compte>>{};

    for (final parent in widget.accounts) {
      if (!parent.isParent) continue;

      final children =
          widget.accounts
              .where((account) => parent.isDirectParentOf(account))
              .toList()
            ..sort((a, b) => a.bg.compareTo(b.bg));

      if (children.isNotEmpty) {
        map[parent.id] = children;
      }
    }

    return map;
  }

  List<Compte> _roots() {
    if (widget.accounts.isEmpty) return [];

    final minNiveau = widget.accounts
        .map((account) => account.niveau)
        .reduce((a, b) => a < b ? a : b);

    return widget.accounts
        .where((account) => account.niveau == minNiveau)
        .toList()
      ..sort((a, b) => a.bg.compareTo(b.bg));
  }

  @override
  Widget build(BuildContext context) {
    final childrenByParent = _childrenByParent();

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                const Text(
                  'Accounts',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'New account',
                  icon: const Icon(Icons.add, size: 20),
                  color: AppColors.steelBlue,
                  onPressed: widget.onAddAccount,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  _row(
                    selected: widget.selectedId == null,
                    onTap: () => widget.onSelect(null),
                    child: const Text(
                      'All accounts',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepSpaceBlue,
                      ),
                    ),
                  ),
                  for (final root in _roots()) _node(root, childrenByParent, 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: selected
            ? AppColors.steelBlue.withOpacity(0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _node(
    Compte account,
    Map<String, List<Compte>> childrenByParent,
    int depth,
  ) {
    final children = childrenByParent[account.id] ?? const <Compte>[];
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expanded.contains(account.id);
    final selected = widget.selectedId == account.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.0 + depth * 14.0),
          child: _row(
            selected: selected,
            onTap: () => widget.onSelect(selected ? null : account.id),
            child: Row(
              children: [
                if (hasChildren)
                  InkWell(
                    onTap: () => _toggle(account.id),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 20,
                      color: AppColors.coolSteel,
                    ),
                  )
                else
                  const SizedBox(width: 20, height: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${account.code} ',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.steelBlue,
                          ),
                        ),
                        TextSpan(
                          text: account.libelle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected
                                ? AppColors.deepSpaceBlue
                                : AppColors.deepSpaceBlue.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasChildren && isExpanded)
          for (final child in children)
            _node(child, childrenByParent, depth + 1),
      ],
    );
  }

  void _toggle(String id) {
    setState(() {
      if (!_expanded.remove(id)) {
        _expanded.add(id);
      }
    });
  }
}
