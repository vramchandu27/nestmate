import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/issue_report.dart';
import '../../providers/app_provider.dart';
import '../../providers/society_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
import '../../widgets/issue_details_sheet.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/photo_picker_field.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';

/// Report-a-problem form plus the resident's own issue history below it.
class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _type;
  File? _photoFile;
  bool _isLoading = false;
  bool _submitted = false;

  static const _types = [
    'Drainage',
    'Plumbing',
    'Electrical',
    'Common area',
    'Other',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(String flatNumber) async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    final society = context.read<SocietyProvider>();
    setState(() => _isLoading = true);
    try {
      await withLoadingOverlay(context, () async {
        String? photoUrl;
        final photo = _photoFile;
        if (photo != null) {
          photoUrl = await StorageService().uploadPhoto(
            basePath: 'buildings/main/issues/${DateTime.now().microsecondsSinceEpoch}',
            file: photo,
          );
        }
        await society.addIssue(
          title: _titleCtrl.text.trim(),
          type: _type!,
          location: _locationCtrl.text.trim(),
          flatNumber: flatNumber,
          photoAdded: photo != null,
          photoUrl: photoUrl,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.t('errorOccurred')),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.t('issueSubmitted')),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final flatNumber = context.watch<AppProvider>().flatNumber ?? '';
    final society = context.watch<SocietyProvider>();
    final issues = society.issuesForFlat(flatNumber);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('reportIssue')),
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
                        AppLocalizations.t('whatIssue'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleCtrl,
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.t('fieldRequired')
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.t('issueType'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        hint: Text(AppLocalizations.t('selectIssueType')),
                        items: _types
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _type = v),
                        validator: (v) =>
                            v == null ? AppLocalizations.t('fieldRequired') : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.t('whereLocation'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _locationCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(),
                      ),
                      const SizedBox(height: 16),
                      PhotoPickerField(
                        label: AppLocalizations.t('addPhoto'),
                        file: _photoFile,
                        onChanged: (f) => setState(() => _photoFile = f),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _submit(flatNumber),
                        child: Text(AppLocalizations.t('submit')),
                      ),
                      const SizedBox(height: 26),
                      SectionHeader(AppLocalizations.t('myIssues')),
                      for (final issue in issues)
                        GestureDetector(
                          onTap: () => showIssueDetails(context, issue: issue),
                          child: AppCard(
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        issue.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14.5,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        issue.location,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusPill(
                                  label: issue.status == IssueStatus.resolved
                                      ? AppLocalizations.t('resolved')
                                      : AppLocalizations.t('inProgress'),
                                  status: issue.status == IssueStatus.resolved
                                      ? PillStatus.resolved
                                      : PillStatus.inProgress,
                                ),
                              ],
                            ),
                          ),
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
