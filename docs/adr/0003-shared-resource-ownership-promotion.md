# 3. Ownership Promotion on Shared Resource Deletion

To prevent deleting shared activities, activity groups, and categories that are still in use by other teams, deleting a resource does not remove it from the database if other organization units have opted in (applied) to it; instead, ownership is promoted to the next opted-in unit.

## Context

Resources (categories, activity groups, and activities) are owned by the organization unit that created them. However, they can be shared with other units, which can then choose to "apply" (opt-in) to them for their own planning. If the owner of a resource decides to delete it, simply deleting the document would break the capacity plans and settings of all other units that had applied it.

## Decision

We implemented an ownership promotion lifecycle on resource deletion:
- When an owner requests deletion of a resource, the system checks the list of `appliedOrgUnitIds` (units that have applied the resource).
- If other units have applied it, the resource is **not** deleted. Instead, the `ownerOrgUnitId` is updated to the first ID in the `appliedOrgUnitIds` list, and the deleting unit is removed from both the applied list and the shared list.
- If no other units have applied the resource, it is permanently deleted from the database.

## Consequences

- **Pros**:
  - Prevents accidental loss of planning data for teams relying on shared resources.
  - Decentralizes management without requiring a global administrator to arbitrate deletion.
- **Cons**:
  - Resource ownership changes implicitly, which might surprise the unit inheriting ownership.
  - Resources can persist in the database even after the original creator has discarded them.
