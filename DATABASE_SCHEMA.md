# Gym Tracker v1.0 — Database Schema

Status: **Proposed (Phase 1)**. The SQL in `supabase/migrations/` is a working
draft: it has been applied to PostgreSQL 16 with a stubbed `auth` schema and the
RLS / constraint behaviour below was verified (see
`supabase/tests/phase1_schema_smoke.sql`). It has not yet been applied to a real
Supabase project.

| Migration | Contents |
|---|---|
| `20261102000100_core_schema.sql` | Enums, tables, constraints, indexes, `sync_guard` and `handle_new_user` triggers |
| `20261102000200_row_level_security.sql` | RLS enablement and policies |
| `20261102000300_seed_system_exercises.sql` | 58 system exercises with deterministic IDs |

Requires PostgreSQL 15+ (uses `ON DELETE SET NULL (column)`); Supabase projects
run 15 or 17.

---

## 1. Entity relationships

```
auth.users 1───1 profiles
     │
     ├──1───* exercises (custom; owner_id)        exercises (system; owner_id NULL)
     │                 │                                   │
     ├──1───* workout_plans                                │
     │            │ 1                                      │
     │            *                                        │
     │        plan_exercises *──────1 exercises ◀──────────┘
     │            │ 1
     │            *
     │        plan_exercise_sets
     │
     └──1───* workouts ·····(plan_id, nullable)····· workout_plans
                  │ 1
                  *
              workout_exercises *──────1 exercises
                  │ 1     · · · (plan_exercise_id, nullable) · · · plan_exercises
                  *
              workout_sets
```

Solid lines are ownership (cascade on hard delete). Dotted lines are
provenance links that are set to `NULL`, never cascaded, so deleting a plan can
never delete history.

The spec's required relationships:

| Requirement | Where |
|---|---|
| One user owns many plans | `workout_plans.user_id` |
| One plan contains many exercises | `plan_exercises.plan_id` |
| One exercise appears in many plans | `plan_exercises.exercise_id` (each placement is its own row with its own settings) |
| One user completes many workouts | `workouts.user_id` |
| One workout contains many exercises | `workout_exercises.workout_id` |
| One workout exercise contains many sets | `workout_sets.workout_exercise_id` |

---

## 2. Conventions applied to every table

| Column | Purpose |
|---|---|
| `id uuid` | Primary key, generated on the device (UUIDv7) so rows can be created offline. |
| `user_id uuid` | Owner (`owner_id` on `exercises`, where `NULL` means system). Present even on child tables so RLS is a simple equality and pulls are a simple filter. |
| `created_at timestamptz` | First creation (client clock). Immutable after insert (trigger). |
| `updated_at timestamptz` | Last change (client clock). The last-write-wins version. |
| `deleted_at timestamptz` | Soft-delete tombstone. Sticky once set on the server. |
| `server_updated_at timestamptz` | Stamped by the server on every accepted write. Clients pull by this cursor, so device clock skew never causes missed rows. |

**Composite foreign keys.** Every parent that has children declares
`unique (id, user_id)`, and each child references `(parent_id, user_id)`. A row
can therefore only point at a parent with the *same owner*, enforced by the
database itself, independent of RLS (business rules 2–4).

**The `sync_guard` trigger** (before insert/update on every table):

* stamps `server_updated_at`;
* clamps `updated_at` more than 5 minutes in the future to `now()`;
* turns an UPDATE with an older `updated_at` than the stored row into a no-op
  (stale offline edits cannot overwrite newer data — rule 7 and spec §8);
* keeps `created_at` immutable and `deleted_at` sticky.

---

## 3. Enumerated types

| Type | Values |
|---|---|
| `weight_unit` | `kg`, `lbs` |
| `muscle_group` | `chest`, `back`, `shoulders`, `biceps`, `triceps`, `legs`, `core`, `cardio`, `other` |
| `equipment_type` | `barbell`, `dumbbell`, `machine`, `cable`, `kettlebell`, `bodyweight`, `band`, `other` |
| `set_type` | `warmup`, `working` |
| `workout_status` | `in_progress`, `completed`, `abandoned` |

Enums can gain values in a later migration (`alter type ... add value`), which
is enough for v1 extensibility. Display labels are localised in the app, not
stored.

---

## 4. Tables

### 4.1 `profiles`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK → `auth.users(id)` cascade | Same as the auth user id. |
| `display_name` | text, 1–50 chars, nullable | From sign-up metadata; editable. |
| `weight_unit` | `weight_unit` default `kg` | Display preference only. |
| `default_rest_seconds` | int 0–3600, default 90 | Default for new plan exercises / quick-start exercises. |
| `auto_start_rest_timer` | bool default true | Start the timer when a set is completed. |
| sync columns | | |

Created by the `on_auth_user_created` trigger. Email is read from `auth.users`
via the session, not duplicated.

