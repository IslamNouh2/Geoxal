import 'package:flutter/material.dart';
import '../../../../core/database/database.dart';
import '../../../../core/services/invoice_number_service.dart';
import '../../../../data/datasources/finance_datasource.dart';
import '../../../../data/datasources/settings_datasource.dart';
import '../../../../data/models/compte.dart';
import '../../../../data/repositories/finance_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../accounting/widgets/account_tree_picker.dart';

class GeneralSettingsTab extends StatefulWidget {
  const GeneralSettingsTab({super.key});

  @override
  State<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends State<GeneralSettingsTab> {
  late final SettingsRepository _settingsRepo;
  late final FinanceRepository _financeRepo;

  bool _loading = true;
  bool _venteAllowSelectCompte = false;
  bool _achatAllowSelectCompte = false;

  String? _venteDefaultCompteId;
  String? _achatDefaultCompteId;

  // Invoice number format controllers
  final _venteNumFormatController = TextEditingController();
  final _achatNumFormatController = TextEditingController();
  bool _savingVenteFormat = false;
  bool _savingAchatFormat = false;

  List<Compte> _accounts = [];

  @override
  void initState() {
    super.initState();
    final db = Database.instance;
    _settingsRepo = SettingsRepository(SettingsDataSource(db));
    _financeRepo = FinanceRepository(FinanceDataSource(db));
    _load();
  }

  @override
  void dispose() {
    _venteNumFormatController.dispose();
    _achatNumFormatController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final accounts = await _financeRepo.getAccounts();
      final vAllow = await _settingsRepo.getBoolSetting('VENTE_ALLOW_SELECT_COMPTE');
      final aAllow = await _settingsRepo.getBoolSetting('ACHAT_ALLOW_SELECT_COMPTE');
      final vDef = await _settingsRepo.getSettingValue('VENTE_DEFAULT_COMPTE_ID');
      final aDef = await _settingsRepo.getSettingValue('ACHAT_DEFAULT_COMPTE_ID');
      final vFmt = await _settingsRepo.getSettingValue('VENTE_NUM_FORMAT') ?? 'FV{YY}/{NNNN}';
      final aFmt = await _settingsRepo.getSettingValue('ACHAT_NUM_FORMAT') ?? 'FA{YY}/{NNNN}';

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _venteAllowSelectCompte = vAllow;
        _achatAllowSelectCompte = aAllow;
        _venteDefaultCompteId = vDef ??
            (accounts.any((a) => a.id == 'e953f50c-b365-4dd7-a8ce-50972d9c2b39')
                ? 'e953f50c-b365-4dd7-a8ce-50972d9c2b39'
                : null);
        _achatDefaultCompteId = aDef ??
            (accounts.any((a) => a.id == '3b78186d-3835-46a7-99d7-f2c3a69523f9')
                ? '3b78186d-3835-46a7-99d7-f2c3a69523f9'
                : null);
        _venteNumFormatController.text = vFmt;
        _achatNumFormatController.text = aFmt;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveVenteNumFormat() async {
    final val = _venteNumFormatController.text.trim();
    if (val.isEmpty) return;
    setState(() => _savingVenteFormat = true);
    try {
      await _settingsRepo.setSetting(
        'VENTE_NUM_FORMAT',
        val,
        description: 'Format numérotation factures vente. Variables: {YY} {YYYY} {MM} {NNNN} {NNN}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Format N° Facture Vente enregistré'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        setState(() {}); // refresh preview
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingVenteFormat = false);
    }
  }

  Future<void> _saveAchatNumFormat() async {
    final val = _achatNumFormatController.text.trim();
    if (val.isEmpty) return;
    setState(() => _savingAchatFormat = true);
    try {
      await _settingsRepo.setSetting(
        'ACHAT_NUM_FORMAT',
        val,
        description: 'Format numérotation factures achat. Variables: {YY} {YYYY} {MM} {NNNN} {NNN}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Format N° Facture Achat enregistré'),
            backgroundColor: Color(0xFF2563EB),
          ),
        );
        setState(() {}); // refresh preview
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingAchatFormat = false);
    }
  }

  Future<void> _pickVenteCompte() async {
    final picked = await showAccountTreePickerDialog(
      context,
      accounts: _accounts,
      selectedAccount: _accounts.cast<Compte?>().firstWhere(
        (a) => a?.id == _venteDefaultCompteId,
        orElse: () => null,
      ),
    );
    if (picked != null) {
      await _settingsRepo.setSetting('VENTE_DEFAULT_COMPTE_ID', picked.id);
      setState(() => _venteDefaultCompteId = picked.id);
    }
  }

  Future<void> _pickAchatCompte() async {
    final picked = await showAccountTreePickerDialog(
      context,
      accounts: _accounts,
      selectedAccount: _accounts.cast<Compte?>().firstWhere(
        (a) => a?.id == _achatDefaultCompteId,
        orElse: () => null,
      ),
    );
    if (picked != null) {
      await _settingsRepo.setSetting('ACHAT_DEFAULT_COMPTE_ID', picked.id);
      setState(() => _achatDefaultCompteId = picked.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final venteCompte = _accounts.cast<Compte?>().firstWhere(
      (a) => a?.id == _venteDefaultCompteId,
      orElse: () => null,
    );
    final achatCompte = _accounts.cast<Compte?>().firstWhere(
      (a) => a?.id == _achatDefaultCompteId,
      orElse: () => null,
    );

    final ventePreview = InvoiceNumberService.preview(_venteNumFormatController.text.trim().isNotEmpty
        ? _venteNumFormatController.text.trim()
        : 'FV{YY}/{NNNN}');
    final achatPreview = InvoiceNumberService.preview(_achatNumFormatController.text.trim().isNotEmpty
        ? _achatNumFormatController.text.trim()
        : 'FA{YY}/{NNNN}');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Ventes ─────────────────────────────────────────────────
          _buildCard(
            title: 'Paramètres du Module Ventes',
            icon: Icons.point_of_sale_rounded,
            iconColor: const Color(0xFF10B981),
            children: [
              // Numérotation des factures vente
              const ListTile(
                leading: Icon(Icons.tag_rounded, color: Color(0xFF10B981)),
                title: Text('Numérotation des factures de vente',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text(
                  'Seul l\'administrateur peut modifier le N° dans le formulaire.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 4),
              // Format variables helper
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: const Text(
                  'Variables disponibles :  {YY} = année 2 chiffres  •  {YYYY} = année 4 chiffres  •  {MM} = mois  •  {NNN} = séq. 3 chiffres  •  {NNNN} = séq. 4 chiffres',
                  style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _venteNumFormatController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Format N° Facture Vente',
                        hintText: 'FV{YY}/{NNNN}',
                        prefixIcon: const Icon(Icons.format_list_numbered_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixText: '→ $ventePreview',
                        suffixStyle: const TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ElevatedButton.icon(
                      onPressed: _savingVenteFormat ? null : _saveVenteNumFormat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _savingVenteFormat
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),

              const Divider(height: 28),

              // Allow select compte
              SwitchListTile(
                title: const Text('Activer la sélection de compte à la création de facture',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text(
                  'Si désactivé, le compte par défaut sera automatiquement attribué.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: _venteAllowSelectCompte,
                activeThumbColor: const Color(0xFF10B981),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) async {
                  await _settingsRepo.setBoolSetting('VENTE_ALLOW_SELECT_COMPTE', val);
                  setState(() => _venteAllowSelectCompte = val);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compte de vente par défaut',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(venteCompte != null
                    ? '${venteCompte.code} - ${venteCompte.libelle}'
                    : 'Aucun compte sélectionné'),
                trailing: ElevatedButton.icon(
                  onPressed: _pickVenteCompte,
                  icon: const Icon(Icons.account_tree_outlined, size: 16),
                  label: const Text('Choisir'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Section Achats ─────────────────────────────────────────────────
          _buildCard(
            title: 'Paramètres du Module Achats & Charges',
            icon: Icons.shopping_cart_rounded,
            iconColor: const Color(0xFF2563EB),
            children: [
              // Numérotation des factures achat
              const ListTile(
                leading: Icon(Icons.tag_rounded, color: Color(0xFF2563EB)),
                title: Text('Numérotation des factures d\'achat',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text(
                  'Seul l\'administrateur peut modifier le N° dans le formulaire.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: const Text(
                  'Variables disponibles :  {YY} = année 2 chiffres  •  {YYYY} = année 4 chiffres  •  {MM} = mois  •  {NNN} = séq. 3 chiffres  •  {NNNN} = séq. 4 chiffres',
                  style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _achatNumFormatController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Format N° Facture Achat',
                        hintText: 'FA{YY}/{NNNN}',
                        prefixIcon: const Icon(Icons.format_list_numbered_rounded, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixText: '→ $achatPreview',
                        suffixStyle: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ElevatedButton.icon(
                      onPressed: _savingAchatFormat ? null : _saveAchatNumFormat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _savingAchatFormat
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),

              const Divider(height: 28),

              SwitchListTile(
                title: const Text('Activer la sélection de compte pour les achats standard',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text(
                  'Pour les factures de type "Charge", l\'arborescence des charges s\'affiche toujours automatiquement.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: _achatAllowSelectCompte,
                activeThumbColor: const Color(0xFF2563EB),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) async {
                  await _settingsRepo.setBoolSetting('ACHAT_ALLOW_SELECT_COMPTE', val);
                  setState(() => _achatAllowSelectCompte = val);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compte d\'achat standard par défaut',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(achatCompte != null
                    ? '${achatCompte.code} - ${achatCompte.libelle}'
                    : 'Aucun compte sélectionné'),
                trailing: ElevatedButton.icon(
                  onPressed: _pickAchatCompte,
                  icon: const Icon(Icons.account_tree_outlined, size: 16),
                  label: const Text('Choisir'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
