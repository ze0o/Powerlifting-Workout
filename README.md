# Meet Prep Log v2.2

A powerlifting training log for Android, built with Flutter. It includes programs for beginner, intermediate and advanced lifters, plus a blank builder. Every workout can be edited. You log sets with RPE and referee lights, and the app tracks estimated maxes, your total with IPF GL points, and body composition.

## What's new in v2.2: accounts and cloud database

- **Account** (Athlete tab → Account): create an account with email and password, sign in, reset your password, sign out. Without an account the app works offline exactly as before.
- **Sync**: when you're signed in, everything uploads about 20 seconds after you stop editing, and again when you leave the app. On a new phone, sign in and choose **Use the cloud backup**.
- **Database for analysis**: each sync also writes clean rows (profiles, programs, workouts, sets, body entries) and analysis views that calculate e1RM, weekly progress and GL points on the server.
- **`analysis/progress_model.py`**: a starter script that reads all lifters' data and predicts each lifter's e1RM 4 weeks ahead.

### One-time setup for the cloud (do this before you build)

1. **Run the sync function.** In the Supabase dashboard, open the **meet-prep-log** project → **SQL Editor** → **New query**. Paste all of `supabase/migrations/0003_sync_snapshot.sql` and click **Run**. Files 0001 and 0002 are already applied.
2. **Allow internet in release builds.** In `android/app/src/main/AndroidManifest.xml`, add this line above `<application`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
3. **Email confirmation**: by default, Supabase emails a confirmation link before a new account can sign in. For testing you can turn that off under **Authentication → Sign In / Providers → Email → Confirm email**. Turn it back on before going public.
4. `flutter pub get` installs `supabase_flutter`.

### Database map

| Table / view | What's in it |
|---|---|
| `profiles` | One row per lifter: name, sex, division, class, height, maxes, goals, meet range, gym setup |
| `app_snapshots` | Latest full app JSON per lifter (used for restore) |
| `programs`, `workouts`, `sets`, `body_entries` | Clean rows rebuilt on every sync, for analysis |
| `v_sets` | Every set with date, e1RM and volume |
| `v_weekly_lift_progress` | Best e1RM, volume and sets per lifter, lift and week |
| `v_workout_summary` | One row per workout: duration, sets, volume, best e1RM per lift |
| `v_lifter_standing` | Best e1RM per lift, estimated total and GL points at latest bodyweight |
| `gl_points(total, bw, female, equipped)` | IPF GL formula in SQL |

Row level security means each signed-in lifter can only read and write their own rows. You, as the project owner, can read everyone's data from the dashboard or with `DATABASE_URL` (see the top of `analysis/progress_model.py`).

## What's new in v2.1

- **Rest timer**: starts when you tap a set's light, with −30 / +30 / Skip buttons and a vibration when rest is over. You can also start it from the timer icon on a workout.
- **Warm-up ramp** under the first set of each competition lift, with plates shown for every step.
- **Gym setup** (Athlete tab): bar weight, which plates your gym has, competition collars, and rest times. Plate loading warns you when your plates can't make the exact weight.
- **Personal records** (Progress tab): heaviest 1, 3 and 5 rep weights and best estimated max per lift, across every program.
- **Tools**: a plate calculator with warm-ups, and a GL points calculator for any total and bodyweight.
- **Welcome flow** on a fresh install: about you, maxes (with an estimator from a recent hard set), and a program.
- **CSV export** of every logged set and every body entry, ready for spreadsheets or pandas.

## What's new in v2

