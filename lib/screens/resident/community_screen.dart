import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../config/localization/app_localizations.dart';
import '../../models/community_post.dart';
import '../../providers/app_provider.dart';
import '../../providers/society_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icon_badge.dart';

/// The association's notice feed — purely informational, fully decoupled
/// from billing. Shown only once the building has joined an association.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final society = context.watch<SocietyProvider>();

    if (!society.association.joined) {
      return SafeArea(
        child: EmptyState(
          icon: Icons.groups_rounded,
          title: AppLocalizations.t('notJoinedCommunity'),
          subtitle: AppLocalizations.t('communityLocked'),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 14),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primary, AppTheme.primaryDark],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  society.association.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${AppLocalizations.t('communitySub')} · ${society.association.buildingCount} buildings',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final post in society.posts) _PostCard(post: post),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  const _PostCard({required this.post});
  final CommunityPost post;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge.icon(Icons.apartment_rounded, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      post.timeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (post.pinned)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '📌 ${AppLocalizations.t('pinned')}',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            post.body,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppTheme.textMedium,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Action(
                icon: Icons.favorite_border_rounded,
                label: '${post.likeCount}',
                onTap: () => context.read<SocietyProvider>().likePost(post.id),
              ),
              const SizedBox(width: 8),
              _Action(
                icon: Icons.mode_comment_outlined,
                label:
                    '${post.comments.length} ${AppLocalizations.t('comments')}',
                onTap: null,
              ),
            ],
          ),
          if (post.comments.isNotEmpty) ...[
            const SizedBox(height: 11),
            for (final c in post.comments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBadge.text(
                      c.authorName.isNotEmpty ? c.authorName[0] : '?',
                      size: 26,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.authorName,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              c.text,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.textMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.t('writeComment'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_commentCtrl.text.trim().isEmpty) return;
                  final name = context.read<AppProvider>().userName ?? '';
                  context.read<SocietyProvider>().addComment(
                    post.id,
                    name,
                    _commentCtrl.text.trim(),
                  );
                  _commentCtrl.clear();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                child: Text(AppLocalizations.t('comment')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppTheme.textMedium),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
