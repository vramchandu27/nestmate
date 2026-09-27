/// User roles in NestMate
enum UserRole {
  /// Platform-level admin managing multiple communities
  platformAdmin,

  /// Community admin managing a single apartment community
  communityAdmin,

  /// Read-mostly access to community information
  committee,

  /// Resident accessing their own flat and community info
  resident,

  /// Not tied to any building or flat at all — just uses the app's
  /// personal expense tracker on its own. See [PersonalExpensesScreen]'s
  /// standalone entry point from the Welcome screen.
  personal,

  /// No role assigned yet (new user)
  none,
}

extension UserRoleExtension on UserRole {
  String get name {
    switch (this) {
      case UserRole.platformAdmin:
        return 'Platform Admin';
      case UserRole.communityAdmin:
        return 'Community Admin';
      case UserRole.committee:
        return 'Committee';
      case UserRole.resident:
        return 'Resident';
      case UserRole.personal:
        return 'Personal';
      case UserRole.none:
        return 'Unassigned';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.platformAdmin:
        return 'Platform Administrator';
      case UserRole.communityAdmin:
        return 'Community Administrator';
      case UserRole.committee:
        return 'Committee Member';
      case UserRole.resident:
        return 'Resident';
      case UserRole.personal:
        return 'Personal';
      case UserRole.none:
        return 'No Role';
    }
  }

  /// Check if user is admin (platform or community)
  bool get isAdmin {
    return this == UserRole.platformAdmin || this == UserRole.communityAdmin;
  }

  /// Check if user has read-write access
  bool get hasWriteAccess {
    return this == UserRole.platformAdmin || this == UserRole.communityAdmin;
  }
}
