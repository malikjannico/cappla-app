// File: lib/models/enums.dart

class UserRole {
  final String value;
  const UserRole(this.value);

  static const user = UserRole('User');
  static const administrator = UserRole('Administrator');

  static UserRole fromString(String val) {
    final clean = val.trim().toLowerCase();
    if (clean == 'administrator' || clean == 'admin') {
      return UserRole.administrator;
    }
    return UserRole.user;
  }

  String toLowerCase() => value.toLowerCase();
  String toUpperCase() => value.toUpperCase();
  String trim() => value.trim();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is UserRole) return value == other.value;
    if (other is String) return value.trim().toLowerCase() == other.trim().toLowerCase();
    return false;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

class UserStatus {
  final String value;
  const UserStatus(this.value);

  static const active = UserStatus('Active');
  static const inactive = UserStatus('Inactive');

  static UserStatus fromString(String val) {
    final clean = val.trim().toLowerCase();
    if (clean == 'inactive') return UserStatus.inactive;
    return UserStatus.active;
  }

  String toLowerCase() => value.toLowerCase();
  String toUpperCase() => value.toUpperCase();
  String trim() => value.trim();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is UserStatus) return value == other.value;
    if (other is String) return value.trim().toLowerCase() == other.trim().toLowerCase();
    return false;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

enum OrgUnitType {
  mdDivision('md division'),
  svpDivision('svp division'),
  vpDivision('vp division'),
  department('department'),
  group('group'),
  team('team');

  final String value;
  const OrgUnitType(this.value);

  static OrgUnitType fromString(String val) {
    final clean = val.trim().toLowerCase();
    switch (clean) {
      case 'md division':
      case 'mddivision':
        return OrgUnitType.mdDivision;
      case 'svp division':
      case 'svpdivision':
        return OrgUnitType.svpDivision;
      case 'vp division':
      case 'vpdivision':
        return OrgUnitType.vpDivision;
      case 'department':
        return OrgUnitType.department;
      case 'group':
        return OrgUnitType.group;
      case 'team':
      default:
        return OrgUnitType.team;
    }
  }

  String toLowerCase() => value.toLowerCase();
  String toUpperCase() => value.toUpperCase();
  String trim() => value.trim();

  @override
  String toString() => value;
}

enum CapacityType {
  standard('Standard'),
  specific('Specific');

  final String value;
  const CapacityType(this.value);

  static CapacityType fromString(String val) {
    final clean = val.trim().toLowerCase();
    if (clean == 'specific') return CapacityType.specific;
    return CapacityType.standard;
  }

  String toLowerCase() => value.toLowerCase();
  String toUpperCase() => value.toUpperCase();
  String trim() => value.trim();

  @override
  String toString() => value;
}

enum ActivityType {
  unlimited('Unlimited'),
  limited('Limited');

  final String value;
  const ActivityType(this.value);

  static ActivityType fromString(String val) {
    final clean = val.trim().toLowerCase();
    if (clean == 'limited') return ActivityType.limited;
    return ActivityType.unlimited;
  }

  String toLowerCase() => value.toLowerCase();
  String toUpperCase() => value.toUpperCase();
  String trim() => value.trim();

  @override
  String toString() => value;
}
