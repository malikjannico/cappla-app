# Cappla

A web-based capacity planning and steering application designed for enterprise resource management, enabling hierarchical team structures, activity management, individual employee capacity definitions, demand planning, and allocation alignment.

## Language

**User**:
An authenticated user of the application, representing an employee of the organization, with assigned roles and organizational memberships.
_Avoid_: Account, profile, member

**Organization Unit (Org Unit)**:
A node within the hierarchical tree structure of the enterprise (ranging from Managing Director division to Team) that serves as the boundary for resource ownership and capacity planning.
_Avoid_: Department, division, branch

**Category**:
A global classification tag used to classify and group activities across multiple organization units.
_Avoid_: Tag, label, classification

**Activity Group**:
A structural container used to organize and group related activities.
_Avoid_: Folder, container

**Activity**:
A specific task or item of work, classified as either Unlimited (indefinite validity) or Limited (time-bound with precise start and end dates).
_Avoid_: Task, job, work item

**Capacity**:
The planned weekly working hours for a user, defined as either Standard (default baseline) or Specific (temporary time-bound overrides).
_Avoid_: Availability, working hours

**Demand**:
The monthly planned hours required by an organization unit to complete a specific activity.
_Avoid_: Target hours, required hours

**Allocation**:
The monthly planned hours that a specific employee dedicates to a given activity.
_Avoid_: Assigned hours, planned capacity, booking

**Lock**:
A pessimistic concurrency control mechanism that grants exclusive edit access to a planner for a specific activity or a selection of employees for a given year.
_Avoid_: Mutex, reservation, block
