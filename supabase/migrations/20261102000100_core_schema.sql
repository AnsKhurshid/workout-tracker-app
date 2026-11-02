-- Gym Tracker v1.0: core schema.
--
-- See DATABASE_SCHEMA.md for the reasoning behind every table and rule here.
--
-- Conventions
--   * Every primary key is a UUID generated on the client (UUIDv7) so that rows
--     can be created offline and pushed later without ID collisions. The server
--     default exists only for rows created server-side (profiles, seeds).
--   * Every synced table carries the same four bookkeeping columns:
--       created_at         when the row was first created (client clock)
--       updated_at         when the row was last changed (client clock); used for
--                          last-write-wins conflict resolution
--       deleted_at         tombstone; rows are soft-deleted so deletes can sync
--       server_updated_at  set by the server on every write; the pull cursor
--   * Every user-owned table carries user_id, and child tables use composite
--     foreign keys (parent_id, user_id) so a child can never point at a parent
--     owned by another user.
--   * Weights are stored canonically in kilograms (numeric(8,3)). The display
--     unit is a profile preference only, so changing it never rewrites history.

-- ---------------------------------------------------------------------------
-- Enumerated types
-- ---------------------------------------------------------------------------

create type public.weight_unit as enum ('kg', 'lbs');

-- The default exercise categories from the product spec. Used both as the
-- exercise "category" and as its primary/secondary muscle groups.
create type public.muscle_group as enum (
  'chest', 'back', 'shoulders', 'biceps', 'triceps', 'legs', 'core', 'cardio', 'other'
);

create type public.equipment_type as enum (
  'barbell', 'dumbbell', 'machine', 'cable', 'kettlebell', 'bodyweight', 'band', 'other'
);

create type public.set_type as enum ('warmup', 'working');

create type public.workout_status as enum ('in_progress', 'completed', 'abandoned');

-- ---------------------------------------------------------------------------
-- Sync guard trigger
-- ---------------------------------------------------------------------------
-- Applied to every synced table. It makes client upserts safe to retry and
-- prevents an older offline edit from overwriting a newer one:
--   * stamps server_updated_at (the pull cursor) on every accepted write;
--   * clamps client timestamps that are unreasonably far in the future;
--   * silently skips an UPDATE whose updated_at is older than the stored row
--     (last-write-wins by updated_at, the stale write becomes a no-op);
--   * keeps created_at immutable;
--   * keeps tombstones sticky, so a stale device cannot resurrect a deleted row.

create or replace function public.sync_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.updated_at > now() + interval '5 minutes' then
    new.updated_at := now();
  end if;

  if tg_op = 'UPDATE' then
    if new.updated_at < old.updated_at then
      return null;  -- stale write: keep the newer row already stored
    end if;
    new.created_at := old.created_at;
    if old.deleted_at is not null and new.deleted_at is null then
      new.deleted_at := old.deleted_at;
    end if;
  end if;

  new.server_updated_at := clock_timestamp();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles: one row per auth user
-- ---------------------------------------------------------------------------
-- Email is not duplicated here; it lives in auth.users and is read from the
-- session.

create table public.profiles (
  id                    uuid primary key references auth.users (id) on delete cascade,
  display_name          text check (display_name is null or char_length(btrim(display_name)) between 1 and 50),
  weight_unit           public.weight_unit not null default 'kg',
  default_rest_seconds  integer not null default 90 check (default_rest_seconds between 0 and 3600),
  auto_start_rest_timer boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz,
  server_updated_at     timestamptz not null default now()
);

create index profiles_server_updated_at_idx on public.profiles (server_updated_at);

