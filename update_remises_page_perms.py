with open('lib/features/accounting/pages/remises_cheques_page.dart', 'r', encoding='utf-8') as f:
    text = f.read()

delete_draft_func = """  Future<void> _deleteDraftRemise(RemiseCheque remise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le bordereau brouillon ?'),
        content: Text(
          'Voulez-vous supprimer définitivement le bordereau brouillon N° ' +
              remise.bordereauNumber +
              ' ?\\nLes chèques associés resteront intacts dans votre portefeuille.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteDraftRemise(remise.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bordereau brouillon supprimé avec succès.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
"""

text_norm = text.replace('\r\n', '\n')
target_cancel = '  Future<void> _cancelRemise(RemiseCheque remise) async {'
assert target_cancel in text_norm
text_norm = text_norm.replace(target_cancel, delete_draft_func + '\n' + target_cancel, 1)

# Header "Nouveau Bordereau" button check
old_hdr_btn = """                ElevatedButton.icon(
                  onPressed: _openCreateRemiseDialog,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Nouveau Bordereau', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),"""

new_hdr_btn = """                if (Session.user?.hasCreateRemisesPermission ?? true)
                  ElevatedButton.icon(
                    onPressed: _openCreateRemiseDialog,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Nouveau Bordereau', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),"""

assert old_hdr_btn in text_norm
text_norm = text_norm.replace(old_hdr_btn, new_hdr_btn, 1)

# Action buttons on remise items
old_item_actions = """                if (isDraft)
                  ElevatedButton(
                    onPressed: () => _validateRemise(r),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    child: const Text('Valider'),
                  ),
                if (isValidated)
                  OutlinedButton(
                    onPressed: () => _cancelRemise(r),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red),
                    child: const Text('Annuler'),
                  ),"""

new_item_actions = """                if (isDraft && (Session.user?.hasUpdateRemisesPermission ?? true))
                  ElevatedButton(
                    onPressed: () => _validateRemise(r),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                    child: const Text('Valider'),
                  ),
                if (isDraft && (Session.user?.hasDeleteRemisesPermission ?? true)) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                    tooltip: 'Supprimer ce brouillon',
                    onPressed: () => _deleteDraftRemise(r),
                  ),
                ],
                if (isValidated && (Session.user?.hasDeleteRemisesPermission ?? true))
                  OutlinedButton(
                    onPressed: () => _cancelRemise(r),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red),
                    child: const Text('Annuler'),
                  ),"""

assert old_item_actions in text_norm
text_norm = text_norm.replace(old_item_actions, new_item_actions, 1)

with open('lib/features/accounting/pages/remises_cheques_page.dart', 'w', encoding='utf-8', newline='') as f:
    f.write(text_norm.replace('\n', '\r\n'))

print("Updated remises_cheques_page.dart with full CRUD permissions")