| Area | v1 | v2 |
|---|---|---|
| Program | One fixed 8-week plan | 4 templates: **Foundation** (Beginner, 8 wk), **Meet Prep** (Intermediate, 8 wk), **Peaking Block** (Advanced, 10 wk), **Build Your Own**. Old programs stay in your history. |
| Workouts | A day chip with exercises below it | One **card per workout** showing date, status (Planned / Live / Done / Not logged), main lifts, duration, sets, volume and bodyweight. Tap a card to open the workout. |
| Editing | None | Add, remove, reorder and edit exercises. Edit each set's kg or % of max, reps and RPE. Add a workout to any week, copy a workout or a whole week forward, rename, delete. |
| Exercises | Fixed list | 43 built-in exercises in 9 categories, plus your own (name, category, barbell, % of which max). |
| Dates | Fixed | Every workout has its own date and you can change it. Body entries and weigh-ins have their own dates too. |
| Duration | None | Start/Finish timer, or type the minutes in. |
| Logging | kg, reps, RPE | The same, plus a **referee light** per set: white = good lift, red = missed. Missed sets don't count toward estimated maxes. |
| Bodyweight | A list in Progress | A separate **Body** tab with weight, skeletal muscle, fat mass, body fat %, body water, visceral fat, BMR, InBody score and waist. Lean mass and BMI are calculated for you. Shows the change since the previous entry, a chart per metric, and your weight class status. Bodyweight typed in a workout is saved here too. |
| Progress | e1RM per lift | Estimated **total**, **IPF GL points** (classic or equipped, men or women), and start vs goal totals. |
| Profile | Maxes only | Name, sex, classic/equipped, IPF weight class, height, maxes, goals, meet weight range. |
| Look | Grey logbook | Competition style: navy scoreboard headers with a red stripe, referee lights, and plate colours per lift. Light and dark themes. |
| Data | Copy backup | Copy **and restore** backups. v1 data is migrated automatically on first launch. |

## Run it

The `lib/`, `test/` and `pubspec.yaml` files are the app. Flutter generates the Android project for you:

```bash
cd meet_prep_log
flutter create --platforms=android --project-name meet_prep_log --org com.abdulaziz .
flutter pub get
flutter analyze
flutter test
flutter run --release              # phone plugged in with USB debugging on
# or: flutter build apk --release  -> build/app/outputs/flutter-apk/app-release.apk
```

`flutter create .` only adds missing files. It won't overwrite `lib/`. If you're updating the v1 folder, delete the old `lib/` and `test/` first, then copy these in. `lib/plan.dart`, `lib/store.dart` and `lib/screens/` from v1 are replaced by `lib/core/` and `lib/ui/`.

To show "Meet Prep Log" under the icon, open `android/app/src/main/AndroidManifest.xml` and change `android:label="meet_prep_log"` to `android:label="Meet Prep Log"`.

Requires Flutter 3.22 or newer (Dart 3.4+).

## Code map

| File | What it does |
|---|---|
| `lib/core/calc.dart` | Formatting, dates, plate math, estimated 1RM (Epley with reps in reserve), IPF GL points, IPF weight classes |
| `lib/core/models.dart` | PlannedSet, LoggedSet, ExerciseSlot, Workout, Program, Profile, BodyEntry, CheckIn, all with JSON |
| `lib/core/library.dart` | Built-in exercise library |
| `lib/core/templates.dart` | The four program templates |
| `lib/core/store.dart` | App state, editing operations, analysis, check-in text, saving, backup/restore, v1 migration |
| `lib/core/cloud.dart` | Supabase sign-in, sync and restore |
| `supabase/migrations/` | Database schema, analysis views and the sync function |
| `analysis/progress_model.py` | Starter analysis and 4-week e1RM prediction |
| `lib/ui/theme.dart` | Palette (light/dark) and theme |
| `lib/ui/widgets.dart` | Header, lift tag, plate loading, referee light, stat tile, chart, dialogs |
| `lib/ui/screens/` | Program, Workout (with rest timer and warm-ups), Exercise editor, Progress, Body, Athlete, Program picker, Tools, Onboarding |
| `test/core_test.dart` | Tests for the maths, templates and JSON |

## How the data works

- A **program** is a list of **workouts**. Each workout has **exercise slots**, each with a **plan** (target sets) and a **log** (what you did).
- Loads are stored as a percentage of a competition max where that makes sense, so changing a max in the Athlete tab updates every target.
- An exercise slot keeps the same `id` across weeks. That's how "also add to / remove from later weeks" finds the matching workouts (same workout name, later week).
- Everything is one JSON blob in `shared_preferences` (`meet_prep_log_v2`). It's saved half a second after each change and immediately when the app goes to the background.
