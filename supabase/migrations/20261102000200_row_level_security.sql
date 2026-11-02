-- Gym Tracker v1.0: row level security.
--
-- Every table has RLS enabled. Policies apply to the `authenticated` role only,
-- so the anonymous key alone can read or write nothing.
--
-- auth.uid() is wrapped in a sub-select so Postgres evaluates it once per
-- statement instead of once per row (Supabase performance guidance).
--
-- Deletes from the app are soft deletes (an UPDATE of deleted_at), but DELETE
-- policies exist for owned rows so a future "purge tombstones" job or account
-- cleanup can run as the user.

alter table public.profiles           enable row level security;
alter table public.exercises          enable row level security;
alter table public.workout_plans      enable row level security;
alter table public.plan_exercises     enable row level security;
alter table public.plan_exercise_sets enable row level security;
alter table public.workouts           enable row level security;
alter table public.workout_exercises  enable row level security;
alter table public.workout_sets       enable row level security;

-- Visibility of an exercise to the current user: system or own custom.
-- security definer so the check works regardless of the caller's RLS context;
-- it only ever returns a boolean.
create or replace function public.exercise_is_visible(p_exercise_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.exercises e
    where e.id = p_exercise_id
      and (e.owner_id is null or e.owner_id = (select auth.uid()))
  );
$$;

revoke all on function public.exercise_is_visible(uuid) from public, anon;
grant execute on function public.exercise_is_visible(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create policy "profiles: read own" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy "profiles: insert own" on public.profiles
  for insert to authenticated
  with check (id = (select auth.uid()));

create policy "profiles: update own" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- No delete policy: profiles are removed only with the auth user (cascade).

-- ---------------------------------------------------------------------------
-- exercises
-- ---------------------------------------------------------------------------
-- System exercises (owner_id is null) are readable by every authenticated user
-- and writable by nobody through the API. Custom exercises are private.

create policy "exercises: read system and own" on public.exercises
  for select to authenticated
  using (owner_id is null or owner_id = (select auth.uid()));

create policy "exercises: insert own custom" on public.exercises
  for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy "exercises: update own custom" on public.exercises
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "exercises: delete own custom" on public.exercises
  for delete to authenticated
  using (owner_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- workout_plans, plan_exercise_sets, workouts, workout_sets: owner only
-- ---------------------------------------------------------------------------
-- Parent ownership for child rows is enforced by the composite foreign keys
-- (parent_id, user_id), so checking user_id here is sufficient.

create policy "workout_plans: owner all" on public.workout_plans
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "plan_exercise_sets: owner all" on public.plan_exercise_sets
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "workouts: owner all" on public.workouts
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "workout_sets: owner all" on public.workout_sets
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- plan_exercises, workout_exercises: owner only, and the referenced exercise
-- must be a system exercise or one of the user's own custom exercises.
-- ---------------------------------------------------------------------------

create policy "plan_exercises: owner all" on public.plan_exercises
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and public.exercise_is_visible(exercise_id)
  );

create policy "workout_exercises: owner all" on public.workout_exercises
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and public.exercise_is_visible(exercise_id)
  );