### 4.2 `exercises`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | System rows use deterministic UUIDv5 IDs. |
| `owner_id` | uuid → `auth.users` cascade, nullable | `NULL` = system exercise. |
| `name` | text 1–100 | Not unique (see decision D8). |
| `primary_muscle_group` | `muscle_group` | This is the exercise **category** used for filtering (open question 1). |
| `secondary_muscle_groups` | `muscle_group[]` default `{}` | Must not contain the primary. |
| `equipment` | `equipment_type`, nullable | |
| `description` | text ≤ 2000, nullable | |
| `uses_external_weight` | bool default true | False for push-ups, planks, cardio… |
| `is_custom` | bool, generated `owner_id is not null` | Read-only. |
| sync columns | | |

Index: `(owner_id, server_updated_at)`.

### 4.3 `workout_plans`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid → `auth.users` cascade | |
| `name` | text 1–100 | |
| `description` | text ≤ 2000, nullable | |
| `is_active` | bool default true | Inactive plans are hidden from quick start but kept. |
| sync columns | | `created_at` / `updated_at` are the spec's creation / last-updated dates. |

Unique `(id, user_id)` for child FKs. Index `(user_id, server_updated_at)`.

### 4.4 `plan_exercises`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid | |
| `plan_id` | uuid, FK `(plan_id, user_id)` → `workout_plans` cascade | |
| `exercise_id` | uuid → `exercises` **restrict** | Must be system or own custom (RLS). |
| `position` | int ≥ 0 | Order within the plan. |
| `rest_seconds` | int 0–3600, default 90 | Rest duration for this exercise in this plan. |
| `notes` | text ≤ 2000, nullable | Exercise-specific instructions for this plan. |
| sync columns | | |

Indexes: `(plan_id, position)`, `(exercise_id)`, `(user_id, server_updated_at)`.

### 4.5 `plan_exercise_sets`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid | |
| `plan_exercise_id` | uuid, FK `(plan_exercise_id, user_id)` → `plan_exercises` cascade | |
| `position` | int ≥ 0 | |
| `set_type` | `set_type` default `working` | |
| `target_reps` | smallint 1–999, nullable | Default reps. |
| `target_weight_kg` | numeric(8,3) 0–2000, nullable | Optional default target weight. |
| sync columns | | |

"Default sets" = the number of rows. The plan editor offers a quick
"3 × 10 @ 40 kg" setter that generates the rows, plus per-set overrides.

### 4.6 `workouts`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid | |
| `plan_id` | uuid, nullable, FK `(plan_id, user_id)` → `workout_plans` **set null (plan_id)** | Provenance only. Null for quick-start workouts. |
| `name` | text 1–100 | Copied from the plan name at start; editable. Shown as "plan used" in history. |
| `status` | `workout_status` default `in_progress` | |
| `started_at` | timestamptz | |
| `ended_at` | timestamptz, nullable | Required iff status ≠ `in_progress`; ≥ `started_at`. |
| `notes` | text ≤ 2000, nullable | |
| sync columns | | |

Duration is `ended_at − started_at`, computed in the app (no stored duplicate).
Indexes: `(user_id, status, ended_at desc)` for history and previous
performance, `(plan_id)`, `(user_id, server_updated_at)`.

### 4.7 `workout_exercises`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid | |
| `workout_id` | uuid, FK `(workout_id, user_id)` → `workouts` cascade | |
| `exercise_id` | uuid → `exercises` **restrict** | Identity used for previous performance and progress. |
| `plan_exercise_id` | uuid, nullable, FK → `plan_exercises` **set null** | Provenance only. |
| `exercise_name_snapshot` | text | Name at the time of the workout. |
| `uses_external_weight_snapshot` | bool | Weight flag at the time of the workout. |
| `instructions_snapshot` | text, nullable | Plan notes at the time of the workout. |
| `rest_seconds` | int 0–3600 | Copied from plan / profile default; editable in session. |
| `position` | int ≥ 0 | Reorderable during the workout. |
| `is_skipped` | bool default false | |
| `notes` | text ≤ 2000, nullable | User's notes for this exercise in this session. |
| sync columns | | |

Indexes: `(workout_id, position)`, `(user_id, exercise_id)`, `(plan_exercise_id)`,
`(user_id, server_updated_at)`.

### 4.8 `workout_sets`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid | |
| `workout_exercise_id` | uuid, FK `(workout_exercise_id, user_id)` → `workout_exercises` cascade | |
| `position` | int ≥ 0 | The displayed set number is derived (warm-ups shown as "W", working sets numbered 1..n). |
| `set_type` | `set_type` default `working` | |
| `target_reps`, `target_weight_kg` | nullable | Copied from the plan template. |
| `weight_kg` | numeric(8,3) 0–2000, nullable | What was lifted; null for bodyweight. Decimal weights supported. |
| `reps` | smallint 0–999, nullable | |
| `is_completed` | bool default false | |
| `completed_at` | timestamptz, nullable | Required iff completed. |
| `notes` | text ≤ 500, nullable | |
| sync columns | | |

