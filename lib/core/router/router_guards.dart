// File: lib/core/router/router_guards.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'router_paths.dart';

// Interface representation of User Profile
class UserProfile {
  final String email;
  final String role; // "Administrator" or "User"
  final String status; // "Active" or "Inactive"
  final String? orgUnitId;
  final bool isHeadOfOrg;

  UserProfile({
    required this.email,
    required this.role,
    required this.status,
    this.orgUnitId,
    this.isHeadOfOrg = false,
  });
}

// Interface representation of Auth State
abstract class AuthStateInterface {
  bool get isAuthenticated;
  UserProfile? get currentUser;
  bool isOrgUnitActive(String orgUnitId);
  bool get isOrgUnitsLoading;
}

// Redirect Guard Implementation
String? appRedirectGuard(
  BuildContext context,
  GoRouterState state,
  AuthStateInterface authState,
) {
  final isAuthenticated = authState.isAuthenticated;
  final currentUser = authState.currentUser;

  final isLoggingIn = state.matchedLocation == RouterPaths.login;
  final isResettingPassword =
      state.matchedLocation == RouterPaths.resetPassword;

  // 1. Unauthenticated or Inactive users
  if (currentUser == null ||
      !isAuthenticated ||
      currentUser.status == 'Inactive') {
    if (isLoggingIn || isResettingPassword) {
      return null; // Permit access to authentication pages
    }
    return RouterPaths.login; // Force login redirect
  }

  // 2. Authenticated users going to auth pages
  if (isLoggingIn || isResettingPassword) {
    final hasOrgUnitId =
        currentUser.orgUnitId != null && currentUser.orgUnitId!.isNotEmpty;
    if (!hasOrgUnitId) {
      return RouterPaths.home;
    }
    if (authState.isOrgUnitsLoading) {
      return null; // Defer redirect until organization units stream resolves
    }
    final hasActiveOrgUnit = authState.isOrgUnitActive(currentUser.orgUnitId!);
    if (!hasActiveOrgUnit) {
      return RouterPaths.home;
    }
    return RouterPaths.planning; // Redirect to home landing page
  }

  // 2.5. Root Path Guard
  final isHome = state.matchedLocation == RouterPaths.home;
  if (isHome) {
    final hasOrgUnitId =
        currentUser.orgUnitId != null && currentUser.orgUnitId!.isNotEmpty;
    if (!hasOrgUnitId) {
      return null; // Allow staying on home /
    }
    if (authState.isOrgUnitsLoading) {
      return null; // Defer redirect until organization units stream resolves
    }
    final hasActiveOrgUnit = authState.isOrgUnitActive(currentUser.orgUnitId!);
    if (hasActiveOrgUnit) {
      return RouterPaths.planning;
    }
  }

  // 3. Organization Unit Guards for planning, settings, reports, dashboards
  final isPlanning =
      state.matchedLocation.startsWith('/plan') ||
      state.matchedLocation.startsWith('/reports') ||
      state.matchedLocation.startsWith('/dashboards');
  final isSettings = state.matchedLocation == RouterPaths.settings;

  if (isPlanning || isSettings) {
    final hasOrgUnitId =
        currentUser.orgUnitId != null && currentUser.orgUnitId!.isNotEmpty;
    if (!hasOrgUnitId) {
      return RouterPaths.home; // Both users and admins redirect to home /
    }
    if (authState.isOrgUnitsLoading) {
      return null; // Defer redirect until organization units stream resolves
    }
    final hasActiveOrgUnit = authState.isOrgUnitActive(currentUser.orgUnitId!);
    if (!hasActiveOrgUnit) {
      return RouterPaths.home; // Both users and admins redirect to home /
    }

    if (isSettings && !currentUser.isHeadOfOrg) {
      return RouterPaths.planning;
    }
  }

  // 4. Administrator Role Guard
  final isAdminPath = state.matchedLocation.startsWith('/admin');
  if (isAdminPath) {
    final isAdmin = currentUser.role == 'Administrator';
    if (!isAdmin) {
      return RouterPaths.planning; // Access denied, redirect to home page
    }
  }

  return null; // Allow navigation to target path
}
