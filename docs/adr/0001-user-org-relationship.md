# 1. Single Source of Truth for User-Organization Unit Membership

To ensure database consistency and simplify update operations, user membership in an organization unit is stored solely via the `orgUnitId` attribute on the `UserModel` document, rather than maintaining a duplicated `userIds` list inside the `OrgUnitModel`.

## Context

Organization units (such as teams, groups, and departments) contain employees. We considered storing the relationship bidirectionally (e.g. keeping a list of member IDs on the organization unit document) to allow fast lookups from the organization side. However, this introduces synchronization risk: any update to a user's unit would require a multi-document transaction to update both the user and the old/new organization units. Under high concurrency or network disruptions, these references could easily fall out of sync.

## Decision

We decided to make `UserModel.orgUnitId` the single source of truth for membership. 

To resolve the list of employees belonging to a specific organization unit, the application fetches the set of users and filters them in memory or queries them by `orgUnitId`. 

## Consequences

- **Pros**: 
  - Eliminates data duplication and the risk of orphaned references.
  - User organization updates are atomic single-document writes.
- **Cons**:
  - Requires scanning users or executing queries on `orgUnitId` to list members, rather than reading a static list on the unit itself.
