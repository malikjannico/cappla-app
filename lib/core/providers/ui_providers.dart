// File: lib/core/providers/ui_providers.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/user_model.dart';
import '../../models/org_unit_model.dart';

part 'ui_providers.g.dart';

@Riverpod(keepAlive: true)
class SelectedTabCollection extends _$SelectedTabCollection {
  @override
  String build() => 'Standard';

  @override
  set state(String value) => super.state = value;
}

@Riverpod(keepAlive: true)
class CurrentAdminRoute extends _$CurrentAdminRoute {
  @override
  String build() => 'users';

  @override
  set state(String value) => super.state = value;
}

@Riverpod(keepAlive: true)
class SelectedUserForDetails extends _$SelectedUserForDetails {
  @override
  UserModel? build() => null;

  @override
  set state(UserModel? value) => super.state = value;
}

@Riverpod(keepAlive: true)
class SelectedOrgForDetails extends _$SelectedOrgForDetails {
  @override
  OrgUnitModel? build() => null;

  @override
  set state(OrgUnitModel? value) => super.state = value;
}

@Riverpod(keepAlive: true)
class ShowDetailedUserCreateForm extends _$ShowDetailedUserCreateForm {
  @override
  bool build() => false;

  @override
  set state(bool value) => super.state = value;
}

@Riverpod(keepAlive: true)
class ShowDetailedOrgCreateForm extends _$ShowDetailedOrgCreateForm {
  @override
  bool build() => false;

  @override
  set state(bool value) => super.state = value;
}

@Riverpod(keepAlive: true)
class ShowDetailedOrgChildInput extends _$ShowDetailedOrgChildInput {
  @override
  bool build() => false;

  @override
  set state(bool value) => super.state = value;
}
