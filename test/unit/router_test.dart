import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:cappla/core/router/router_paths.dart';
import 'package:cappla/core/router/router_guards.dart';

class MockBuildContext extends Mock implements BuildContext {}

class MockGoRouterState extends Mock implements GoRouterState {}

class TestAuthState implements AuthStateInterface {
  @override
  final bool isAuthenticated;
  @override
  final UserProfile? currentUser;
  final bool isOrgActive;
  @override
  final bool isOrgUnitsLoading;

  TestAuthState({
    required this.isAuthenticated,
    this.currentUser,
    this.isOrgActive = true,
    this.isOrgUnitsLoading = false,
  });

  @override
  bool isOrgUnitActive(String orgUnitId) => isOrgActive;
}

void main() {
  late MockBuildContext mockContext;
  late MockGoRouterState mockState;

  setUp(() {
    mockContext = MockBuildContext();
    mockState = MockGoRouterState();
  });

  group('Router Guards Tests', () {
    test(
      'Test Case 1: Unauthenticated Redirect: If isAuthenticated is false, accessing /plan redirects to /login',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.planning);
        final authState = TestAuthState(isAuthenticated: false);

        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, equals(RouterPaths.login));
      },
    );

    test(
      'Test Case 2: Login Access Bypass: If isAuthenticated is false, accessing /login allows access',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.login);
        final authState = TestAuthState(isAuthenticated: false);

        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, isNull);
      },
    );

    test(
      'Test Case 2.1: Reset Password Access Bypass: If isAuthenticated is false, accessing /reset-password allows access',
      () {
        when(
          () => mockState.matchedLocation,
        ).thenReturn(RouterPaths.resetPassword);
        final authState = TestAuthState(isAuthenticated: false);

        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, isNull);
      },
    );

    test(
      'Test Case 3: Authenticated Redirect: If isAuthenticated is true, accessing /login redirects to /plan',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.login);
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'user@example.com',
            role: 'User',
            status: 'Active',
            orgUnitId: 'some-org',
          ),
        );

        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, equals(RouterPaths.planning));
      },
    );

    test(
      'Test Case 4: Admin Guard Violation: If role is User, accessing /admin/users redirects to /plan',
      () {
        when(
          () => mockState.matchedLocation,
        ).thenReturn(RouterPaths.adminUsers);
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'user@example.com',
            role: 'User',
            status: 'Active',
            orgUnitId: 'some-org',
          ),
        );

        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, equals(RouterPaths.planning));
      },
    );

    test(
      'Test Case 5: Admin Guard Success: If role is Administrator, accessing /admin/users allows access',
      () {
        when(
          () => mockState.matchedLocation,
        ).thenReturn(RouterPaths.adminUsers);
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'admin@example.com',
            role: 'Administrator',
            status: 'Active',
            orgUnitId: 'some-org',
          ),
        );

        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, isNull);
      },
    );

    test(
      'Test Case 6: Inactive User Redirect: If status is Inactive, accessing any page redirects to /login',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.planning);
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'inactive@example.com',
            role: 'User',
            status: 'Inactive',
            orgUnitId: 'some-org',
          ),
        );

        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, equals(RouterPaths.login));
      },
    );

    test(
      'Test Case 7: Access plan/settings without org unit (Standard User) redirects to /',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.planning);
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'user@example.com',
            role: 'User',
            status: 'Active',
            orgUnitId: null,
          ),
        );
        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, equals(RouterPaths.home));
      },
    );

    test(
      'Test Case 7.1: Access / without org unit (Standard User) is allowed',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.home);
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'user@example.com',
            role: 'User',
            status: 'Active',
            orgUnitId: null,
          ),
        );
        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, isNull);
      },
    );

    test(
      'Test Case 7.2: Access / with org unit (Standard User) redirects to /plan',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.home);
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'user@example.com',
            role: 'User',
            status: 'Active',
            orgUnitId: 'some-org',
          ),
        );
        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, equals(RouterPaths.planning));
      },
    );

    test(
      'Test Case 7.3: Access /login when authenticated without org unit (Standard User) redirects to /',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.login);
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'user@example.com',
            role: 'User',
            status: 'Active',
            orgUnitId: null,
          ),
        );
        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, equals(RouterPaths.home));
      },
    );

    test(
      'Test Case 7.3.1: Access /login when authenticated without org unit (Administrator) redirects to /',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.login);
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'admin@example.com',
            role: 'Administrator',
            status: 'Active',
            orgUnitId: null,
          ),
        );
        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, equals(RouterPaths.home));
      },
    );

    test(
      'Test Case 7.4: Access / as Administrator without org unit is allowed',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.home);
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'admin@example.com',
            role: 'Administrator',
            status: 'Active',
            orgUnitId: null,
          ),
        );
        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, isNull);
      },
    );

    test(
      'Test Case 8: Access plan/settings without org unit (Administrator) redirects to /',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.planning);
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'admin@example.com',
            role: 'Administrator',
            status: 'Active',
            orgUnitId: null,
          ),
        );
        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, equals(RouterPaths.home));
      },
    );

    test(
      'Test Case 9: Access settings when not head of unit redirects to /plan',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.settings);
        final authState = TestAuthState(
          isAuthenticated: true,
          currentUser: UserProfile(
            email: 'user@example.com',
            role: 'User',
            status: 'Active',
            orgUnitId: 'some-org',
            isHeadOfOrg: false,
          ),
        );
        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, equals(RouterPaths.planning));
      },
    );

    test('Test Case 10: Access settings when head of unit is allowed', () {
      when(() => mockState.matchedLocation).thenReturn(RouterPaths.settings);
      final authState = TestAuthState(
        isAuthenticated: true,
        currentUser: UserProfile(
          email: 'user@example.com',
          role: 'User',
          status: 'Active',
          orgUnitId: 'some-org',
          isHeadOfOrg: true,
        ),
      );
      final result = appRedirectGuard(mockContext, mockState, authState);
      expect(result, isNull);
    });

    test(
      'Test Case 11: Access plan/settings without org unit (Administrator) redirects to / even if isOrgUnitsLoading is true',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.planning);
        final authState = TestAuthState(
          isAuthenticated: true,
          isOrgUnitsLoading: true,
          currentUser: UserProfile(
            email: 'admin@example.com',
            role: 'Administrator',
            status: 'Active',
            orgUnitId: null,
          ),
        );
        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, equals(RouterPaths.home));
      },
    );

    test(
      'Test Case 12: Access plan/settings without org unit (Standard User) redirects to / even if isOrgUnitsLoading is true',
      () {
        when(() => mockState.matchedLocation).thenReturn(RouterPaths.planning);
        final authState = TestAuthState(
          isAuthenticated: true,
          isOrgUnitsLoading: true,
          currentUser: UserProfile(
            email: 'user@example.com',
            role: 'User',
            status: 'Active',
            orgUnitId: null,
          ),
        );
        final result = appRedirectGuard(mockContext, mockState, authState);
        expect(result, equals(RouterPaths.home));
      },
    );
  });
}
