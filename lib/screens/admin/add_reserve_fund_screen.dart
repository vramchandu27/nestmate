import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/reserve_contribution.dart';
import '../../providers/society_provider.dart';
import '../../utils/money.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/nav_list_tile.dart';
import '../../widgets/screen_header.dart';
import 'reserve_spending_screen.dart';

/// The reserve fund: its balance, a form for recording what residents pay
/// into it, and the record of who has paid.
///
/// Collection is per flat rather than a lump sum because residents pay at
/// their own pace — recording "₹5,000 × 16 flats" as a single number left
/// the admin no way to tell who was still outstanding, which is the
/// question they actually have between collections.
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

  /// Which flats are paying in this round. Starts empty: money arrives one
  /// resident at a time, so the admin opens this screen to record the two
  /// or three people who have just paid. Pre-ticking everyone would mean
  /// unticking twelve flats to record one payment, and would make it easy
  /// to credit the whole building by accident.
  final Set<String> _selected = {};

  @override
  void dispose() {
    _perFlatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(SocietyProvider society, Set<String> selected) async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    if (selected.isEmpty) return;

    setState(() => _isLoading = true);
    await withLoadingOverlay(
      context,
      () => society.addReserveContributions(
        flatNumbers: selected.toList()..sort(),
        perFlatPaise: parseRupeesToPaise(_perFlatCtrl.text),
      ),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _submitted = false;
      _perFlatCtrl.clear();
      // Cleared along with the amount so the next resident who pays starts
      // from nothing — leaving the previous ticks in place invites paying
      // the same flats in twice.
      _selected.clear();
    });
    // Deliberately stays on the screen rather than popping: the admin can
    // now see the payment they just recorded land in the list below, and
    // carry straight on to the next one.
    _formKey.currentState?.reset();
  }

  Future<void> _confirmDelete(
    SocietyProvider society,
    ReserveContribution c,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t('removeContributionTitle')),
        content: Text(
          '${c.flatNumber} · ${formatPaise(c.amountPaise)}\n\n'
          '${AppLocalizations.t('removeContributionBody')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.t('remove')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await society.deleteReserveContribution(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();
    final flats = society.flats;
    final selected = _selected;
    final perFlatPaise = parseRupeesToPaise(_perFlatCtrl.text);
    final totalPaise = perFlatPaise * selected.length;
    final contributions = society.reserveContributions;
    // The expenses ticked "Pay from Reserve Fund" on the expense form.
    final reserveExpenses = society.currentMonth.expenses
        .where((e) => e.fundedByReserve)
        .toList();
    final dateFormat = DateFormat('d MMM');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('reserveFundLabel')),
              Expanded(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _submitted
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _BalanceCard(
                        balancePaise: society.building.reserveFundPaise,
                        collectedPaise: society.reserveCollectedPaise,
                        pendingPaise: totalPaise,
                      ),
                      const SizedBox(height: 22),

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
                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.t('whoIsPayingLabel'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.textMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() {
                                    if (selected.length == flats.length) {
                                      selected.clear();
                                    } else {
                                      selected
                                        ..clear()
                                        ..addAll(flats.map((f) => f.flatNumber));
                                    }
                                  }),
                            child: Text(
                              selected.length == flats.length
                                  ? AppLocalizations.t('clearAll')
                                  : AppLocalizations.t('selectAll'),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Column(
                          children: [
                            for (final f in flats)
                              CheckboxListTile(
                                dense: true,
                                value: selected.contains(f.flatNumber),
                                onChanged: _isLoading
                                    ? null
                                    : (on) => setState(() {
                                        if (on == true) {
                                          selected.add(f.flatNumber);
                                        } else {
                                          selected.remove(f.flatNumber);
                                        }
                                      }),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(
                                  '${f.flatNumber}  ${f.residentName}',
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${selected.length} ${AppLocalizations.t('flats').toLowerCase()} × ${formatPaise(perFlatPaise)} = ${formatPaise(totalPaise)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isLoading || selected.isEmpty
                            ? null
                            : () => _save(society, selected),
                        child: Text(AppLocalizations.t('saveReserveFundBtn')),
                      ),

                      // Spending lives on its own screen: this one is
                      // about money coming in, and mixing the two lists
                      // on one page made it hard to tell them apart.
                      const SizedBox(height: 22),
                      NavListTile(
                        icon: Icons.receipt_long_rounded,
                        title: AppLocalizations.t('spentFromReserveLabel'),
                        trailingText: reserveExpenses.isEmpty
                            ? ''
                            : '− ${formatPaise(reserveExpenses.fold(0, (t, e) => t + e.amountPaise))}',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReserveSpendingScreen(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),
                      Divider(color: AppTheme.borderColor),
                      const SizedBox(height: 14),
                      Text(
                        AppLocalizations.t('whoHasPaidLabel'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (contributions.isEmpty)
                        Text(
                          AppLocalizations.t('noContributionsYet'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textLight,
                          ),
                        )
                      else
                        for (final c in contributions)
                          _ContributionRow(
                            contribution: c,
                            dateLabel: dateFormat.format(c.collectedOn),
                            onDelete: _isLoading
                                ? null
                                : () => _confirmDelete(society, c),
                          ),
                      const SizedBox(height: 30),
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

/// The balance, given the weight of a summary rather than sitting in a
/// bordered box above the form — where it read as one more input.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balancePaise,
    required this.collectedPaise,
    required this.pendingPaise,
  });

  final int balancePaise;
  final int collectedPaise;

  /// What the ticked flats add up to but has not been saved yet. Shown
  /// beneath the balance rather than added into it: the big number is
  /// money the society actually holds, and quietly inflating it with an
  /// unsaved selection would misreport that.
  final int pendingPaise;

  @override
  Widget build(BuildContext context) {
    // Everything paid in, minus what's left, is what the reserve has been
    // spent on — derived rather than stored, so it can't drift.
    final spentPaise = (collectedPaise - balancePaise).clamp(0, 1 << 62);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.savings_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.t('currentReserveBalance'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatPaise(balancePaise),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          if (pendingPaise > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.arrow_upward_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  '${formatPaise(pendingPaise)} ${AppLocalizations.t('pendingOnSave')}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(
                label: AppLocalizations.t('reserveCollectedLabel'),
                value: formatPaise(collectedPaise),
              ),
              const SizedBox(width: 22),
              _MiniStat(
                label: AppLocalizations.t('reserveSpentLabel'),
                value: formatPaise(spentPaise),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.contribution,
    required this.dateLabel,
    required this.onDelete,
  });

  final ReserveContribution contribution;
  final String dateLabel;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              contribution.flatNumber,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              contribution.residentName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppTheme.textMedium,
              ),
            ),
          ),
          Text(
            formatPaise(contribution.amountPaise),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            child: Text(
              dateLabel,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppTheme.textLight,
              ),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              size: 17,
              color: AppTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
