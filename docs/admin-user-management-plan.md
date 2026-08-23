# Admin Module — User Account Management Plan

> Execution spec for:
>
> - **View User Accounts** page (search & filter)
> - **User Account Details** page (read-only)
> - **Edit User Account** page (validation, duplicate detection, audit logging)
>
> Status: **PLANNED — not yet executed.** Migrations were drafted, but
> **nothing has been applied to the database** and **no production code was
> changed**. Work through this document top-to-bottom.

---

## Table of Contents

1. [Requirements recap](#1-requirements-recap)
2. [Current state analysis](#2-current-state-analysis)
3. [Database plan](#3-database-plan)
4. [Migrations — what they do + how to verify](#4-migrations--what-they-do--how-to-verify)
5. [Model plan](#5-model-plan)
6. [Repository plan](#6-repository-plan)
7. [Controller plan](#7-controller-plan)
8. [View plan](#8-view-plan)
9. [Router plan](#9-router-plan)
10. [Test plan](#10-test-plan)
11. [Final verification checklist](#11-final-verification-checklist)
12. [Handoff notes](#12-handoff-notes)

---

## 1. Requirements recap

Under the **admin module**, deliver two features:

### A. View User Accounts

- Retrieve registered user accounts from the database
- Search and filter by **name, email, role, and status**
- Display **account summaries** and **current statuses**
- Implement **empty list**, **no-results**, and **retrieval error** handling

### B. User Account Management

- **User Account Details** page
- **Edit User Account** page
- Allow administrators to edit **permitted account details**
- **Validate input fields**
- **Detect duplicate email or phone numbers**
- **Log administrative update actions** (audit trail)

### Decisions taken with the product owner

| Question | Decision |
|---|---|
| Details vs Edit pages | **Split**: `/admin/users/:id` (read-only) + `/admin/users/:id/edit` (editable) |
| Editable fields | username, email, phone, profile title, community score, role, account status |
| Role filter UI | **Dropdown** (reuses `AdminFilterDropdown`) |

---

## 2. Current state analysis

### Project structure

Feature-first MVC (per `AGENTS.md` and `docs/coding-standards.md`). Riverpod
`StateNotifier` controllers, repository interface in `models/`, views in
`views/`. The admin module lives in `lib/features/admin/`.

### Existing user-management surfaces (already built)

| File | Role today |
|---|---|
| `models/admin_models.dart` | `AdminUser`, `AdminAccountStatus`, other admin models |
| `models/admin_repository.dart` | Interface; `loadUsers`, `loadUser`, `updateUser`, `setUserAccountStatus` |
| `models/supabase_admin_repository.dart` | Supabase impl. `updateUser` / `setUserAccountStatus` currently **throw `UnimplementedError`** |
| `models/fixture_admin_repository.dart` | In-memory impl, used when Supabase not configured |
| `controllers/user_management_controller.dart` | List state + search + status filter |
| `controllers/user_details_controller.dart` | Details state + save + toggle status |
| `views/user_management_screen.dart` | List page (search + status dropdown) |
| `views/user_details_screen.dart` | Combined details + edit form today |

### `AdminUser` model today

```dart
class AdminUser {
  final String id;
  final String username;
  final String email;
  final String profilePictureUrl;
  final String profileTitle;   // derived from community score tier
  final int communityScore;
  final AdminAccountStatus accountStatus;
}
```

### `users` table today (`001_initial_schema.sql`)

```sql
id UUID PK
username TEXT UNIQUE NOT NULL
email TEXT UNIQUE NOT NULL
avatar_url TEXT
country TEXT
favorite_food TEXT
community_score INTEGER DEFAULT 0
role TEXT DEFAULT 'user' CHECK (role IN ('user','admin'))
created_at TIMESTAMPTZ
updated_at TIMESTAMPTZ
```

### RLS / grants today

- `Public users are viewable by everyone.` — SELECT `using(true)`
- `Users can insert their own profile.` — INSERT with auth.uid() = id
- `Users can update own profile.` — UPDATE using(auth.uid() = id)
- `auth`, `authenticated` granted `SELECT` on `public.users`
  (`014_authenticated_select_grants.sql`)

### Gap analysis vs. the requirements

| Requirement | Gap |
|---|---|
| Search by name/email | Implemented; add **role** match |
| Filter by role | **Missing** → add role dropdown to list page and controller |
| Filter by status | Implemented (`active` / `deactivated`) — needs a real DB column |
| Account status persisted | **Missing** → add `is_active` column | 
| Phone number | **Missing** → add `phone_number` column + model field |
| Edit email & role | **Missing** → must write to `users.email` / `users.role` |
| Duplicate email/phone check | **Missing** → add repo methods + controller validation |
| Audit log | **Missing** → new `admin_audit_log` table + repo logging |
| Read-only details + separate edit page | **Missing** → split screens/routes |

---

## 3. Database plan

### 3.1 New columns on `public.users`

```sql
is_active     BOOLEAN DEFAULT true
phone_number  TEXT
```

- `is_active` drives the admin `accountStatus` (active / deactivated).
- Backfill: existing rows → `is_active = true`.

### 3.2 New table `public.admin_audit_log`

| Column | Type | Notes |
|---|---|---|
| `id` | bigint identity PK | |
| `admin_user_id` | uuid FK `auth.users` | NULL on delete |
| `admin_username` | text | denormalised for readability |
| `action` | text NOT NULL | e.g. `update_user`, `toggle_account_status` |
| `target_user_id` | uuid FK `public.users` | NULL on delete |
| `target_username` | text | denormalised |
| `field_changes` | jsonb | `{ "field": {"from":…, "to":…} }` |
| `created_at` | timestamptz | default now() |

### 3.3 RLS / grants

- `users`: new UPDATE policy for admins; no change to SELECT.
- Grant column-level `UPDATE` on `users` to `authenticated`.
- `admin_audit_log`: RLS enabled; INSERT + SELECT only for admins.
- Grant `INSERT, SELECT` on `admin_audit_log` to `authenticated`.

> Note: the audit log INSERT runs under the signed-in admin's JWT. The row
> is inserted by the repo *before* any update is applied when an action is
> performed, so the admin session is valid at write time.

---

## 4. Migrations — what they do + how to verify

Two migration files were **drafted** (ready but **not applied**):

1. `supabase/migrations/20260808000001_admin_user_columns.sql`
2. `supabase/migrations/20260808000002_admin_audit_log.sql`

### 4.1 Apply

Run **only** the CLI push; the app-side code changes come later:

```bash
supabase db push
```

Then verify with the queries below (Supabase SQL editor or `psql`).

### 4.2 Migration 1 — `admin_user_columns.sql`

**What it does**

- Adds `is_active BOOLEAN DEFAULT true`
- Adds `phone_number TEXT`
- Backfills `is_active = true` for existing rows
- Creates `Admins can update any user account` UPDATE policy
- Grants column-level `UPDATE` on `users` to `authenticated`

**Verify**

```sql
-- columns exist
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'users'
  AND column_name IN ('is_active', 'phone_number');

-- every row active after backfill
SELECT count(*) AS blank_is_active
FROM public.users WHERE is_active IS NULL;

-- RLS policy present
SELECT policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'users'
ORDER BY policyname;

-- grants present
SELECT privilege_type
FROM information_schema.role_column_grants
WHERE table_schema = 'public' AND table_name = 'users'
  AND column_name = 'is_active' AND grantee = 'authenticated';
```

### 4.3 Migration 2 — `admin_audit_log.sql`

**What it does**

- Creates `admin_audit_log` with indexes on `created_at`, `target_user_id`, `action`
- Enables RLS, admin-only INSERT + SELECT policies
- Grants `INSERT, SELECT` to `authenticated`

**Verify**

```sql
-- table + indexes exist
SELECT tablename FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'admin_audit_log';

SELECT indexname FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'admin_audit_log'
ORDER BY indexname;

-- RLS enabled + policies present
SELECT relrowsecurity FROM pg_class
WHERE relname = 'admin_audit_log';

SELECT policyname, cmd
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'admin_audit_log'
ORDER BY policyname;
```

### 4.4 Sanity check — admin role can edit a user

Sign in as `admin@makanspot.my` in the SQL editor (or via the app), then:

```sql
-- should be allowed (admin role) — flip back afterwards
UPDATE public.users
SET is_active = NOT is_active
WHERE email = 'fariz@makan.my';
```

---

## 5. Model plan

File: `lib/features/admin/models/admin_models.dart`

### 5.1 Add `AdminUserRole`

```dart
enum AdminUserRole { user, admin }

extension AdminUserRoleX on AdminUserRole {
  String get label => this == AdminUserRole.admin ? 'Admin' : 'User';
  String get value => this == AdminUserRole.admin ? 'admin' : 'user';
}
```

### 5.2 Extend `AdminUser`

Add fields:

```dart
final AdminUserRole role;
final String phone;
final DateTime? joinedAt;   // from created_at, optional
```

- `phone` is an empty string when unset (mirrors how other strings are stored).
- Extend `copyWith({ String? email, String? phone, AdminUserRole? role })`.
- `accountStatus` mapping: `is_active == true` → `active`; else `deactivated`.

Keep `profileTitle` as a stored/overridable string, but when loading from the DB
the tier derivation function in the repo stays as today.

---

## 6. Repository plan

### 6.1 Interface — `lib/features/admin/models/admin_repository.dart`

Extend `updateUser` and add three methods:

```dart
Future<AdminUser?> updateUser({
  required String id,
  required String username,
  required String email,
  required String phone,
  required AdminUserRole role,
  required String profileTitle,
  required int communityScore,
});

/// True when another user already holds email (exclude [excludeUserId]).
Future<bool> emailExists(String email, String excludeUserId);

/// True when another user already holds phone (exclude [excludeUserId]).
Future<bool> phoneExists(String phone, String excludeUserId);

/// Records an audit-trail entry for an administrative action.
Future<void> logAdminAction({
  required String adminUserId,
  required String adminUsername,
  required String action,
  required String targetUserId,
  required String targetUsername,
  Map<String, Map<String, Object?>>? fieldChanges,
});
```

`setUserAccountStatus(String id, AdminAccountStatus status)` stays as-is but is
now backed by the real `is_active` column.

### 6.2 Supabase repo — `supabase_admin_repository.dart`

**`_userFromRow`**: read and map

- `role` → `AdminUserRole` (`'admin'` vs default `user`)
- `phone_number` → `phone`
- `is_active` → `accountStatus`
- `created_at` → `joinedAt`

**`loadUsers`**: keep the query but also `.order('created_at')` empty-safe.
Client-side filtering for search/role/status stays in the controller (no server
round trips, consistent with existing patterns).

**`updateUser`**:

```dart
final updated = await _client
  .from('users')
  .update({username, email, phone_number, role: role.value,
           community_score, updated_at: now})
  .eq('id', id)
  .select();
if (updated.isEmpty) throw StateError('row not updated — permissions?');
return _userFromRow(updated.single);
```

> Email is `UNIQUE` in the DB — a real duplicate surfaces as a constraint
> error. The app checks `emailExists`/`phoneExists` first to give a friendly
> message; the constraint is a backstop, not the UX.

**`setUserAccountStatus`**:

```dart
final updated = await _client
  .from('users')
  .update({'is_active': status == AdminAccountStatus.active,
           'updated_at': now})
  .eq('id', id)
  .select();
if (updated.isEmpty) throw StateError(...);
return _userFromRow(updated.single);
```

**`emailExists` / `phoneExists`** — query with exclusion:

```dart
final rows = await _client
  .from('users')
  .select('id')
  .eq('email', email)          // or 'phone_number', phone
  .neq('id', excludeUserId);
return rows.isNotEmpty;
```

Edge case: if `excludeUserId` is the current editor (admin editing themselves)
and email/phone are unchanged, the query correctly returns `false` because the
only match is excluded.

**`logAdminAction`**:

```dart
await _client.from('admin_audit_log').insert({
  'admin_user_id': adminUserId,
  'admin_username': adminUsername,
  'action': action,
  'target_user_id': targetUserId,
  'target_username': targetUsername,
  'field_changes': fieldChanges ?? {},
});
```

**Who is the admin?** The controller reads
`Supabase.instance.client.auth.currentUser` (`id` + `email`) and passes it in.
Fall back to `admin@makanspot.my` / `admin` when no session exists (fixture mode).

### 6.3 Fixture repo — `fixture_admin_repository.dart`

- Expand seed users with `role`, `phone`, `is_active` (e.g. mix of admin/user,
  active/deactivated, a phone for some).
- Implement `updateUser` with new params.
- Implement `emailExists`/`phoneExists` by scanning the in-memory list.
- Implement `setUserAccountStatus` (already exists) and `logAdminAction`
  (append to an in-memory list, `@visibleForTesting` export optional).

---

## 7. Controller plan

### 7.1 `user_management_controller.dart`

Add role filter alongside status filter:

- `enum UserRoleFilter { all, user, admin }`
- Add `roleFilter` + `selectRoleFilter(UserRoleFilter)` to state/controller
- `_applyFilters`: search query also matches `role.label.toLowerCase()`; and
  `matchesRole = roleFilter == all || (roleFilter == user && role == user) || …`

Keep existing behaviour: `status == empty` when no results, `content` otherwise,
`error` state on failure, `loading` during load.

### 7.2 `user_details_controller.dart`

`save()` gains `email`, `phone`, `role`:

```dart
Future<String?> save({
  required String rawUsername,
  required String rawEmail,
  required String rawPhone,
  required String profileTitle,
  required AdminUserRole role,
  required String rawCommunityScore,
})
```

Validation order (each returns a user-facing message):

1. `username` non-empty → `'Username is required.'`
2. email format (simple regex) → `'Enter a valid email address.'`
3. phone format (optional, if non-empty) → `'Enter a valid phone number.'`
4. `_repository.emailExists(email, userId)` → `'This email is already in use.'`
5. `_repository.phoneExists(phone, userId)` (when phone non-empty)
   → `'This phone number is already in use.'`

Then `updateUser(...)`; on success call `logAdminAction` with the diff; on
failure keep `isSaving=false` and set `errorMessage`.

`toggleAccountStatus()` — after the status flips, also
`logAdminAction(action: 'toggle_account_status', fieldChanges: {is_active:…})`.

---

## 8. View plan

### 8.1 `user_management_screen.dart`

Current layout: search + status dropdown. Change to a row of **two dropdowns**:

- `AdminFilterDropdown<UserStatusFilter>` (status) — unchanged
- `AdminFilterDropdown<UserRoleFilter>` (role): `All roles` / `User` / `Admin`

Wire `onChanged: controller.selectRoleFilter`. Keep loading / empty / error /
content states as-is.

### 8.2 `user_details_screen.dart` → read-only **Details**

Rework the existing screen into a **read-only** details view:

- Header: `AdminBackButton('Back to Users')`
- Profile card: avatar, username, email, account-status badge
- Info rows: phone (or `Not provided`), role badge (`Admin`/`User`), profile
  title, community score, joined date
- Prominent `Edit` button → `context.go('/admin/users/${user.id}/edit')`
- Keep `loading` skeletis and `notFound` / `error` states

Remove the editable fields and save/toggle from this screen.

### 8.3 NEW `edit_user_screen.dart` → editable **Edit** page

- `AdminBackButton('Back to Details')` → `context.pop()`
- Form card with `AdminInputField`s:
  - Username, Email, Phone (optional), Profile Title, Community Score (number)
- `AdminSelectField<AdminUserRole>` for Role — options `User`/`Admin`
- Account status section: read-only badge + `Activate` / `Deactivate` outline
  button (reuses `showAdminConfirmDialog`)
- `AdminPrimaryButton('Save Changes')` with `isLoading` spinner
- Inline error text under fields when validation fails (or via SnackBar — pick
  one and be consistent). Prefer inline text for field errors.
- Seeds controllers from `state.user` once; `ConsumerStatefulWidget`.

### 8.4 Reuse

`AdminInputField`, `AdminSelectField`, `AdminPageHeader`, `AdminStatusBadge`,
`AdminUserAvatar`, `AdminEmptyState`, `AdminSkeletons`,
`AdminOutlineButton`, `AdminPrimaryButton` — all already exist.

---

## 9. Router plan

File: `lib/core/router/app_router.dart`

- `/admin/users/:id` → `UserDetailsScreen(userId: …)` (read-only)
- **NEW** `/admin/users/:id/edit` → `EditUserScreen(userId: …)`

Add constant: `static const adminEditUser = '/admin/users';` (edit route is
path + `/edit`, keep explicit string in the `GoRoute`).

`user_management_screen` card tap still goes to `/admin/users/:id`.

---

## 10. Test plan

Two checkpoints:

### 10.1 Unit — controllers

`test/features/admin/controllers/user_management_controller_test.dart`

- loading → content transition
- search filters by username / email / role label
- role filter (`all`/`user`/`admin`)
- status filter (`all`/`active`/`deactivated`)
- combined filters
- empty (no matches) → `empty`
- repo throws → `error`

`test/features/admin/controllers/user_details_controller_test.dart`

- load → content
- load missing → notFound
- load throws → error
- save: empty username → message
- save: bad email → message
- save: bad phone → message
- save: duplicate email → message
- save: duplicate phone → message
- save: valid → null, state updated, **audit log recorded**
- toggle status: active↔deactivated, audit log recorded

### 10.2 Widget — views

`test/features/admin/views/user_management_screen_test.dart`

- loading skeleton
- error + retry
- empty state
- content list renders status badge
- typing search filters
- role dropdown filters

`test/features/admin/views/user_details_screen_test.dart`

- loading skeleton
- content shows info + Edit button
- Edit navigates to `/admin/users/:id/edit`

`test/features/admin/views/edit_user_screen_test.dart`

- loading skeleton
- form seeded from user
- save happy path
- validation error shown
- role dropdown change respected
- status toggle confirmation dialog

Use fixture repository via provider overrides; deterministic, no network.

---

## 11. Final verification checklist

Before calling done:

- [ ] `supabase db push` applied both migrations (user performs this step)
- [ ] Migration verification SQL from §4 returns expected results
- [ ] `AdminUser` carries `role`, `phone`, real `accountStatus`, `joinedAt`
- [ ] List page filters by **name, email, role, status**
- [ ] Empty / no-results / error states render correctly
- [ ] Details page is read-only, has an Edit action
- [ ] Edit page edits all permitted fields
- [ ] Duplicate email + phone prevented with friendly messages
- [ ] Every update + status toggle writes an `admin_audit_log` row
- [ ] `dart format --output=none --set-exit-if-changed lib test`
- [ ] `flutter analyze` clean
- [ ] `flutter test` green

---

## 12. Handoff notes

- **Do not run** `supabase db push` as part of this task — the owner applies
  it separately after review.
- Migration files are drafts under `supabase/migrations/` — review before
  applying (the doc says “never edit a migration after it’s applied”).
- The audit log insert occurs from the signed-in admin's session; fixture
  mode degrades gracefully (no session → admin@makanspot.my placeholder).
- Existing `adminDashboard` "Comments" & "Posts" stat cards point at
  `/admin/users` today; that's out of scope, leave unchanged.