enum UserRole { customer, driver, admin }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.driver:
        return 'Driver';
      case UserRole.admin:
        return 'Administrator';
    }
  }
}