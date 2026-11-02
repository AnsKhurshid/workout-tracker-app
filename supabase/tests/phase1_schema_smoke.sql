-- Phase 1 smoke test for the draft schema. Run on a scratch database:
--   psql -d scratch -v ON_ERROR_STOP=1 -f supabase/tests/local_auth_stub.sql \
--        -f supabase/migrations/20261102000100_core_schema.sql \
--        -f supabase/migrations/20261102000200_row_level_security.sql \
--        -f supabase/migrations/20261102000300_seed_system_exercises.sql
--   psql -d scratch -f supabase/tests/phase1_schema_smoke.sql
-- Statements marked 'should fail' are expected to raise errors.
-- Expected: 58 visible system exercises; stale upsert ignored; user B sees 0 of A's rows;
-- after the plan delete the workout keeps its sets with plan_id cleared.
\set ON_ERROR_STOP 0
\set A '''aaaaaaaa-0000-0000-0000-000000000001'''
\set B '''bbbbbbbb-0000-0000-0000-000000000002'''
insert into auth.users values (:A, '{"display_name":"Alice"}'), (:B, '{}');
select id, display_name, weight_unit from profiles order by id;
set role authenticated;
select set_config('request.jwt.claim.sub', 'aaaaaaaa-0000-0000-0000-000000000001', false);
select count(*) as visible_system_exercises from exercises;
-- A cannot modify system exercise (0 rows updated)
update exercises set name='Hacked' where owner_id is null; 
insert into exercises (id, owner_id, name, primary_muscle_group) values ('11111111-0000-0000-0000-000000000001', :A, 'My Curl', 'biceps');
insert into exercises (owner_id, name, primary_muscle_group) values (null, 'Fake system', 'chest'); -- should fail RLS
insert into workout_plans (id,user_id,name) values ('22222222-0000-0000-0000-000000000001', :A, 'Push Day');
insert into plan_exercises (id,user_id,plan_id,exercise_id,position) select '33333333-0000-0000-0000-000000000001', :A, '22222222-0000-0000-0000-000000000001', id, 0 from exercises where name='Barbell Bench Press';
insert into plan_exercise_sets (user_id,plan_exercise_id,position,target_reps,target_weight_kg) values (:A,'33333333-0000-0000-0000-000000000001',0,10,40),(:A,'33333333-0000-0000-0000-000000000001',1,10,45);
insert into workouts (id,user_id,plan_id,name,started_at,status,ended_at) values ('44444444-0000-0000-0000-000000000001', :A,'22222222-0000-0000-0000-000000000001','Push Day', now()-interval '1 hour','completed',now());
insert into workout_exercises (id,user_id,workout_id,exercise_id,plan_exercise_id,exercise_name_snapshot,uses_external_weight_snapshot,position) select '55555555-0000-0000-0000-000000000001', :A,'44444444-0000-0000-0000-000000000001', id,'33333333-0000-0000-0000-000000000001','Barbell Bench Press',true,0 from exercises where name='Barbell Bench Press';
insert into workout_sets (user_id,workout_exercise_id,position,weight_kg,reps,is_completed,completed_at) values (:A,'55555555-0000-0000-0000-000000000001',0,40,12,true,now());
insert into workout_sets (user_id,workout_exercise_id,position,weight_kg,reps,is_completed) values (:A,'55555555-0000-0000-0000-000000000001',1,40,12,true); -- should fail check
-- stale write is ignored
insert into workout_plans (id,user_id,name,updated_at) values ('22222222-0000-0000-0000-000000000001', :A, 'OLD NAME', now()-interval '1 day') on conflict (id) do update set name=excluded.name, updated_at=excluded.updated_at;
select name as plan_name_after_stale_upsert from workout_plans;
-- newer write wins
insert into workout_plans (id,user_id,name,updated_at) values ('22222222-0000-0000-0000-000000000001', :A, 'Push Day v2', now()+interval '1 second') on conflict (id) do update set name=excluded.name, updated_at=excluded.updated_at;
select name as plan_name_after_newer_upsert from workout_plans;
-- now B
select set_config('request.jwt.claim.sub', 'bbbbbbbb-0000-0000-0000-000000000002', false);
select (select count(*) from workouts) w, (select count(*) from workout_sets) s, (select count(*) from exercises where owner_id is not null) custom, (select count(*) from profiles) p;
-- B cannot attach a child to A's workout, even with own user_id (composite FK)
insert into workout_exercises (user_id,workout_id,exercise_id,exercise_name_snapshot,uses_external_weight_snapshot,position) select :B,'44444444-0000-0000-0000-000000000001',id,'x',true,0 from exercises where name='Deadlift'; -- should fail (composite FK)
-- B cannot use A's custom exercise
insert into workout_plans (id,user_id,name) values ('22222222-0000-0000-0000-000000000002', :B, 'B plan');
insert into plan_exercises (user_id,plan_id,exercise_id,position) values (:B,'22222222-0000-0000-0000-000000000002','11111111-0000-0000-0000-000000000001',0); -- should fail RLS
-- B cannot spoof user_id
insert into workout_plans (user_id,name) values (:A, 'spoof'); -- should fail RLS
reset role;
-- hard-deleting the plan keeps history, clears plan_id / plan_exercise_id
delete from workout_plans where id='22222222-0000-0000-0000-000000000001';
select plan_id, name, (select count(*) from workout_sets) sets, (select plan_exercise_id from workout_exercises where id='55555555-0000-0000-0000-000000000001') pe from workouts;
-- exercise referenced by history cannot be hard-deleted
delete from exercises where name='Barbell Bench Press'; -- should fail (FK restrict)
