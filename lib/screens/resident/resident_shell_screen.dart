import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/resident_bottom_nav.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import 'resident_home_screen.dart';

/// The resident's bottom-nav shell: Building / Notices / Profile.
class ResidentShellScreen extends StatefulWidget {
  const ResidentShellScreen({super.key});

  @override
  State<ResidentShellScreen> createState() => _ResidentShellScreenState();
}

class _ResidentShellScreenState extends State<ResidentShellScreen> {
  int _index = 0;

  static const _profileIndex = 2;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      BuildingTabScreen(
        onOpenProfile: () => setState(() => _index = _profileIndex),
      ),
      const CommunityScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AmbientBackground(
        child: IndexedStack(index: _index, children: tabs),
      ),
      bottomNavigationBar: ResidentBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
