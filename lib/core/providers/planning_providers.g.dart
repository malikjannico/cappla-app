// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planning_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userCapacitiesStreamHash() =>
    r'6fc77c1b81331c731cfaa56d051bab75f6eb0245';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [userCapacitiesStream].
@ProviderFor(userCapacitiesStream)
const userCapacitiesStreamProvider = UserCapacitiesStreamFamily();

/// See also [userCapacitiesStream].
class UserCapacitiesStreamFamily
    extends Family<AsyncValue<List<UserCapacityModel>>> {
  /// See also [userCapacitiesStream].
  const UserCapacitiesStreamFamily();

  /// See also [userCapacitiesStream].
  UserCapacitiesStreamProvider call(String email) {
    return UserCapacitiesStreamProvider(email);
  }

  @override
  UserCapacitiesStreamProvider getProviderOverride(
    covariant UserCapacitiesStreamProvider provider,
  ) {
    return call(provider.email);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'userCapacitiesStreamProvider';
}

/// See also [userCapacitiesStream].
class UserCapacitiesStreamProvider
    extends AutoDisposeStreamProvider<List<UserCapacityModel>> {
  /// See also [userCapacitiesStream].
  UserCapacitiesStreamProvider(String email)
    : this._internal(
        (ref) => userCapacitiesStream(ref as UserCapacitiesStreamRef, email),
        from: userCapacitiesStreamProvider,
        name: r'userCapacitiesStreamProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$userCapacitiesStreamHash,
        dependencies: UserCapacitiesStreamFamily._dependencies,
        allTransitiveDependencies:
            UserCapacitiesStreamFamily._allTransitiveDependencies,
        email: email,
      );

  UserCapacitiesStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.email,
  }) : super.internal();

  final String email;

  @override
  Override overrideWith(
    Stream<List<UserCapacityModel>> Function(UserCapacitiesStreamRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UserCapacitiesStreamProvider._internal(
        (ref) => create(ref as UserCapacitiesStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        email: email,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<UserCapacityModel>> createElement() {
    return _UserCapacitiesStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UserCapacitiesStreamProvider && other.email == email;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, email.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UserCapacitiesStreamRef
    on AutoDisposeStreamProviderRef<List<UserCapacityModel>> {
  /// The parameter `email` of this provider.
  String get email;
}

class _UserCapacitiesStreamProviderElement
    extends AutoDisposeStreamProviderElement<List<UserCapacityModel>>
    with UserCapacitiesStreamRef {
  _UserCapacitiesStreamProviderElement(super.provider);

  @override
  String get email => (origin as UserCapacitiesStreamProvider).email;
}

String _$planningDemandsStreamHash() =>
    r'c5505705207132470ad98d7b02f5839e73c9345a';

/// See also [planningDemandsStream].
@ProviderFor(planningDemandsStream)
const planningDemandsStreamProvider = PlanningDemandsStreamFamily();

/// See also [planningDemandsStream].
class PlanningDemandsStreamFamily
    extends Family<AsyncValue<List<PlanningDemandModel>>> {
  /// See also [planningDemandsStream].
  const PlanningDemandsStreamFamily();

  /// See also [planningDemandsStream].
  PlanningDemandsStreamProvider call(int year) {
    return PlanningDemandsStreamProvider(year);
  }

  @override
  PlanningDemandsStreamProvider getProviderOverride(
    covariant PlanningDemandsStreamProvider provider,
  ) {
    return call(provider.year);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'planningDemandsStreamProvider';
}

/// See also [planningDemandsStream].
class PlanningDemandsStreamProvider
    extends AutoDisposeStreamProvider<List<PlanningDemandModel>> {
  /// See also [planningDemandsStream].
  PlanningDemandsStreamProvider(int year)
    : this._internal(
        (ref) => planningDemandsStream(ref as PlanningDemandsStreamRef, year),
        from: planningDemandsStreamProvider,
        name: r'planningDemandsStreamProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$planningDemandsStreamHash,
        dependencies: PlanningDemandsStreamFamily._dependencies,
        allTransitiveDependencies:
            PlanningDemandsStreamFamily._allTransitiveDependencies,
        year: year,
      );

  PlanningDemandsStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.year,
  }) : super.internal();

  final int year;

  @override
  Override overrideWith(
    Stream<List<PlanningDemandModel>> Function(
      PlanningDemandsStreamRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PlanningDemandsStreamProvider._internal(
        (ref) => create(ref as PlanningDemandsStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        year: year,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<PlanningDemandModel>> createElement() {
    return _PlanningDemandsStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanningDemandsStreamProvider && other.year == year;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, year.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PlanningDemandsStreamRef
    on AutoDisposeStreamProviderRef<List<PlanningDemandModel>> {
  /// The parameter `year` of this provider.
  int get year;
}

class _PlanningDemandsStreamProviderElement
    extends AutoDisposeStreamProviderElement<List<PlanningDemandModel>>
    with PlanningDemandsStreamRef {
  _PlanningDemandsStreamProviderElement(super.provider);

  @override
  int get year => (origin as PlanningDemandsStreamProvider).year;
}

String _$planningAllocationsStreamHash() =>
    r'b0bb9893852f198eaabc50f20903796738a97b60';

/// See also [planningAllocationsStream].
@ProviderFor(planningAllocationsStream)
const planningAllocationsStreamProvider = PlanningAllocationsStreamFamily();

/// See also [planningAllocationsStream].
class PlanningAllocationsStreamFamily
    extends Family<AsyncValue<List<PlanningAllocationModel>>> {
  /// See also [planningAllocationsStream].
  const PlanningAllocationsStreamFamily();

  /// See also [planningAllocationsStream].
  PlanningAllocationsStreamProvider call(int year) {
    return PlanningAllocationsStreamProvider(year);
  }

  @override
  PlanningAllocationsStreamProvider getProviderOverride(
    covariant PlanningAllocationsStreamProvider provider,
  ) {
    return call(provider.year);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'planningAllocationsStreamProvider';
}

/// See also [planningAllocationsStream].
class PlanningAllocationsStreamProvider
    extends AutoDisposeStreamProvider<List<PlanningAllocationModel>> {
  /// See also [planningAllocationsStream].
  PlanningAllocationsStreamProvider(int year)
    : this._internal(
        (ref) => planningAllocationsStream(
          ref as PlanningAllocationsStreamRef,
          year,
        ),
        from: planningAllocationsStreamProvider,
        name: r'planningAllocationsStreamProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$planningAllocationsStreamHash,
        dependencies: PlanningAllocationsStreamFamily._dependencies,
        allTransitiveDependencies:
            PlanningAllocationsStreamFamily._allTransitiveDependencies,
        year: year,
      );

  PlanningAllocationsStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.year,
  }) : super.internal();

  final int year;

  @override
  Override overrideWith(
    Stream<List<PlanningAllocationModel>> Function(
      PlanningAllocationsStreamRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PlanningAllocationsStreamProvider._internal(
        (ref) => create(ref as PlanningAllocationsStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        year: year,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<PlanningAllocationModel>>
  createElement() {
    return _PlanningAllocationsStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanningAllocationsStreamProvider && other.year == year;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, year.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PlanningAllocationsStreamRef
    on AutoDisposeStreamProviderRef<List<PlanningAllocationModel>> {
  /// The parameter `year` of this provider.
  int get year;
}

class _PlanningAllocationsStreamProviderElement
    extends AutoDisposeStreamProviderElement<List<PlanningAllocationModel>>
    with PlanningAllocationsStreamRef {
  _PlanningAllocationsStreamProviderElement(super.provider);

  @override
  int get year => (origin as PlanningAllocationsStreamProvider).year;
}

String _$allPlanningDemandsStreamHash() =>
    r'9eef4192663f043c72a50dc749b9dac0ca85d76c';

/// See also [allPlanningDemandsStream].
@ProviderFor(allPlanningDemandsStream)
const allPlanningDemandsStreamProvider = AllPlanningDemandsStreamFamily();

/// See also [allPlanningDemandsStream].
class AllPlanningDemandsStreamFamily
    extends Family<AsyncValue<List<PlanningDemandModel>>> {
  /// See also [allPlanningDemandsStream].
  const AllPlanningDemandsStreamFamily();

  /// See also [allPlanningDemandsStream].
  AllPlanningDemandsStreamProvider call(String yearsCsv) {
    return AllPlanningDemandsStreamProvider(yearsCsv);
  }

  @override
  AllPlanningDemandsStreamProvider getProviderOverride(
    covariant AllPlanningDemandsStreamProvider provider,
  ) {
    return call(provider.yearsCsv);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'allPlanningDemandsStreamProvider';
}

/// See also [allPlanningDemandsStream].
class AllPlanningDemandsStreamProvider
    extends AutoDisposeStreamProvider<List<PlanningDemandModel>> {
  /// See also [allPlanningDemandsStream].
  AllPlanningDemandsStreamProvider(String yearsCsv)
    : this._internal(
        (ref) => allPlanningDemandsStream(
          ref as AllPlanningDemandsStreamRef,
          yearsCsv,
        ),
        from: allPlanningDemandsStreamProvider,
        name: r'allPlanningDemandsStreamProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$allPlanningDemandsStreamHash,
        dependencies: AllPlanningDemandsStreamFamily._dependencies,
        allTransitiveDependencies:
            AllPlanningDemandsStreamFamily._allTransitiveDependencies,
        yearsCsv: yearsCsv,
      );

  AllPlanningDemandsStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.yearsCsv,
  }) : super.internal();

  final String yearsCsv;

  @override
  Override overrideWith(
    Stream<List<PlanningDemandModel>> Function(
      AllPlanningDemandsStreamRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AllPlanningDemandsStreamProvider._internal(
        (ref) => create(ref as AllPlanningDemandsStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        yearsCsv: yearsCsv,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<PlanningDemandModel>> createElement() {
    return _AllPlanningDemandsStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AllPlanningDemandsStreamProvider &&
        other.yearsCsv == yearsCsv;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, yearsCsv.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AllPlanningDemandsStreamRef
    on AutoDisposeStreamProviderRef<List<PlanningDemandModel>> {
  /// The parameter `yearsCsv` of this provider.
  String get yearsCsv;
}

class _AllPlanningDemandsStreamProviderElement
    extends AutoDisposeStreamProviderElement<List<PlanningDemandModel>>
    with AllPlanningDemandsStreamRef {
  _AllPlanningDemandsStreamProviderElement(super.provider);

  @override
  String get yearsCsv => (origin as AllPlanningDemandsStreamProvider).yearsCsv;
}

String _$allPlanningAllocationsStreamHash() =>
    r'25f9c55ba76322c5037c8d4e499a757ba33b264a';

/// See also [allPlanningAllocationsStream].
@ProviderFor(allPlanningAllocationsStream)
const allPlanningAllocationsStreamProvider =
    AllPlanningAllocationsStreamFamily();

/// See also [allPlanningAllocationsStream].
class AllPlanningAllocationsStreamFamily
    extends Family<AsyncValue<List<PlanningAllocationModel>>> {
  /// See also [allPlanningAllocationsStream].
  const AllPlanningAllocationsStreamFamily();

  /// See also [allPlanningAllocationsStream].
  AllPlanningAllocationsStreamProvider call(String yearsCsv) {
    return AllPlanningAllocationsStreamProvider(yearsCsv);
  }

  @override
  AllPlanningAllocationsStreamProvider getProviderOverride(
    covariant AllPlanningAllocationsStreamProvider provider,
  ) {
    return call(provider.yearsCsv);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'allPlanningAllocationsStreamProvider';
}

/// See also [allPlanningAllocationsStream].
class AllPlanningAllocationsStreamProvider
    extends AutoDisposeStreamProvider<List<PlanningAllocationModel>> {
  /// See also [allPlanningAllocationsStream].
  AllPlanningAllocationsStreamProvider(String yearsCsv)
    : this._internal(
        (ref) => allPlanningAllocationsStream(
          ref as AllPlanningAllocationsStreamRef,
          yearsCsv,
        ),
        from: allPlanningAllocationsStreamProvider,
        name: r'allPlanningAllocationsStreamProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$allPlanningAllocationsStreamHash,
        dependencies: AllPlanningAllocationsStreamFamily._dependencies,
        allTransitiveDependencies:
            AllPlanningAllocationsStreamFamily._allTransitiveDependencies,
        yearsCsv: yearsCsv,
      );

  AllPlanningAllocationsStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.yearsCsv,
  }) : super.internal();

  final String yearsCsv;

  @override
  Override overrideWith(
    Stream<List<PlanningAllocationModel>> Function(
      AllPlanningAllocationsStreamRef provider,
    )
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AllPlanningAllocationsStreamProvider._internal(
        (ref) => create(ref as AllPlanningAllocationsStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        yearsCsv: yearsCsv,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<PlanningAllocationModel>>
  createElement() {
    return _AllPlanningAllocationsStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AllPlanningAllocationsStreamProvider &&
        other.yearsCsv == yearsCsv;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, yearsCsv.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin AllPlanningAllocationsStreamRef
    on AutoDisposeStreamProviderRef<List<PlanningAllocationModel>> {
  /// The parameter `yearsCsv` of this provider.
  String get yearsCsv;
}

class _AllPlanningAllocationsStreamProviderElement
    extends AutoDisposeStreamProviderElement<List<PlanningAllocationModel>>
    with AllPlanningAllocationsStreamRef {
  _AllPlanningAllocationsStreamProviderElement(super.provider);

  @override
  String get yearsCsv =>
      (origin as AllPlanningAllocationsStreamProvider).yearsCsv;
}

String _$locksStreamHash() => r'49f693e048eb911b47e62e0b32ed5d9408e545d8';

/// See also [locksStream].
@ProviderFor(locksStream)
const locksStreamProvider = LocksStreamFamily();

/// See also [locksStream].
class LocksStreamFamily extends Family<AsyncValue<List<LockModel>>> {
  /// See also [locksStream].
  const LocksStreamFamily();

  /// See also [locksStream].
  LocksStreamProvider call(int year) {
    return LocksStreamProvider(year);
  }

  @override
  LocksStreamProvider getProviderOverride(
    covariant LocksStreamProvider provider,
  ) {
    return call(provider.year);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'locksStreamProvider';
}

/// See also [locksStream].
class LocksStreamProvider extends AutoDisposeStreamProvider<List<LockModel>> {
  /// See also [locksStream].
  LocksStreamProvider(int year)
    : this._internal(
        (ref) => locksStream(ref as LocksStreamRef, year),
        from: locksStreamProvider,
        name: r'locksStreamProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$locksStreamHash,
        dependencies: LocksStreamFamily._dependencies,
        allTransitiveDependencies: LocksStreamFamily._allTransitiveDependencies,
        year: year,
      );

  LocksStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.year,
  }) : super.internal();

  final int year;

  @override
  Override overrideWith(
    Stream<List<LockModel>> Function(LocksStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LocksStreamProvider._internal(
        (ref) => create(ref as LocksStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        year: year,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<LockModel>> createElement() {
    return _LocksStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LocksStreamProvider && other.year == year;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, year.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin LocksStreamRef on AutoDisposeStreamProviderRef<List<LockModel>> {
  /// The parameter `year` of this provider.
  int get year;
}

class _LocksStreamProviderElement
    extends AutoDisposeStreamProviderElement<List<LockModel>>
    with LocksStreamRef {
  _LocksStreamProviderElement(super.provider);

  @override
  int get year => (origin as LocksStreamProvider).year;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
