import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/screen_header.dart';

/// Records money collected from residents beyond what's needed for the
/// current month's costs — entered per flat, since that's how the admin
/// actually collects it, and multiplied by the flat count for the total
/// added to the reserve fund's running balance.
class AddReserveFundScreen extends StatefulWidget {
  const AddReserveFundScreen({super.key});

  @override
  State<AddReserveFundScreen> createState() => _AddReserveFundScreenState();
}

class _AddReserveFundScreenState extends State<AddReserveFundScreen> {
  final _perFlatCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _perFlatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(SocietyProvider society) async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final totalPaise =
        parseRupeesToPaise(_perFlatCtrl.text) * society.flats.length;
    setState(() => _isLoading = true);
    await withLoadingOverlay(
      context,
      () => society.topUpReserveFund(totalPaise),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final perFlatPaise = parseRupeesToPaise(_perFlatCtrl.text);
    final totalPaise = perFlatPaise * society.flats.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('addToReserveFund')),
              Expanded(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppLocalizations.t('currentReserveBalance'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textMedium,
                              ),
                            ),
                            Text(
                              formatPaise(society.building.reserveFundPaise),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        AppLocalizations.t('reserveFundAmountPerFlatLabel'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _perFlatCtrl,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        validator: (v) => parseRupeesToPaise(v ?? '') > 0
                            ? null
                            : AppLocalizations.t('enterValidAmount'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '× ${society.flats.length} ${AppLocalizations.t('flats')} = ${formatPaise(totalPaise)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : () => _save(society),
                        child: Text(AppLocalizations.t('saveReserveFundBtn')),
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
