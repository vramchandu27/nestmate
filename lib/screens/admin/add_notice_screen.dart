import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/community_post.dart';
import '../../providers/society_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/app_card.dart';
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

                      // Everything below is the notices already posted.
                      // This screen used to be the form alone, so the admin
                      // wrote into a void — no way to see what had gone out,
                      // and no way to read a single reply to it.
                      const SizedBox(height: 28),
                      Divider(color: AppTheme.borderColor),
                      const SizedBox(height: 14),
                      Text(
                        AppLocalizations.t('postedNoticesLabel'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (context.watch<SocietyProvider>().posts.isEmpty)
                        Text(
                          AppLocalizations.t('noNoticesYet'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textLight,
                          ),
                        )
                      else
                        for (final post
                            in context.watch<SocietyProvider>().posts)
                          _PostedNoticeCard(post: post),
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

/// One already-posted notice, with whatever residents have said about it.
///
/// The comments are the point: an admin posts to ask something ("is anyone
/// free Saturday for the tank cleaning?") and previously had no way to read
/// a single reply from this screen.
class _PostedNoticeCard extends StatelessWidget {
  const _PostedNoticeCard({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              Text(
                post.timeLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textLight,
                ),
              ),
            ],
          ),
          if (post.body.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              post.body,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textMedium,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 14,
                color: AppTheme.textLight,
              ),
              const SizedBox(width: 4),
              Text(
                '${post.likeCount}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textLight,
                ),
              ),
              const SizedBox(width: 14),
              const Icon(
                Icons.mode_comment_rounded,
                size: 13,
                color: AppTheme.textLight,
              ),
              const SizedBox(width: 4),
              Text(
                '${post.comments.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textLight,
                ),
              ),
            ],
          ),
          for (final c in post.comments) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.authorName,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.text,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textMedium,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
