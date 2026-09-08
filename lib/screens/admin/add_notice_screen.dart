import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../providers/society_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/screen_header.dart';

/// Post a notice to this building's own notice feed — residents see it in
/// their Notices tab. Scoped to this block only, no cross-building
/// association required.
class AddNoticeScreen extends StatefulWidget {
  const AddNoticeScreen({super.key});

  @override
  State<AddNoticeScreen> createState() => _AddNoticeScreenState();
}

class _AddNoticeScreenState extends State<AddNoticeScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await withLoadingOverlay(
      context,
      () => context.read<SocietyProvider>().addPost(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              ScreenHeader(title: AppLocalizations.t('communityNotices')),
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
                        AppLocalizations.t(
                          'expenseNameLabel',
                          defaultValue: 'Title',
                        ),
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
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.t('fieldRequired')
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.t('writeComment'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bodyCtrl,
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 5,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: Text(AppLocalizations.t('submit')),
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
