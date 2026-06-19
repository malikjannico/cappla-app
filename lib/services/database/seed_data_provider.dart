import '../../models/user_model.dart';
import '../../models/org_unit_model.dart';
import '../../models/category_model.dart';
import '../../models/activity_group_model.dart';
import '../../models/activity_model.dart';
import '../../models/user_capacity_model.dart';
import 'database_service.dart';

Future<void> performFullSeeding(DatabaseService db) async {
  // 1. Seed Admin User first so that subsequent writes (like Org Units) satisfy isAdmin() security rules
  final admin = UserModel(
    id: '00000000-0000-0000-0000-000000000000',
    fullName: 'Malik Jannico Press',
    email: 'MalikJannico.Press@vetter-pharma.com',
    title: 'Administrator',
    status: 'Active',
    role: 'Administrator',
    orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
  );
  await db.saveUser(admin);

  // 2. Seed Org Units (using a sequence that satisfies parent-child reference integrity validations)
  final orgCSInit = OrgUnitModel(
    id: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    name: 'IT Core Solutions',
    abbreviation: 'IT CS',
    headOfEmail: 'malikjannico.press@vetter-pharma.com',
    type: 'department',
    status: 'Active',
    childIds: const [], // Start empty to pass child existence validations
  );
  await db.saveOrgUnit(orgCSInit);

  final orgDQS = OrgUnitModel(
    id: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
    name: 'IT Document & Quality Solutions',
    abbreviation: 'IT DQS',
    headOfEmail: 'malikjannico.press@vetter-pharma.com',
    type: 'team',
    status: 'Active',
    parentId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    childIds: const [],
  );
  await db.saveOrgUnit(orgDQS);

  final orgMLS = OrgUnitModel(
    id: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
    name: 'IT Manufacturing & Lab Solutions',
    abbreviation: 'IT MLS',
    headOfEmail: 'sandro.perez.veiga@vetter-pharma.com',
    type: 'team',
    status: 'Active',
    parentId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
    childIds: const [],
  );
  await db.saveOrgUnit(orgMLS);

  // Re-save parent department now that children exist to finalize reference integrity
  final orgCSFinal = orgCSInit.copyWith(
    childIds: const [
      'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
    ],
  );
  await db.saveOrgUnit(orgCSFinal);

  // 3. Seed remaining Users
  final mateo = UserModel(
    id: 'd5f1a547-4927-4a7b-a010-3375c3db7383',
    fullName: 'Mateo Kevric',
    email: 'mateo.kevric@vetter-pharma.com',
    title: 'Employee',
    status: 'Active',
    role: 'User',
    orgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
  );
  await db.saveUser(mateo);

  final sandro = UserModel(
    id: 'e5f1a547-4927-4a7b-a010-3375c3db7383',
    fullName: 'Sandro Perez Veiga',
    email: 'sandro.perez.veiga@vetter-pharma.com',
    title: 'Team Lead',
    status: 'Active',
    role: 'User',
    orgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
  );
  await db.saveUser(sandro);

  final sven = UserModel(
    id: 'f5f1a547-4927-4a7b-a010-3375c3db7383',
    fullName: 'Sven Reisenhauer',
    email: 'sven.reisenhauer@vetter-pharma.com',
    title: 'Employee',
    status: 'Active',
    role: 'User',
    orgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
  );
  await db.saveUser(sven);

  // 3. Seed Capacity
  final allSeededUsers = [admin, mateo, sandro, sven];
  for (final u in allSeededUsers) {
    final capacities = await db.getUserCapacities(u.email);
    final hasStandard = capacities.any((c) => c.type == 'Standard');
    if (!hasStandard) {
      final defaultStandard = UserCapacityModel(
        id: 'standard_${u.email.trim().toLowerCase()}',
        userEmail: u.email.trim().toLowerCase(),
        type: 'Standard',
        monday: 8.0,
        tuesday: 8.0,
        wednesday: 8.0,
        thursday: 8.0,
        friday: 8.0,
        saturday: 0.0,
        sunday: 0.0,
      );
      await db.saveUserCapacity(defaultStandard);
    }
  }

  // 4. Seed Categories
  final categories = [
    CategoryModel(
      id: '4a4ef6e6-df06-444d-b9cf-795dc7455d31',
      name: 'Veeva',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 1,
    ),
    CategoryModel(
      id: '9c5fa00e-26a9-4672-97cf-69bd59bb9304',
      name: 'Docusign',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 2,
    ),
    CategoryModel(
      id: '08a1faef-75a7-4e76-8f24-63bd59e13028',
      name: 'TrackWise',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 3,
    ),
    CategoryModel(
      id: 'ae6c4643-7a3c-4467-93e1-0fa138e6f1f5',
      name: 'MES',
      ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 1,
    ),
    CategoryModel(
      id: 'be6c4643-7a3c-4467-93e1-0fa138e6f1f6',
      name: 'LIMS',
      ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 2,
    ),
  ];
  for (final cat in categories) {
    await db.saveCategory(cat);
  }

  // 5. Seed Activity Groups
  final groups = [
    ActivityGroupModel(
      id: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
      name: 'Außerbetrieblich',
      ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
      sharedOrgUnitIds: const [
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      appliedOrgUnitIds: const [
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      statusMap: const {
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active',
      },
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 1,
    ),
    ActivityGroupModel(
      id: 'a5f1a547-4927-4a7b-a010-3375c3db7383',
      name: 'Linientätigkeiten',
      ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
      sharedOrgUnitIds: const [
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      appliedOrgUnitIds: const [
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      statusMap: const {
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active',
      },
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 2,
    ),
    ActivityGroupModel(
      id: 'd8bf59cf-2b83-4a75-b463-b883015f5e55',
      name: 'Releasemanagement',
      ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
      sharedOrgUnitIds: const [
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      appliedOrgUnitIds: const [
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      statusMap: const {
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active',
      },
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 3,
    ),
    ActivityGroupModel(
      id: '1a329d72-9746-4cb4-9be1-081cb8d956f6',
      name: 'Projektportfolio',
      ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
      sharedOrgUnitIds: const [
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      appliedOrgUnitIds: const [
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      statusMap: const {
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active',
      },
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 4,
    ),
    ActivityGroupModel(
      id: '8d3e913a-a16f-4421-9876-0bfdc92b5120',
      name: 'Strategie',
      ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
      sharedOrgUnitIds: const [
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      appliedOrgUnitIds: const [
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      statusMap: const {
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active',
      },
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 5,
    ),
    ActivityGroupModel(
      id: '57bcde82-f703-4c91-b68e-9d24cbfa6001',
      name: 'Sonstiges',
      ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
      sharedOrgUnitIds: const [
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      appliedOrgUnitIds: const [
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      statusMap: const {
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active',
      },
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 6,
    ),
  ];
  for (final g in groups) {
    await db.saveActivityGroup(g);
  }

  // 6. Seed Activities
  final activities = [
    // Shared Außerbetrieblich activities
    ActivityModel(
      id: 'de6c4643-7a3c-4467-93e1-0fa138e6f1f4',
      name: 'Feiertage',
      activityGroupId: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
      type: 'Unlimited',
      ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
      sharedOrgUnitIds: const [
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      appliedOrgUnitIds: const [
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      statusMap: const {
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active',
      },
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 1,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: 'ca872589-9a74-4bfa-948f-622be8fa6002',
      name: 'Urlaub',
      activityGroupId: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
      type: 'Unlimited',
      ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
      sharedOrgUnitIds: const [
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      appliedOrgUnitIds: const [
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      statusMap: const {
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active',
      },
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 2,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '26c91e3e-48a5-48fa-89cf-72b9aef46003',
      name: 'Studium',
      activityGroupId: 'f81d4fae-7dec-11d0-a765-00a0c91e6bf6',
      type: 'Unlimited',
      ownerOrgUnitId: '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
      sharedOrgUnitIds: const [
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      appliedOrgUnitIds: const [
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      ],
      statusMap: const {
        '8e6c4643-7a3c-4467-93e1-0fa138e6f1f3': 'Active',
        'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active',
        'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active',
      },
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 3,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),

    // IT DQS Activities
    ActivityModel(
      id: '48fe912a-00cd-44b2-b0cf-53e9aef86004',
      name: 'Linientätigkeit 1',
      activityGroupId: 'a5f1a547-4927-4a7b-a010-3375c3db7383',
      type: 'Unlimited',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 1,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '82fae1ab-590f-48fa-a10c-12bc9aef7005',
      name: 'Linientätigkeit 2',
      activityGroupId: 'a5f1a547-4927-4a7b-a010-3375c3db7383',
      categoryId: '4a4ef6e6-df06-444d-b9cf-795dc7455d31',
      type: 'Unlimited',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 2,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '9aefc30d-2b72-46fa-b1cf-7cf9aef46006',
      name: 'Releasemanagement 1',
      activityGroupId: 'd8bf59cf-2b83-4a75-b463-b883015f5e55',
      categoryId: '4a4ef6e6-df06-444d-b9cf-795dc7455d31',
      type: 'Unlimited',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 1,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '08fa9df3-10ba-48fa-89df-1cf9bcf46007',
      name: 'Releasemanagement 2',
      activityGroupId: 'd8bf59cf-2b83-4a75-b463-b883015f5e55',
      categoryId: '9c5fa00e-26a9-4672-97cf-69bd59bb9304',
      type: 'Unlimited',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 2,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: 'b87fcf9d-3c22-48df-b9cf-1dfbcef63008',
      name: 'Projekt 1',
      activityGroupId: '1a329d72-9746-4cb4-9be1-081cb8d956f6',
      categoryId: '4a4ef6e6-df06-444d-b9cf-795dc7455d31',
      type: 'Unlimited',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 1,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '9ac8fe1d-3b7c-4cfa-9bf3-5cfaeb63c009',
      name: 'Projekt 2',
      activityGroupId: '1a329d72-9746-4cb4-9be1-081cb8d956f6',
      categoryId: '08a1faef-75a7-4e76-8f24-63bd59e13028',
      type: 'Unlimited',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 2,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: 'c87fade3-4c22-4df3-a1bf-5cfa9be63010',
      name: 'Innitiative 1',
      activityGroupId: '8d3e913a-a16f-4421-9876-0bfdc92b5120',
      type: 'Unlimited',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 3,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '4c7faeb2-df08-4cfb-b9f1-6cf9be63c011',
      name: 'Innitiative 2',
      activityGroupId: '8d3e913a-a16f-4421-9876-0bfdc92b5120',
      type: 'Unlimited',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 4,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '8cfabed2-2c89-4cf3-a0bf-7cf9ae76c012',
      name: 'Sonstiges 1',
      activityGroupId: '57bcde82-f703-4c91-b68e-9d24cbfa6001',
      type: 'Unlimited',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 1,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: 'cfabed34-4c89-4cf3-b0bf-8cf9ae76c013',
      name: 'Sonstiges 2',
      activityGroupId: '57bcde82-f703-4c91-b68e-9d24cbfa6001',
      type: 'Unlimited',
      ownerOrgUnitId: 'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'e6f4772b-8a1a-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 2,
      assignedUserEmails: const [
        'malikjannico.press@vetter-pharma.com',
        'mateo.kevric@vetter-pharma.com',
      ],
    ),

    // IT MLS Activities
    ActivityModel(
      id: '7e6c4643-7a3c-4467-93e1-0fa138e6f1f7',
      name: 'Linientätigkeit 1',
      activityGroupId: 'a5f1a547-4927-4a7b-a010-3375c3db7383',
      type: 'Unlimited',
      ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 1,
      assignedUserEmails: const [
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '7e6c4643-7a3c-4467-93e1-0fa138e6f1f8',
      name: 'Linientätigkeit 2',
      activityGroupId: 'a5f1a547-4927-4a7b-a010-3375c3db7383',
      categoryId: 'ae6c4643-7a3c-4467-93e1-0fa138e6f1f5',
      type: 'Unlimited',
      ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 2,
      assignedUserEmails: const [
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '7e6c4643-7a3c-4467-93e1-0fa138e6f1f9',
      name: 'Releasemanagement 1',
      activityGroupId: 'd8bf59cf-2b83-4a75-b463-b883015f5e55',
      categoryId: 'ae6c4643-7a3c-4467-93e1-0fa138e6f1f5',
      type: 'Unlimited',
      ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 1,
      assignedUserEmails: const [
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '7e6c4643-7a3c-4467-93e1-0fa138e6f1fa',
      name: 'Releasemanagement 2',
      activityGroupId: 'd8bf59cf-2b83-4a75-b463-b883015f5e55',
      categoryId: 'be6c4643-7a3c-4467-93e1-0fa138e6f1f6',
      type: 'Unlimited',
      ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 2,
      assignedUserEmails: const [
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '7e6c4643-7a3c-4467-93e1-0fa138e6f1fb',
      name: 'Projekt 1',
      activityGroupId: '1a329d72-9746-4cb4-9be1-081cb8d956f6',
      categoryId: 'ae6c4643-7a3c-4467-93e1-0fa138e6f1f5',
      type: 'Unlimited',
      ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 1,
      assignedUserEmails: const [
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '7e6c4643-7a3c-4467-93e1-0fa138e6f1fc',
      name: 'Projekt 2',
      activityGroupId: '1a329d72-9746-4cb4-9be1-081cb8d956f6',
      categoryId: 'be6c4643-7a3c-4467-93e1-0fa138e6f1f6',
      type: 'Unlimited',
      ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 2,
      assignedUserEmails: const [
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '7e6c4643-7a3c-4467-93e1-0fa138e6f1fd',
      name: 'Innitiative 1',
      activityGroupId: '8d3e913a-a16f-4421-9876-0bfdc92b5120',
      type: 'Unlimited',
      ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 3,
      assignedUserEmails: const [
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '7e6c4643-7a3c-4467-93e1-0fa138e6f1fe',
      name: 'Innitiative 2',
      activityGroupId: '8d3e913a-a16f-4421-9876-0bfdc92b5120',
      type: 'Unlimited',
      ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 4,
      assignedUserEmails: const [
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '7e6c4643-7a3c-4467-93e1-0fa138e6f1ff',
      name: 'Sonstiges 1',
      activityGroupId: '57bcde82-f703-4c91-b68e-9d24cbfa6001',
      type: 'Unlimited',
      ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 1,
      assignedUserEmails: const [
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),
    ActivityModel(
      id: '7e6c4643-7a3c-4467-93e1-0fa138e6f100',
      name: 'Sonstiges 2',
      activityGroupId: '57bcde82-f703-4c91-b68e-9d24cbfa6001',
      type: 'Unlimited',
      ownerOrgUnitId: 'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d',
      sharedOrgUnitIds: const [],
      appliedOrgUnitIds: const ['c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d'],
      statusMap: const {'c8c88f6f-2b72-4d7a-b50a-9d7a188f6f7d': 'Active'},
      createdBy: 'system',
      createdAt: DateTime.now(),
      lastModifiedBy: 'system',
      lastModifiedAt: DateTime.now(),
      order: 2,
      assignedUserEmails: const [
        'sandro.perez.veiga@vetter-pharma.com',
        'sven.reisenhauer@vetter-pharma.com',
      ],
    ),
  ];
  for (final act in activities) {
    await db.saveActivity(act);
  }
}
