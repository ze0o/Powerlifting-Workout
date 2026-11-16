# Meet Prep Log v2.7

A powerlifting training log for Android, built with Flutter. It includes programs for beginner, intermediate and advanced lifters, plus a blank builder. Every workout can be edited. You log sets with RPE and referee lights, and the app tracks estimated maxes, your total with IPF GL points, and body composition. Coaches can follow their athletes, comment on workouts and send programs.

## Setup checklist

Everything you need to do by hand, in order. Each step links to the section with details.

| # | Step | Where | Status |
|---|---|---|---|
| 1 | Create the Android project: `flutter create --platforms=android .` | Project folder | Done |
| 2 | `flutter pub get`, then `dart run flutter_launcher_icons` | Project folder | Done ([App icon](#app-icon)) |
| 3 | INTERNET permission and the "Meet Prep Log" label in `AndroidManifest.xml` | `android/app/src/main/` | Done (v2.6) |
| 4 | `flutter pub get`, `flutter analyze` and `flutter test` | Project folder | Each update |
| 5 | Database migrations 0001, 0002, 0004, 0005, 0006 | Supabase | Done (applied for you) |
| 6 | Sync function `0003_sync_snapshot.sql` | Supabase → SQL Editor | Done (you ran it) |
| 7 | Load the competition percentiles with `analysis/build_standing.py` | Your computer | To do ([Where you stand](#where-you-stand-data)) |
| 8 | Turn email confirmation back on before going public | Supabase → Authentication | Later |
| 8b | Change the package name from `com.example.meet_prep_log` before the Play Store | `android/app/build.gradle(.kts)` | Later |
| 9 | `flutter run --release` on your phone | Project folder | Each update |

You only need the SQL Editor if you ever create a **new** Supabase project. Then run every file in `supabase/migrations/` in number order.

## App icon

The icon is a red 25 kg competition plate on navy (concept C, designed on the "Meet Prep Log App Icons" canvas).

| File | Used for |
|---|---|
| `assets/icon/icon.png` | Full icon, 1024 px: legacy Android icons and the source for other sizes |
| `assets/icon/foreground.png` | Android adaptive icon foreground (plate on a transparent 108 dp grid; the background is navy `#0C2340`) |
| `assets/icon/monochrome.png` | Android 13+ themed icon (white shape, tinted by the system) |
| `web/favicon.png`, `web/icons/*` | Browser tab and installed web app icons |

The settings are in the `flutter_launcher_icons:` block at the end of `pubspec.yaml`. To make every Android size (after step 1 of the checklist):

```bash
flutter pub get
dart run flutter_launcher_icons
```

This writes `android/app/src/main/res/mipmap-*` and `mipmap-anydpi-v26/ic_launcher.xml`. To change the icon, replace the three PNGs in `assets/icon/` (keep the plate inside the middle 61% of `foreground.png`, or launchers will crop it) and run the command again. `adaptive_icon_foreground_inset: 0` stops the tool adding extra padding, because the foreground already has it. iOS is off (`ios: false`) until there is an `ios/` folder.

## What's new in v2.7: federations and Wilks

Pick your federation in **Athlete tab → Athlete → Federation** (also asked during onboarding). It sets your weight classes and the formula used for your points.

| Federation | Men (kg) | Women (kg) | Points formula | Source |
|---|---|---|---|---|
| IPF and affiliates | 59, 66, 74, 83, 93, 105, 120, 120+ | 47, 52, 57, 63, 69, 76, 84, 84+ | IPF GL | IPF technical rules |
| USAPL | 52, 56, 60, 67.5, 75, 82.5, 90, 100, 110, 125, 140, 140+ | 44, 48, 52, 56, 60, 65, 70, 75, 82.5, 90, 100, 100+ | DOTS | [USAPL rulebook v2026.2](https://www.usapowerlifting.com/assets/general/PDFs/USAPL-Rulebook-v2026.2.pdf), rules 1.8.2–1.8.3 |
| USPA / IPL | same as USAPL men | 44, 48, 52, 56, 60, 67.5, 75, 82.5, 90, 100, 110, 110+ | DOTS | [USPA rulebook](https://uspa.net/rulebook), 1.3.1 and 1.6.1 |
| WRPF | same as USAPL men | 44, 48, 52, 56, 60, 67.5, 75, 82.5, 90, 90+ | Wilks | WRPF rulebook, 1.4 and 1.5.4 |

- **Points formula** can be changed under the federation (for example, use DOTS while in an IPF federation). The choice shows on the Progress total card, the Meet tab's attempt plan, meet-day mode and the coach's overview, with a second score (GL, or DOTS when you use GL) next to it.
- **Wilks** (original, ×500) and **Wilks 2020** (×600) are new. Bodyweight is held to the range each formula was fitted on (original: men 40–201.9 kg, women 26.51–154.53 kg; 2020: 40–200.95 / 40–150.95 kg). Checked against the published coefficient (0.6086 at 100 kg, men): 700 kg total → 426.0 Wilks.
- **Tools → Points calculator** shows all four scores at once.
- Switching federation or sex keeps your class if it exists, otherwise picks the lightest class that fits (for example IPF −105 → USAPL −110).
- **Where you stand** still compares you with **IPF** results (OpenIPF data). For other federations it uses "all classes" because the class limits differ.
- Old backups and synced data load as IPF with GL, so nothing changes until you pick another federation. The federation is saved in your synced data (no database change needed).

## What's new in v2.6: coach mode

Any account can coach, and any account can have a coach. Both need to be signed in.

**For the coach**
1. Athlete tab → **Coach** → turn on **I coach other lifters**. A **Coach** tab appears with your 6-character code (for example `5AXS4R`). Tap the copy icon to copy an invite message.
2. When an athlete enters your code, they appear in the Coach tab with their class and when they last synced. A badge shows unread comments.
3. Tap an athlete to see four tabs:
   - **Overview:** estimated total, GL, bodyweight, 7-day readiness, maxes vs best e1RM, current program progress, next meet, and the programs you sent (with **Take back** while they're unanswered).
   - **Program:** their week strip and workout cards. Tap a workout to see every logged set (kg × reps @ RPE, lights, e1RM), readiness answers, their notes, and the **comments**.
   - **Progress** and **Body:** the athlete's own Progress and Body screens, read-only.
4. **Send a program** (button on Overview or the ⋮ menu): pick one of your own programs, a start date and an optional note. Only the plan is sent (exercises, sets, %, reps, RPE). Your logs are not. Build the program in your own Program tab first, from a template or **Build your own**.

**For the athlete**
1. Athlete tab → **Coach** → **Connect to a coach** → enter the code. Entering the code is your approval. Your data syncs straight away so the coach sees it.
2. Programs your coach sends show in the Coach panel with **Accept** or **Decline**. Accepting adds it as your active program. Your old program and its logs stay in **Programs**. Percentages use **your** maxes.
3. Comments appear at the bottom of each workout, and you can reply. A badge on the Program tab and on workout cards shows unread comments.
4. Remove a coach at any time with the unlink icon. They lose access immediately.

**How it's protected (database)**
- `0006_coach_mode.sql` (already applied) adds the coach code to `profiles`, plus `coach_links`, `coach_comments`, `program_assignments` and the `v_coach_links` view.
- Row level security: a coach can read an athlete's profile and latest snapshot only while linked. Comments can be read and written only by the athlete and their coaches. Only the athlete can accept or decline a program, and only its status can change. Strangers see nothing.
- These rules were tested with three fake accounts (coach, athlete, stranger) in a transaction that was rolled back, so no test data was left behind.
- `connect_coach(code)` is a `security definer` function, because it has to find a coach by code. Supabase's advisor lists it as a warning; that is intended.

**What the coach sees** is the athlete's last sync, normally within 20 seconds of their last change. Pull down on the Coach tab, or tap refresh, to update.

## What's new in v2.5: العربية (Arabic)

- **Arabic and English.** Choose Phone, English or العربية in the Athlete tab, under **Language**.
- **In Arabic the whole app is right-to-left:** layouts, dialogs, date pickers, month and weekday names, and durations (د / س).
- **About 600 strings are translated:** every screen, the exercise library, program names, workout titles, coach notes, cues and the meet checklist. Numbers stay in Western digits, as most gyms in the Gulf use.
- **Letter spacing is turned off in Arabic,** because it breaks the joined letters.
- **How translation works:** text in the code stays in English. `T('Add workout')` (a drop-in for `Text`) and `tr(context, 'Week {n}', {'n': 3})` look up `lib/l10n/ar.dart`. A missing entry falls back to English.
- **Adding a string:** copy the exact English text, including any `{placeholders}`, as a new key in `ar.dart`. `test/l10n_test.dart` checks that every Arabic entry keeps its placeholders.
- **Still in English:** a few sentences built from changing values, such as weigh-in advice, fatigue warnings and RPE-adjustment reasons. Exercises and workouts you create yourself stay as you typed them.

## What's new in v2.4: competition

A new **Meet** tab:
- **Plan a meet:** name, place, date and weigh-in type (2-hour like IPF, or 24-hour). It shows a countdown, and you can keep several meets.
- **Peak timing:** checks whether your program's meet day lands on the meet date. **Line up my program** moves the workouts you haven't logged by the difference; logged workouts keep their dates.
- **Attempts:** suggested from your projected max (best e1RM in the last 28 days, otherwise your max plus RPE adjustments) at about 91%, 96.5% and 101%. Every attempt can be edited. Shows opener and planned totals, GL and DOTS at your meet bodyweight, and where that ranks.
- **Weigh-in:** your 7-day average against the class limit, with advice that fits a 2-hour or a 24-hour weigh-in.
- **Meet bag:** a checklist of 15 items. Check your federation's approved equipment list.
- **Meet day:** enter your weigh-in bodyweight, then each attempt with three referee lights (white = good lift, red = no lift, two whites count). It shows your best lift, running total, GL and DOTS, and warns you if a lift has no good attempt. After each decision a 60-second timer reminds you to hand in your next attempt. Each lift shows a warm-up ramp to your opener.

**DOTS** now appears next to GL in the calculator and on meet day.

<a id="where-you-stand-data"></a>**Where you stand:** the GL calculator and the Meet tab rank your GL and total against real lifters of your sex, division and IPF class. The numbers come from OpenIPF (IPF-affiliated meets, public domain data from OpenPowerlifting). To load them:

```bash
pip install pandas numpy sqlalchemy "psycopg[binary]" requests
export DATABASE_URL="postgresql+psycopg://..."   # Supabase dashboard → Connect → Session pooler
python analysis/build_standing.py --dry-run     # check the summary first, nothing is uploaded
python analysis/build_standing.py               # last 3 years; add --years 5 for more
```

On Windows PowerShell, set the variable like this instead of `export`:

```powershell
$env:DATABASE_URL="postgresql+psycopg://postgres.czjbqrirvxxwmgzwoxdo:YOUR_PASSWORD@<pooler host>:5432/postgres"
```

Copy the URI from Supabase (**Connect → Session pooler**), change `postgresql://` to `postgresql+psycopg://`, and put in your database password. Never commit it to a file.

The script uploads percentile tables to `competition_percentiles` (migration 0005, already applied). Every user can read them, and only you can write them. The app downloads them at launch and keeps a copy for offline use. Re-run the script every few months.

## What's new in v2.3: smart coaching

- **RPE auto-regulation.** When you finish a workout, the app compares your heaviest planned set (the top single, if there is one) with the RPE you logged:
  - 1.5 or more below target: +2 steps
  - 0.75 below target: +1 step
  - 1 or more above target: −1 step
  - missed: −2 steps

  A step is 5 kg for squat and deadlift, 2.5 kg for bench. You choose which changes to apply, and they affect the rest of the program from the next week. They show as chips on the Program tab, where you can undo them.
- **Update-max prompt.** When your estimated max beats your entered max by 2.5 kg or more, the Progress tab offers to update it.
- **Readiness check.** Before each workout you rate sleep, energy, soreness and stress, and get a score from 0 to 100 with advice. Below 50 it suggests main lifts 5% lighter that day, below 35 it suggests 10% lighter. You can change today's load from the workout screen at any time.
- **Week load** (Progress tab): hard sets by area this week against last week. Warnings appear when your competition lifts average RPE 8.8 or more, when hard sets jump more than 30%, when you miss 2 or more competition-lift sets, or when readiness averages below 50.
- **Weight trend** (Body tab): 7-day average, change from the week before, and rate in kg per week, with a warning above 1% of bodyweight a week and an estimate of the weeks left to reach your meet range.
- **Database:** workouts now store the readiness answers and today's load, and programs store the RPE adjustments (`0004_…`, already applied). `v_workout_summary` adds readiness and average main-lift RPE, and the analysis script uses both as features.

## What's new in v2.2: accounts and cloud database

- **Account** (Athlete tab → Account): create an account with email and password, sign in, reset your password, sign out. Without an account the app works offline exactly as before.
- **Sync**: when you're signed in, everything uploads about 20 seconds after you stop editing, and again when you leave the app. On a new phone, sign in and choose **Use the cloud backup**.
- **Database for analysis**: each sync also writes clean rows (profiles, programs, workouts, sets, body entries) and analysis views that calculate e1RM, weekly progress and GL points on the server.
- **`analysis/progress_model.py`**: a starter script that reads all lifters' data and predicts each lifter's e1RM 4 weeks ahead. Run it with the same `DATABASE_URL` as above:
  ```bash
  pip install pandas scikit-learn sqlalchemy "psycopg[binary]"
  python analysis/progress_model.py
  ```
  With fewer than 5 lifters it falls back to each lifter's own trend.

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
| `coach_links` / `v_coach_links` | Coach ↔ athlete links (with names and last sync time) |
| `coach_comments` | Comments on an athlete's workouts by the athlete or their coach |
| `program_assignments` | Programs a coach sent, with status sent / accepted / declined |
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
cd Powerlifting-Workout
flutter create --platforms=android --project-name meet_prep_log --org com.abdulaziz .
flutter pub get
dart run flutter_launcher_icons    # app icon, see "App icon"
flutter analyze
flutter test
flutter run --release              # phone plugged in with USB debugging on
# or: flutter build apk --release  -> build/app/outputs/flutter-apk/app-release.apk
```

`flutter create .` only adds missing files. It won't overwrite `lib/`. If you're updating the v1 folder, delete the old `lib/` and `test/` first, then copy these in. `lib/plan.dart`, `lib/store.dart` and `lib/screens/` from v1 are replaced by `lib/core/` and `lib/ui/`.

`android/app/src/main/AndroidManifest.xml` already has the INTERNET permission (needed for sign-in, sync and coach mode) and the label "Meet Prep Log". If you ever delete `android/` and run `flutter create` again, add both back.

Requires Flutter 3.22 or newer (Dart 3.4+).

## Code map

| File | What it does |
|---|---|
| `lib/core/calc.dart` | Formatting, dates, plate math, estimated 1RM (Epley with reps in reserve), IPF GL points, IPF weight classes |
| `lib/core/models.dart` | PlannedSet, LoggedSet, ExerciseSlot, Workout, Program, Profile, BodyEntry, CheckIn, all with JSON |
| `lib/core/library.dart` | Built-in exercise library |
| `lib/core/templates.dart` | The four program templates |
| `lib/core/store.dart` | App state, editing operations, analysis, check-in text, saving, backup/restore, v1 migration |
| `lib/core/cloud.dart` | Supabase sign-in, sync, restore and coach mode (links, comments, sent programs) |
| `supabase/migrations/` | Database schema, analysis views and the sync function |
| `analysis/progress_model.py` | Starter analysis and 4-week e1RM prediction |
| `analysis/build_standing.py` | Builds the competition percentile tables from OpenIPF |
| `assets/icon/` | App icon sources for `flutter_launcher_icons` |
| `lib/ui/screens/meet_screen.dart` | Meet tab and meet-day mode |
| `lib/ui/screens/coach_screen.dart` | Coach tab, athlete view, read-only workout, comments, send-program sheet, and the athlete's Coach panel |
| `lib/l10n/l10n.dart`, `lib/l10n/ar.dart` | Arabic/English: `T()`, `tr()` and the Arabic dictionary |
| `lib/ui/theme.dart` | Palette (light/dark) and theme |
| `lib/ui/widgets.dart` | Header, lift tag, plate loading, referee light, stat tile, chart, dialogs |
| `lib/ui/screens/` | Program, Workout (with rest timer and warm-ups), Exercise editor, Progress, Body, Athlete, Program picker, Tools, Onboarding |
| `test/core_test.dart` | Tests for the maths, templates, JSON, coaching and competition features |
| `test/l10n_test.dart` | Checks every Arabic entry keeps its `{placeholders}` |
| `test/widget_test.dart` | Checks the light and dark themes build (replaces the counter test from `flutter create`) |

## How the data works

- A **program** is a list of **workouts**. Each workout has **exercise slots**, each with a **plan** (target sets) and a **log** (what you did).
- Loads are stored as a percentage of a competition max where that makes sense, so changing a max in the Athlete tab updates every target.
- An exercise slot keeps the same `id` across weeks. That's how "also add to / remove from later weeks" finds the matching workouts (same workout name, later week).
- Everything is one JSON blob in `shared_preferences` (`meet_prep_log_v2`). It's saved half a second after each change and immediately when the app goes to the background.
