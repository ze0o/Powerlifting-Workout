// Built-in exercise library. Lifters can add their own on top (stored in AppStore).
import 'models.dart';

const List<String> kCategories = [
  'Squat',
  'Bench',
  'Deadlift',
  'Upper back',
  'Shoulders',
  'Arms',
  'Legs',
  'Core',
  'Conditioning',
  'Other',
];

const List<ExerciseDef> kLibrary = [
  // Squat
  ExerciseDef('squat', 'Back squat', 'Squat', barbell: true, pctOf: 'squat', lift: 'squat'),
  ExerciseDef('psquat', 'Paused squat (2 sec in the hole)', 'Squat', barbell: true, pctOf: 'squat'),
  ExerciseDef('pinsquat', 'Pin squat', 'Squat', barbell: true, pctOf: 'squat'),
  ExerciseDef('tempo_squat', 'Tempo squat (3-1-0)', 'Squat', barbell: true, pctOf: 'squat'),
  ExerciseDef('front_squat', 'Front squat', 'Squat', barbell: true, pctOf: 'squat'),
  ExerciseDef('ssb_squat', 'Safety bar squat', 'Squat', barbell: true, pctOf: 'squat'),
  // Bench
  ExerciseDef('bench', 'Competition bench (paused)', 'Bench', barbell: true, pctOf: 'bench', lift: 'bench'),
  ExerciseDef('pbench', 'Paused bench (2-sec pause)', 'Bench', barbell: true, pctOf: 'bench'),
  ExerciseDef('spoto', 'Spoto press', 'Bench', barbell: true, pctOf: 'bench'),
  ExerciseDef('cgbench', 'Close-grip bench', 'Bench', barbell: true, pctOf: 'bench'),
  ExerciseDef('larsen', 'Larsen press', 'Bench', barbell: true, pctOf: 'bench'),
  ExerciseDef('incline', 'Incline dumbbell press', 'Bench'),
  ExerciseDef('dips', 'Weighted dips or close-grip bench', 'Bench'),
  // Deadlift
  ExerciseDef('deadlift', 'Deadlift', 'Deadlift', barbell: true, pctOf: 'deadlift', lift: 'deadlift'),
  ExerciseDef('deficit', 'Deficit deadlift (stand on 2–5 cm plate)', 'Deadlift', barbell: true, pctOf: 'deadlift'),
  ExerciseDef('pdeadlift', 'Paused deadlift (pause below the knee)', 'Deadlift', barbell: true, pctOf: 'deadlift'),
  ExerciseDef('blockpull', 'Block pull', 'Deadlift', barbell: true, pctOf: 'deadlift'),
  ExerciseDef('rdl', 'Romanian deadlift', 'Deadlift', barbell: true),
  // Upper back
  ExerciseDef('row', 'Barbell row', 'Upper back', barbell: true),
  ExerciseDef('pullup', 'Pull-ups or lat pulldown', 'Upper back'),
  ExerciseDef('cablerow', 'Seated cable row', 'Upper back'),
  ExerciseDef('dbrow', 'One-arm dumbbell row', 'Upper back'),
  ExerciseDef('facepull', 'Face pull', 'Upper back'),
  // Shoulders
  ExerciseDef('ohp', 'Overhead press', 'Shoulders', barbell: true),
  ExerciseDef('dbpress', 'Seated dumbbell shoulder press', 'Shoulders'),
  ExerciseDef('latraise', 'Lateral raise', 'Shoulders'),
  ExerciseDef('reardelt', 'Rear-delt fly', 'Shoulders'),
  // Arms
  ExerciseDef('pushdown', 'Triceps pushdown', 'Arms'),
  ExerciseDef('ohext', 'Overhead triceps extension', 'Arms'),
  ExerciseDef('curl', 'Biceps curl', 'Arms'),
  ExerciseDef('hammer', 'Hammer curl', 'Arms'),
  // Legs
  ExerciseDef('legpress', 'Leg press', 'Legs'),
  ExerciseDef('legext', 'Leg extension', 'Legs'),
  ExerciseDef('legcurl', 'Lying leg curl', 'Legs'),
  ExerciseDef('bss', 'Bulgarian split squat', 'Legs'),
  ExerciseDef('hipthrust', 'Hip thrust', 'Legs', barbell: true),
  ExerciseDef('calf', 'Standing calf raise', 'Legs'),
  // Core
  ExerciseDef('core', 'Plank or ab wheel', 'Core'),
  ExerciseDef('hlr', 'Hanging leg raise', 'Core'),
  ExerciseDef('backext', 'Back extension', 'Core'),
  ExerciseDef('core2', 'Core circuit', 'Core'),
  // Conditioning
  ExerciseDef('cond', 'Conditioning: sled, bike or incline walk', 'Conditioning'),
  ExerciseDef('circuit', 'Arms + upper back circuit (curl, pushdown, rear-delt fly)', 'Conditioning'),
];

ExerciseDef? builtInDef(String id) {
  for (final d in kLibrary) {
    if (d.id == id) return d;
  }
  return null;
}
