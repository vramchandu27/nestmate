import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/advance.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/screen_header.dart';

/// Record an advance paid out that isn't a shared common expense, and who
/// it should be recovered from.
class AddAdvanceScreen extends StatefulWidget {
  const AddAdvanceScreen({super.key});

  @override
  State<AddAdvanceScreen> createState() => _AddAdvanceScreenState();
}

class _RecoveryRow {
  _RecoveryRow()
    : flatCtrl = TextEditingController(),
      amountCtrl = TextEditingController();
  final TextEditingController flatCtrl;
  final TextEditingController amountCtrl;
}

class _AddAdvanceScreenState extends State<AddAdvanceScreen> {
  final _reasonCtrl = TextEditingController();
  final _givenToCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<_RecoveryRow> _rows = [_RecoveryRow()];
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _givenToCtrl.dispose();
    _amountCtrl.dispose();
    for (final r in _rows) {
      r.flatCtrl.dispose();
      r.amountCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save(SocietyProvider society) async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final recoveries = <AdvanceRecovery>[];
    for (final r in _rows) {
      if (r.flatCtrl.text.trim().isEmpty) continue;
      recoveries.add(
        AdvanceRecovery(
          flatNumber: r.flatCtrl.text.trim(),
          amountPaise: parseRupeesToPaise(r.amountCtrl.text),
        ),
      );
    }

    setState(() => _isLoading = true);
    await withLoadingOverlay(
      context,
      () => society.addAdvance(
        Advance(
          id: 'adv${DateTime.now().microsecondsSinceEpoch}',
          reason: _reasonCtrl.text.trim(),
          givenToName: _givenToCtrl.text.trim(),
          amountPaise: parseRupeesToPaise(_amountCtrl.text),
          recoveries: recoveries,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final society = context.read<SocietyProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('addAdvance')),
              Expanded(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        AppLocalizations.t('advanceReasonLabel'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _reasonCtrl,
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.t('fieldRequired')
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.t('advanceGivenTo'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _givenToCtrl,
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.t('fieldRequired')
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.t('amountLabel'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountCtrl,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.number,
                        validator: (v) => parseRupeesToPaise(v ?? '') > 0
                            ? null
                            : AppLocalizations.t('enterValidAmount'),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        AppLocalizations.t('recoverFromRows'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final r in _rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: r.flatCtrl,
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.t('flat'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: r.amountCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.t('rupees'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      OutlinedButton(
                        onPressed: () =>
                            setState(() => _rows.add(_RecoveryRow())),
                        child: Text(
                          '+ ${AppLocalizations.t('addAnotherFlat')}',
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : () => _save(society),
                        child: Text(AppLocalizations.t('saveAdvanceBtn')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
