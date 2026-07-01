// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'org_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$orgUnitsStreamHash() => r'0e3bca99897887471786dfaa44b856a33e295292';

/// See also [orgUnitsStream].
@ProviderFor(orgUnitsStream)
final orgUnitsStreamProvider =
    AutoDisposeStreamProvider<List<OrgUnitModel>>.internal(
      orgUnitsStream,
      name: r'orgUnitsStreamProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$orgUnitsStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OrgUnitsStreamRef = AutoDisposeStreamProviderRef<List<OrgUnitModel>>;
String _$orgUnitStreamHash() => r'830b53c737db4fdd2f0d4634b7c818ec995727d8';

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

/// See also [orgUnitStream].
@ProviderFor(orgUnitStream)
const orgUnitStreamProvider = OrgUnitStreamFamily();

/// See also [orgUnitStream].
class OrgUnitStreamFamily extends Family<AsyncValue<OrgUnitModel?>> {
  /// See also [orgUnitStream].
  const OrgUnitStreamFamily();

  /// See also [orgUnitStream].
  OrgUnitStreamProvider call(String id) {
    return OrgUnitStreamProvider(id);
  }

  @override
  OrgUnitStreamProvider getProviderOverride(
    covariant OrgUnitStreamProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'orgUnitStreamProvider';
}

/// See also [orgUnitStream].
class OrgUnitStreamProvider extends AutoDisposeStreamProvider<OrgUnitModel?> {
  /// See also [orgUnitStream].
  OrgUnitStreamProvider(String id)
    : this._internal(
        (ref) => orgUnitStream(ref as OrgUnitStreamRef, id),
        from: orgUnitStreamProvider,
        name: r'orgUnitStreamProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$orgUnitStreamHash,
        dependencies: OrgUnitStreamFamily._dependencies,
        allTransitiveDependencies:
            OrgUnitStreamFamily._allTransitiveDependencies,
        id: id,
      );

  OrgUnitStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    Stream<OrgUnitModel?> Function(OrgUnitStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: OrgUnitStreamProvider._internal(
        (ref) => create(ref as OrgUnitStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<OrgUnitModel?> createElement() {
    return _OrgUnitStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OrgUnitStreamProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin OrgUnitStreamRef on AutoDisposeStreamProviderRef<OrgUnitModel?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _OrgUnitStreamProviderElement
    extends AutoDisposeStreamProviderElement<OrgUnitModel?>
    with OrgUnitStreamRef {
  _OrgUnitStreamProviderElement(super.provider);

  @override
  String get id => (origin as OrgUnitStreamProvider).id;
}

String _$userOwnedOrgUnitHash() => r'6c7c4bb67c552c5aa168ef9f8d0efde69598d51d';

/// See also [userOwnedOrgUnit].
@ProviderFor(userOwnedOrgUnit)
final userOwnedOrgUnitProvider = AutoDisposeProvider<OrgUnitModel?>.internal(
  userOwnedOrgUnit,
  name: r'userOwnedOrgUnitProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userOwnedOrgUnitHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserOwnedOrgUnitRef = AutoDisposeProviderRef<OrgUnitModel?>;
String _$userOrgUnitHash() => r'91ecec2b78eb3e2f66ad9289afe5a1c0cabd9c24';

/// See also [userOrgUnit].
@ProviderFor(userOrgUnit)
final userOrgUnitProvider = AutoDisposeProvider<OrgUnitModel?>.internal(
  userOrgUnit,
  name: r'userOrgUnitProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userOrgUnitHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserOrgUnitRef = AutoDisposeProviderRef<OrgUnitModel?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
