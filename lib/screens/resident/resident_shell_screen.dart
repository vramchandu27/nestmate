import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/society_provider.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/resident_bottom_nav.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import 'resident_home_screen.dart';

/// The resident's bottom-nav shell: Building / Community / Profile.
/// Community is omitted entirely when the building hasn't joined an
/// association.
class ResidentShellScreen extends StatefulWidget {
  const ResidentShellScreen({super.key});

  @override
  State<ResidentShellScreen> createState() => _ResidentShellScreenState();
}

class _ResidentShellScreenState extends State<ResidentShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final showCommunity = context.watch<SocietyProvider>().association.joined;
    final profileIndex = showCommunity ? 2 : 1;
    if (_index > profileIndex) _index = profileIndex;

    final tabs = <Widget>[
      BuildingTabScreen(
        onOpenProfile: () => setState(() => _index = profileIndex),
      ),
      if (showCommunity) const CommunityScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: IndexedStack(index: _index, children: tabs),
      ),
      bottomNavigationBar: ResidentBottomNav(
        currentIndex: _index,
        showCommunity: showCommunity,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
