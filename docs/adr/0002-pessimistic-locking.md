# 2. Pessimistic Concurrency Locking for Planning Resources

To prevent "lost updates" and data overwrites when multiple planners edit capacities, demands, or allocations simultaneously, the system implements a database-level pessimistic locking mechanism with client heartbeats.

## Context

Capacity planning involves editing values across months and years. In a multi-user environment, two planners opening the same grid at the same time could overwrite each other's changes upon saving. While optimistic locking (version tracking) detects conflicts upon saving, it forces one user to discard all of their manual cell edits. Because planning inputs are high-effort, rejecting a save is a poor user experience.

## Decision

We implemented a pessimistic locking system using a separate `locks` collection in Firestore. 

- **Locks**: Before entering edit mode in the planning views, the client must acquire an exclusive lock:
  - **Activity View**: Locks a specific activity's demands in an organization unit for a calendar year.
  - **Employee View**: Locks all selected employees and the visible activity set for a calendar year.
- **Heartbeat & Expiry**: Locks are created with a 2-minute expiration time. The editing client runs a background heartbeat timer every 30 seconds to refresh the expiration to `now + 2 minutes`. If the client disconnects or closes the tab, the lock expires automatically and other users can edit.
- **Mutual Exclusion**: If a resource is locked, the UI disables edit controls and displays a lock badge with the owner's name.

## Consequences

- **Pros**:
  - Guarantees that a user entering edit mode will not have their changes overwritten or rejected.
  - Clear visual feedback in the UI showing who is currently editing a resource.
- **Cons**:
  - Introduces stateful heartbeat timers on the client.
  - Requires cleanups of expired locks in database queries.