-- Create the profile automatically when a user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    nullif(btrim(left(new.raw_user_meta_data ->> 'display_name', 50)), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- exercises: system library (owner_id is null) and user custom exercises
-- ---------------------------------------------------------------------------
-- Secondary muscle groups are a small, bounded enum array owned by the row.
-- It is not workout data, and an array keeps it to one synced row instead of
-- a join table with its own sync bookkeeping.
--
-- Names are deliberately NOT unique: two offline devices may both create
-- "Hip Thrust", and a unique constraint would make one push fail forever.
-- The app warns about duplicates instead.

create table public.exercises (
  id                      uuid primary key default gen_random_uuid(),
  owner_id                uuid references auth.users (id) on delete cascade,
  name                    text not null check (char_length(btrim(name)) between 1 and 100),
  primary_muscle_group    public.muscle_group not null,
  secondary_muscle_groups public.muscle_group[] not null default '{}',
  equipment               public.equipment_type,
  description             text check (description is null or char_length(description) <= 2000),
  uses_external_weight    boolean not null default true,
  is_custom               boolean generated always as (owner_id is not null) stored,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  deleted_at              timestamptz,
  server_updated_at       timestamptz not null default now(),
  constraint exercises_secondary_excludes_primary
    check (not (primary_muscle_group = any (secondary_muscle_groups)))
);

create index exercises_owner_sync_idx on public.exercises (owner_id, server_updated_at);

-- ---------------------------------------------------------------------------
-- workout_plans: user templates ("Push Day", "Legs Day", ...)
-- ---------------------------------------------------------------------------

create table public.workout_plans (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  name              text not null check (char_length(btrim(name)) between 1 and 100),
  description       text check (description is null or char_length(description) <= 2000),
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  server_updated_at timestamptz not null default now(),
  constraint workout_plans_id_user_key unique (id, user_id)
);

create index workout_plans_user_sync_idx on public.workout_plans (user_id, server_updated_at);

-- ---------------------------------------------------------------------------
-- plan_exercises: an exercise placed in a plan, with plan-specific settings
-- ---------------------------------------------------------------------------
-- Each placement is its own row, so the same exercise can appear in many
-- plans (or twice in one plan) with independent configuration.

create table public.plan_exercises (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  plan_id           uuid not null,
  exercise_id       uuid not null references public.exercises (id) on delete restrict,
  position          integer not null check (position >= 0),
  rest_seconds      integer not null default 90 check (rest_seconds between 0 and 3600),
  notes             text check (notes is null or char_length(notes) <= 2000),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  server_updated_at timestamptz not null default now(),
  constraint plan_exercises_id_user_key unique (id, user_id),
  constraint plan_exercises_plan_fk foreign key (plan_id, user_id)
    references public.workout_plans (id, user_id) on delete cascade
);

create index plan_exercises_plan_idx on public.plan_exercises (plan_id, position);
create index plan_exercises_exercise_idx on public.plan_exercises (exercise_id);
create index plan_exercises_user_sync_idx on public.plan_exercises (user_id, server_updated_at);

-- ---------------------------------------------------------------------------
-- plan_exercise_sets: the set template for a plan exercise
-- ---------------------------------------------------------------------------
-- "Default sets and reps" is the number of rows here; each row can carry its
-- own type, target reps and optional target weight (e.g. 1 warm-up + 3 working).

create table public.plan_exercise_sets (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  plan_exercise_id  uuid not null,
  position          integer not null check (position >= 0),
  set_type          public.set_type not null default 'working',
  target_reps       smallint check (target_reps is null or target_reps between 1 and 999),
  target_weight_kg  numeric(8, 3) check (target_weight_kg is null or target_weight_kg between 0 and 2000),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  server_updated_at timestamptz not null default now(),
  constraint plan_exercise_sets_parent_fk foreign key (plan_exercise_id, user_id)
    references public.plan_exercises (id, user_id) on delete cascade
);

create index plan_exercise_sets_parent_idx on public.plan_exercise_sets (plan_exercise_id, position);
create index plan_exercise_sets_user_sync_idx on public.plan_exercise_sets (user_id, server_updated_at);

-- ---------------------------------------------------------------------------
-- workouts: a workout session (in progress, completed or abandoned)
-- ---------------------------------------------------------------------------
-- plan_id records which plan the session started from. If that plan is ever
-- hard-deleted, only plan_id is cleared (PG15+ column list), the session and
-- its snapshot remain. name is copied from the plan at start.

create table public.workouts (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users (id) on delete cascade,
  plan_id           uuid,
  name              text not null check (char_length(btrim(name)) between 1 and 100),
  status            public.workout_status not null default 'in_progress',
  started_at        timestamptz not null,
  ended_at          timestamptz,
  notes             text check (notes is null or char_length(notes) <= 2000),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  deleted_at        timestamptz,
  server_updated_at timestamptz not null default now(),
  constraint workouts_id_user_key unique (id, user_id),
  constraint workouts_plan_fk foreign key (plan_id, user_id)
    references public.workout_plans (id, user_id) on delete set null (plan_id),
  constraint workouts_ended_matches_status
    check ((status = 'in_progress') = (ended_at is null)),
  constraint workouts_ended_after_started
    check (ended_at is null or ended_at >= started_at)
);

-- History lists and "previous performance" look up completed workouts by date.
create index workouts_user_history_idx on public.workouts (user_id, status, ended_at desc);
create index workouts_plan_idx on public.workouts (plan_id);
create index workouts_user_sync_idx on public.workouts (user_id, server_updated_at);

-- ---------------------------------------------------------------------------
-- workout_exercises: snapshot of an exercise inside a session
-- ---------------------------------------------------------------------------
-- The snapshot columns are copied at session start (or when an exercise is
-- added mid-workout) so later edits to plans or exercises never change history.

create table public.workout_exercises (
  id                            uuid primary key default gen_random_uuid(),
  user_id                       uuid not null references auth.users (id) on delete cascade,
  workout_id                    uuid not null,
  exercise_id                   uuid not null references public.exercises (id) on delete restrict,
  plan_exercise_id              uuid,
  exercise_name_snapshot        text not null check (char_length(btrim(exercise_name_snapshot)) between 1 and 100),
  uses_external_weight_snapshot boolean not null,
  instructions_snapshot         text check (instructions_snapshot is null or char_length(instructions_snapshot) <= 2000),
  rest_seconds                  integer not null default 90 check (rest_seconds between 0 and 3600),
  position                      integer not null check (position >= 0),
  is_skipped                    boolean not null default false,
  notes                         text check (notes is null or char_length(notes) <= 2000),
  created_at                    timestamptz not null default now(),
  updated_at                    timestamptz not null default now(),
  deleted_at                    timestamptz,
  server_updated_at             timestamptz not null default now(),
  constraint workout_exercises_id_user_key unique (id, user_id),
  constraint workout_exercises_workout_fk foreign key (workout_id, user_id)
    references public.workouts (id, user_id) on delete cascade,
  constraint workout_exercises_plan_exercise_fk foreign key (plan_exercise_id, user_id)
    references public.plan_exercises (id, user_id) on delete set null (plan_exercise_id)
);

create index workout_exercises_workout_idx on public.workout_exercises (workout_id, position);
-- Previous performance and progress charts: all sessions of one exercise.
create index workout_exercises_user_exercise_idx on public.workout_exercises (user_id, exercise_id);
create index workout_exercises_plan_exercise_idx on public.workout_exercises (plan_exercise_id);
create index workout_exercises_user_sync_idx on public.workout_exercises (user_id, server_updated_at);

-- ---------------------------------------------------------------------------
-- workout_sets: individual logged sets
-- ---------------------------------------------------------------------------
-- target_* are copied from the plan template; weight_kg/reps are what the user
-- actually did and may differ on every set. weight_kg is null for exercises
-- without external weight.

create table public.workout_sets (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references auth.users (id) on delete cascade,
  workout_exercise_id uuid not null,
  position            integer not null check (position >= 0),
  set_type            public.set_type not null default 'working',
  target_reps         smallint check (target_reps is null or target_reps between 1 and 999),
  target_weight_kg    numeric(8, 3) check (target_weight_kg is null or target_weight_kg between 0 and 2000),
  weight_kg           numeric(8, 3) check (weight_kg is null or weight_kg between 0 and 2000),
  reps                smallint check (reps is null or reps between 0 and 999),
  is_completed        boolean not null default false,
  completed_at        timestamptz,
  notes               text check (notes is null or char_length(notes) <= 500),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  server_updated_at   timestamptz not null default now(),
  constraint workout_sets_parent_fk foreign key (workout_exercise_id, user_id)
    references public.workout_exercises (id, user_id) on delete cascade,
  constraint workout_sets_completed_has_timestamp
    check (is_completed = (completed_at is not null)),
  constraint workout_sets_completed_has_reps
    check (not is_completed or reps is not null)
);

create index workout_sets_parent_idx on public.workout_sets (workout_exercise_id, position);
create index workout_sets_user_sync_idx on public.workout_sets (user_id, server_updated_at);

-- ---------------------------------------------------------------------------
-- Attach the sync guard to every synced table
-- ---------------------------------------------------------------------------

create trigger profiles_sync_guard before insert or update on public.profiles
  for each row execute function public.sync_guard();
create trigger exercises_sync_guard before insert or update on public.exercises
  for each row execute function public.sync_guard();
create trigger workout_plans_sync_guard before insert or update on public.workout_plans
  for each row execute function public.sync_guard();
create trigger plan_exercises_sync_guard before insert or update on public.plan_exercises
  for each row execute function public.sync_guard();
create trigger plan_exercise_sets_sync_guard before insert or update on public.plan_exercise_sets
  for each row execute function public.sync_guard();
create trigger workouts_sync_guard before insert or update on public.workouts
  for each row execute function public.sync_guard();
create trigger workout_exercises_sync_guard before insert or update on public.workout_exercises
  for each row execute function public.sync_guard();
create trigger workout_sets_sync_guard before insert or update on public.workout_sets
  for each row execute function public.sync_guard();
