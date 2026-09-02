import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/screen_header.dart';

/// Live water-billing calculator: tanker count/cost + every flat's meter
/// reading feed a blended rate per 1,000 L that recomputes on every
/// keystroke, matching the build spec's §2a formula exactly.
class WaterCalculatorScreen extends StatefulWidget {
  const WaterCalculatorScreen({super.key});

  @override
  State<WaterCalculatorScreen> createState() => _WaterCalculatorScreenState();
}

class _WaterCalculatorScreenState extends State<WaterCalculatorScreen> {
  late final TextEditingController _tankerCountCtrl;
  late final TextEditingController _priceCtrl;
  final Map<String, TextEditingController> _initialCtrls = {};
  final Map<String, TextEditingController> _finalCtrls = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final society = context.read<SocietyProvider>();
    final water = society.currentMonth.water;
    // An unset/zero value starts each field genuinely empty (with "0" as
    // just the hint text) rather than containing a literal "0" character
    // — otherwise typing a real number means deleting that "0" first.
    _tankerCountCtrl = TextEditingController(
      text: water.tankerCount == 0 ? '' : '${water.tankerCount}',
    )..addListener(() {
        society.updateTankerConfig(
          tankerCount: int.tryParse(_tankerCountCtrl.text) ?? 0,
        );
      });
    final pricePerTanker = water.pricePerTankerPaise ~/ 100;
    _priceCtrl = TextEditingController(
      text: pricePerTanker == 0 ? '' : '$pricePerTanker',
    )..addListener(() {
        society.updateTankerConfig(
          pricePerTankerPaise: parseRupeesToPaise(_priceCtrl.text),
        );
      });
    for (final flat in society.flats) {
      final reading = society.currentMonth.readingFor(flat.flatNumber);
      final initialValue = reading?.initialLitres ?? 0;
      final initialCtrl = TextEditingController(
        text: initialValue == 0 ? '' : '$initialValue',
      );
      initialCtrl.addListener(() {
        society.updateReading(
          flat.flatNumber,
          initialLitres: int.tryParse(initialCtrl.text) ?? 0,
        );
      });
      final finalValue = reading?.finalLitres ?? 0;
      final finalCtrl = TextEditingController(
        text: finalValue == 0 ? '' : '$finalValue',
      );
      finalCtrl.addListener(() {
        society.updateReading(
          flat.flatNumber,
          finalLitres: int.tryParse(finalCtrl.text) ?? 0,
        );
      });
      _initialCtrls[flat.flatNumber] = initialCtrl;
      _finalCtrls[flat.flatNumber] = finalCtrl;
    }
  }

  @override
  void dispose() {
    _tankerCountCtrl.dispose();
    _priceCtrl.dispose();
    for (final c in _initialCtrls.values) {
      c.dispose();
    }
    for (final c in _finalCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addToBills() async {
    setState(() => _isLoading = true);
    await withLoadingOverlay(
      context,
      () => context.read<SocietyProvider>().generateBills(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final calc = society.waterCalc;
    final ratePer1000 =
        '₹${(calc.blendedRatePaisePer1000L / 100).toStringAsFixed(1)}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('waterCalculation')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      AppLocalizations.t('waterCalcSub'),
                      style: const TextStyle(
                        color: AppTheme.textMedium,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.t('blendedRate'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12.5,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                ratePer1000,
                                style: AppTheme.displayStyle(
                                  context,
                                  size: 30,
                                  weight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.t('perThousandLitres'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _HeroStat(
                                  label: AppLocalizations.t('totalUsage'),
                                  value: '${calc.totalUsageLitres} L',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _HeroStat(
                                  label: AppLocalizations.t('totalWaterCost'),
                                  value: formatPaise(calc.totalTankerCostPaise),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _NumField(
                            label: AppLocalizations.t('numberOfTankers'),
                            controller: _tankerCountCtrl,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _NumField(
                            label: AppLocalizations.t('costPerTanker'),
                            controller: _priceCtrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      AppLocalizations.t('meterReadingsHeader'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          const SizedBox(width: 44),
                          Expanded(
                            child: Text(
                              AppLocalizations.t('initialReading'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              AppLocalizations.t('finalReading'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              AppLocalizations.t('usage'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final flat in society.flats)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 44,
                              child: Text(
                                flat.flatNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            Expanded(
                              child: _MiniField(
                                controller: _initialCtrls[flat.flatNumber]!,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _MiniField(
                                controller: _finalCtrls[flat.flatNumber]!,
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '${society.currentMonth.readingFor(flat.flatNumber)?.usageLitres ?? 0}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addToBills,
                      child: Text(AppLocalizations.t('addToBills')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.label, required this.controller});
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppTheme.textMedium,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '0'),
        ),
      ],
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 12.5),
      decoration: const InputDecoration(
        hintText: '0',
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        isDense: true,
      ),
    );
  }
}