Constraints: a completed set must have a timestamp and reps.
Indexes: `(workout_exercise_id, position)`, `(user_id, server_updated_at)`.

---

## 5. Row level security

RLS is enabled on every table; all policies target the `authenticated` role.

| Table | SELECT | INSERT / UPDATE | DELETE |
|---|---|---|---|
| `profiles` | own row | own row | none (cascade from auth) |
| `exercises` | system rows **or** own | own custom only (`owner_id = auth.uid()`) | own custom only |
| `workout_plans`, `plan_exercise_sets`, `workouts`, `workout_sets` | own | own | own |
| `plan_exercises`, `workout_exercises` | own | own **and** referenced exercise is system or own custom | own |

System exercises therefore cannot be inserted, edited or deleted through the
API by any user; they change only via migrations.

Verified on PostgreSQL 16 (stubbed auth):

* a user sees all 58 system exercises and none of another user's data;
* updating a system exercise affects 0 rows; inserting one fails RLS;
* a user cannot spoof `user_id`, cannot reference another user's custom
  exercise, and cannot attach a child row to another user's workout (composite
  FK rejects it);
* a stale upsert is ignored and a newer one applies;
* hard-deleting a plan leaves the workout and its sets intact with `plan_id`
  and `plan_exercise_id` cleared;
* an exercise referenced by history cannot be hard-deleted.

---

## 6. Business rules → mechanisms

| # | Rule | Enforced by |
|---|---|---|
| 1 | Plan edits never change completed workouts | Snapshot copy at start; sessions have no live reads from plan tables. |
| 2 | Every set belongs to the correct workout exercise | Composite FK `(workout_exercise_id, user_id)`. |
| 3 | Every workout belongs to the authenticated user | RLS `user_id = auth.uid()` on insert/update. |
| 4 | Every plan belongs to its owner | RLS + composite FKs for children. |
| 5 | Deleting a plan keeps history | Soft delete; hard delete only nulls `plan_id`/`plan_exercise_id`. |
| 6 | Deleting an exercise keeps history | Soft delete; FK `restrict` blocks hard delete while referenced; name snapshot. |
| 7 | No duplicates from sync | Client UUIDs + upsert on `id`. |
| 8 | Incomplete / interrupted sessions | `in_progress` and `abandoned` statuses; sets saved individually. |
| 9 | Not all exercises use weight | `uses_external_weight`, nullable `weight_kg`. |
| 10 | Unit change preserves history | Canonical kg storage. |

### Transactions

Multi-row operations are local SQLite transactions (the source of truth), each
including its outbox entries:

* start workout (workout + exercises + sets snapshot);
* duplicate plan (plan + exercises + set templates, all with new IDs);
* reorder (rewrite `position` of siblings);
* delete plan / workout / custom exercise (tombstone parent and children);
* complete workout.

On the server each row is an idempotent upsert pushed parents-first, so a
partially pushed batch is always consistent and simply resumes on retry.

---

## 7. Local SQLite schema (Drift)

Schema version 1 (Phase 2) contains `profiles` (mirror) plus the local-only
`app_settings`, `sync_outbox` and `sync_cursors`. Later phases add the other
seven mirrored tables as new schema versions, with the same column names as
Postgres. Snapshot: `drift_schemas/drift_schema_v1.json`.

| Difference | Reason |
|---|---|
| Enums stored as `TEXT` with Dart enum converters | SQLite has no enums. |
| Timestamps stored as ISO-8601 text (UTC) | Keeps milliseconds (Drift's integer mode stores whole seconds); sortable. |
| `weight_kg` as `REAL`, rounded to 3 dp on write via the `Weight` value object | SQLite has no decimal type. |
| `secondary_muscle_groups` as a JSON text array with a type converter | SQLite has no arrays. |
| `sync_outbox`, `sync_cursors`, `app_state` tables | Local-only sync and app state (see ARCHITECTURE §7.2). |
| No composite FK enforcement for remote-only invariants; local FKs on `id` with `PRAGMA foreign_keys = ON` | Same user on device; RLS-style rules are server concerns. |

Local schema versions are managed with Drift's `MigrationStrategy` and
`drift_dev` schema snapshots, tested with generated migration tests.

---

## 8. Future-proofing notes (not built in v1)

* **Supersets / circuits:** add a nullable `group_id` to `plan_exercises` and
  `workout_exercises`.
* **Other set kinds** (duration, distance for cardio): add nullable
  `duration_seconds` / `distance_m` columns and an exercise `tracking_type`.
* **Plan scheduling** ("today's workout"): a `plan_schedules` table.
* **Tombstone purge:** a scheduled job deleting tombstones older than N months
  once all devices have pulled them.
* **Account deletion:** an Edge Function using the service role to delete the
  auth user (cascades all data).
