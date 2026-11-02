-- Gym Tracker v1.0: seed system exercises.
--
-- System exercises have owner_id = NULL. They are readable by every authenticated
-- user and cannot be changed by ordinary users (see RLS migration).
--
-- IDs are deterministic (UUIDv5 of the lower-cased name in a fixed namespace,
-- 6f1c1d1e-2b1a-4c55-9a51-7a3f4f0c9d10) so that the same exercise always has the same ID in every
-- environment. Never change an existing ID: workout history references it.
-- To add exercises later, write a new migration; to retire one, set deleted_at.

insert into public.exercises
  (id, name, primary_muscle_group, secondary_muscle_groups, equipment, uses_external_weight)
values
  ('c8bee7ea-99c2-5dfc-99a5-845ff24957cd', 'Barbell Bench Press', 'chest', '{triceps,shoulders}', 'barbell', true),
  ('c7350ae4-5c08-5490-a54d-9eda9e7a839e', 'Incline Barbell Bench Press', 'chest', '{shoulders,triceps}', 'barbell', true),
  ('7cfd945e-d8af-5bd5-8e65-72c30f4d16a8', 'Dumbbell Bench Press', 'chest', '{triceps,shoulders}', 'dumbbell', true),
  ('41443a4d-4a2a-5f7e-aada-9a61e8008265', 'Incline Dumbbell Press', 'chest', '{shoulders,triceps}', 'dumbbell', true),
  ('47afbffd-f487-5b63-a09e-391b662efadb', 'Dumbbell Fly', 'chest', '{}', 'dumbbell', true),
  ('002b0fd6-0118-5cf4-ad94-87fb4da5d301', 'Cable Crossover', 'chest', '{shoulders}', 'cable', true),
  ('5fd8a04a-a881-5370-89f7-fe8b88945ec6', 'Machine Chest Press', 'chest', '{triceps}', 'machine', true),
  ('2d5eeb8f-0ace-5a53-9c27-e2c2b7e6265a', 'Push-Up', 'chest', '{triceps,shoulders,core}', 'bodyweight', false),
  ('a53e478b-62f8-5b46-acca-7c06a8e00d67', 'Chest Dip', 'chest', '{triceps,shoulders}', 'bodyweight', false),
  ('a29adf6b-78b9-57fa-ad59-8c205c58d812', 'Deadlift', 'back', '{legs,core}', 'barbell', true),
  ('a3b67c17-7c88-5a7e-8851-35357ab773ba', 'Pull-Up', 'back', '{biceps}', 'bodyweight', false),
  ('f5c14b67-0faf-5058-9c49-26d4b502bde7', 'Chin-Up', 'back', '{biceps}', 'bodyweight', false),
  ('c8472bf4-4167-58b1-9398-a3aee77d6738', 'Lat Pulldown', 'back', '{biceps}', 'cable', true),
  ('9a4a2cdb-54ab-51c3-8665-7e815549ad4b', 'Barbell Row', 'back', '{biceps}', 'barbell', true),
  ('576e4310-1942-5887-9dcb-9ecfd7b03d99', 'Dumbbell Row', 'back', '{biceps}', 'dumbbell', true),
  ('f82f69e3-015f-5291-8f61-c9986a5ba1fa', 'Seated Cable Row', 'back', '{biceps}', 'cable', true),
  ('2cab2092-7099-5e14-bb05-9d73490db346', 'T-Bar Row', 'back', '{biceps}', 'barbell', true),
  ('31d17691-f703-5c09-b404-41e4628a4820', 'Back Extension', 'back', '{legs}', 'bodyweight', false),
  ('ede1d27c-4ad6-5564-9cea-3b1218f72dba', 'Overhead Press', 'shoulders', '{triceps}', 'barbell', true),
  ('916f5ae5-66ac-57be-859d-be27b2e8ad2b', 'Seated Dumbbell Shoulder Press', 'shoulders', '{triceps}', 'dumbbell', true),
  ('302c5900-f9f4-5fd9-b092-d1a9dbd0f7e6', 'Dumbbell Lateral Raise', 'shoulders', '{}', 'dumbbell', true),
  ('a62ded68-145f-52ed-9560-048e8da279bd', 'Cable Lateral Raise', 'shoulders', '{}', 'cable', true),
  ('39eedb1f-5f2a-5f1b-a939-e7ff4204b67c', 'Dumbbell Front Raise', 'shoulders', '{}', 'dumbbell', true),
  ('39bb815e-6f64-518d-a1f7-64c85555d462', 'Reverse Pec Deck', 'shoulders', '{back}', 'machine', true),
  ('f6047057-eecb-5be4-8aa9-23f5809449b9', 'Face Pull', 'shoulders', '{back}', 'cable', true),
  ('c7f8e9a9-46e4-54e3-bae8-3483a4a297c6', 'Barbell Shrug', 'back', '{}', 'barbell', true),
  ('65d3a8d3-c1e4-5162-9d6d-ba039d0596d7', 'Barbell Curl', 'biceps', '{}', 'barbell', true),
  ('4e379454-f56f-5c29-943e-5935e24f300a', 'Dumbbell Curl', 'biceps', '{}', 'dumbbell', true),
  ('ebd34f64-da5a-5136-ac7b-3871db0b28b1', 'Hammer Curl', 'biceps', '{}', 'dumbbell', true),
  ('d7f5d9aa-9295-516e-a3b2-b4f997deec96', 'Preacher Curl', 'biceps', '{}', 'barbell', true),
  ('847439ce-af3e-54dc-ace1-df69d2dd37f0', 'Cable Curl', 'biceps', '{}', 'cable', true),
  ('d5a3b008-803d-5531-b687-9acda0b06572', 'Triceps Pushdown', 'triceps', '{}', 'cable', true),
  ('ca60792d-78d0-5b8b-9dc5-ff7c001b38ee', 'Overhead Triceps Extension', 'triceps', '{}', 'cable', true),
  ('ebbde210-78b7-525b-b8dc-3734d1749087', 'Skull Crusher', 'triceps', '{}', 'barbell', true),
  ('d2581136-3221-5f4e-8d0a-8dfbede16c32', 'Close-Grip Bench Press', 'triceps', '{chest,shoulders}', 'barbell', true),
  ('6172cc7c-0548-5704-a431-33c41b17d1e2', 'Bench Dip', 'triceps', '{chest}', 'bodyweight', false),
  ('80bde4bd-dc08-5b47-9f99-5cffeffb7523', 'Back Squat', 'legs', '{core}', 'barbell', true),
  ('1a0cb998-03c7-5951-b0b2-9be4dfb7c4db', 'Front Squat', 'legs', '{core}', 'barbell', true),
  ('9ca8bab3-3944-5236-8376-c64fe86f46d0', 'Leg Press', 'legs', '{}', 'machine', true),
  ('b076ef29-fdb4-5b8c-9819-69efb47b1976', 'Romanian Deadlift', 'legs', '{back}', 'barbell', true),
  ('56338e0e-c9a2-5d2a-a3e2-51bda509c0a0', 'Walking Lunge', 'legs', '{}', 'dumbbell', true),
  ('511f4560-f71f-5d9b-bbe4-28fdb3b4a190', 'Bulgarian Split Squat', 'legs', '{}', 'dumbbell', true),
  ('f5364502-633b-59fe-9828-ff0968e6b30f', 'Leg Extension', 'legs', '{}', 'machine', true),
  ('f93c98dc-d2fa-569d-8ff7-a2f2cdc39411', 'Lying Leg Curl', 'legs', '{}', 'machine', true),
  ('75aa111e-a9e5-5b85-8fbd-6786833dd6d1', 'Hip Thrust', 'legs', '{}', 'barbell', true),
  ('4a2fe152-4997-5238-85ad-d1bd27457c33', 'Standing Calf Raise', 'legs', '{}', 'machine', true),
  ('0c35eb8b-cbdf-5c1a-8e51-005ee97165f9', 'Goblet Squat', 'legs', '{core}', 'kettlebell', true),
  ('adf9b811-89e8-5cba-97f2-bca95b887fd4', 'Plank', 'core', '{shoulders}', 'bodyweight', false),
  ('4b19c24c-dfed-52e7-80b7-ca74ae1beffd', 'Crunch', 'core', '{}', 'bodyweight', false),
  ('0434944d-943f-5b27-b2c4-87c5ba7ad637', 'Hanging Leg Raise', 'core', '{}', 'bodyweight', false),
  ('1923be20-19fc-5d2b-920f-cbf640413e78', 'Cable Crunch', 'core', '{}', 'cable', true),
  ('192b6b1e-c7e6-5a33-9e27-fc16bce81f77', 'Russian Twist', 'core', '{}', 'bodyweight', false),
  ('ef4ab2ba-3b42-5826-9440-53a4b41807fa', 'Ab Wheel Rollout', 'core', '{shoulders}', 'other', false),
  ('8988cbfb-e667-560f-ba6a-1135a62caca2', 'Treadmill Run', 'cardio', '{legs}', 'machine', false),
  ('ee4cd478-2226-5169-80b7-1cf819f95c6d', 'Stationary Bike', 'cardio', '{legs}', 'machine', false),
  ('9958fcf0-62e7-553b-b166-a3fcd4968fef', 'Rowing Machine', 'cardio', '{back,legs}', 'machine', false),
  ('746540c8-3912-5111-bba6-0f582dfa0612', 'Jump Rope', 'cardio', '{legs}', 'other', false),
  ('7c104e88-d5b8-58e5-bbf4-a6f9f53123ef', 'Farmer''s Carry', 'other', '{back,core}', 'dumbbell', true)
on conflict (id) do nothing;
