# Meet Prep Log: market comparison and roadmap

## Where the market is (US App Store prices, checked Sept–Oct 2026)

| App | What it is | Price | Strong for powerlifters | Gaps for powerlifters |
|---|---|---|---|---|
| **Hevy** | Fast general logger, biggest user base (4.9★, ~95K ratings) | Free; Pro $2.99/mo, $23.99/yr, $74.99 lifetime | Quick logging, Apple Watch and Wear OS apps, social feed | Free tier capped at 4 routines and 7 custom exercises. Auto-progression is Pro-only and rule-based. No meet prep |
| **Strong** | Clean logger for barbell routines | Free (3 templates); Pro $4.99/mo, $29.99/yr, $99.99 lifetime | RPE tags, 1RM estimate, rest timer | Doesn't program or adjust weights. Plate calculator and body measurements are Pro-only. Weaker Android app (4.3★), no Wear OS. CSV export can't be re-imported |
| **Boostcamp** | Library of ready-made programs (5/3/1, nSuns, GZCL, Sheiko, Candito...) | Free core; Pro $14.99/mo or $59.99/yr | Biggest free program library, RPE on every set, PR tracking | Progression follows each program's fixed rules. Peaking only through specific programs, no meet-date system. Heatmap and some programs are Pro |
| **JuggernautAI** | AI coach using Chad Wesley Smith's methodology | $34.99/mo or $349.99/yr, no free tier | Adapts to readiness and RPE, works back from a meet date, Meet Day attempt advisor | Most expensive, one methodology only, no proper watch app |
| **Sheiko Gold** | Official Boris Sheiko AI app | $19.99/mo, $118.99/yr, $219.99 lifetime | High-frequency % programs that adapt, velocity (VBT) support | iPhone only. 30-day learning period before it personalises |
| **StrengthLog** | Free tracker with named programs (4.87★) | Free; Premium (price not listed) | Competition-day totals, 1RM, 450+ exercises | Program catalogue and % templates are Premium |
| **Liftosaur** | Programmable logger ("Liftoscript") | Free core; $4.99/mo, $39.99/yr, $99.99 lifetime | You can write any progression rule | Steep learning curve. Graphs and plate calculator are paid |

**The gap:** the cheap loggers (Hevy, Strong) don't coach, and the coaching apps (JuggernautAI, Sheiko) are expensive and locked to one method. Most apps put the plate calculator, body measurements or meet features behind a paywall. Nobody combines **free plate math + body composition + meet-day tools + editable % programs** in one app built around federation rules.

## What Meet Prep Log v2 already does that most free tiers don't

- Plate math on every barbell exercise (Pro-only in Strong and Liftosaur)
- Full InBody-style body composition tracking with weight-class status (Pro-only or missing in most apps)
- IPF GL points and an estimated total
- Templates for beginner, intermediate and advanced, plus a blank builder, all editable with no caps on routines or custom exercises
- Referee lights per set, so missed lifts don't inflate your estimated max
- Works fully offline, no account needed

## Weak spots compared with competitors

1. **No sync or account.** Data lives on one phone. Hevy, Strong and Boostcamp all sync.
2. **No auto-regulation.** Targets don't change based on RPE. JuggernautAI and Sheiko do this.
3. **No rest timer, warm-up calculator or watch app.**
4. **No meet-day mode or attempt planning.**
5. **Android only** right now.

## Roadmap

### Phase 1: polish what's there (1–2 weeks)
- [x] **Rest timer** with a vibration alert. Starts when you mark a set; defaults 3 min main lifts, 90 s accessories (v2.1).
- [x] **Warm-up calculator** for the first lift: bar × 10, 40% × 5, 60% × 3, 75% × 2, 85% × 1 (v2.1).
- [x] **Plate settings:** 15/20/25 kg bar, which plates the gym has, competition collars (v2.1). *Still to do: pounds.*
- [x] **Onboarding:** about you, maxes (or estimate from a recent set), choose a program (v2.1).
- [x] **PR board:** best 1, 3 and 5 rep weights and best e1RM per lift, with dates (v2.1).
- [x] **Export:** sets and body data as CSV, copied to the clipboard (v2.1). *Still to do: save as a file and share.*

### Phase 2: smart coaching (the reason to switch from Hevy/Strong)
- [x] **RPE auto-regulation:** suggested changes after each workout, with undo (v2.3).
- [x] **e1RM → update max prompt** (v2.3).
- [x] **Readiness check** with a suggested load for the day (v2.3).
- [x] **Weekly hard sets by area** and fatigue warnings (v2.3).
- [x] **Bodyweight trend:** 7-day average, kg per week, weeks to your meet range (v2.3).

### Phase 3: competition features (what makes it *the* powerlifting app)
- [x] **Meet planner:** meet date, countdown, and lining up the program's peak with it (v2.4).
- [x] **Attempt selector and meet-day mode** with 3 referee lights, live total, GL, DOTS and an attempt timer (v2.4).
- [x] **DOTS** added (v2.4).
- [x] **More federations:** IPF, USAPL, USPA/IPL and WRPF classes, each with its best-lifter formula, plus Wilks and Wilks 2020 (v2.7). *Still to do: more federations (RPS, SPF, WPC), masters age coefficients, and standings for non-IPF federations.*
- [x] **Weigh-in plan** for 2-hour and 24-hour weigh-ins (v2.4).
- [x] **Meet bag checklist** (v2.4).

### Phase 4: growth
- [x] **Accounts and cloud sync** with Supabase: email sign-in, automatic sync, restore on a new phone, analysis tables and views (v2.2).
- [x] **Progress prediction in the app:** each lift's estimated max in 4 weeks or on meet day, with an 80% range and goal verdict, worked out on the phone from the lifter's own logs (v2.8). *Still to do: use `analysis/progress_model.py` across many lifters once there are enough of them.*
- [x] **GL standing** against OpenIPF results by sex, division and class (v2.4). Run `analysis/build_standing.py` to load the data.
- [x] **Coach mode:** a coach builds programs, sends them to athletes, reads their logs, readiness and body data, and comments on workouts (v2.6). *Still to do: coach-only program drafts, group messages, and per-athlete pricing.*
- [ ] **Video:** attach a set video, frame-by-frame review, bar path, maybe bar speed (VBT).
- [ ] **iOS build** (same Flutter code; needs a Mac and an Apple developer account).
- [ ] **Watch app** (Wear OS first) for logging sets and the rest timer.
- [x] **Localization:** Arabic (RTL) and English (v2.5). *Still to do: the few dynamic sentences, and Arabic exercise search.*

### Business model that undercuts the market
- **Free forever:** logging, all templates, plate math, body tracking, GL points. That's more than most competitors' free tiers.
- **Pro (~$2.99/mo or $24.99/yr, plus a lifetime option):** auto-regulation, meet planner, attempt selector, sync, video.
- **Coach plan:** per-athlete pricing.

## Before a public release
- Rename the app (Meet Prep Log is fine for personal use). The icon is done (competition plate, v2.5). Don't use federation logos or names in the branding.
- Change the Android package from `com.example.meet_prep_log` to your own (for example `com.abdulaziz.meetpreplog`); the Play Store rejects `com.example`.
- Privacy policy (body data is health data, and coaches can see an athlete's data). Play Store listing with screenshots.
- Crash reporting (Sentry or Firebase Crashlytics) and a small beta group from your gym.
- Widget tests for the main flows (log a set, add an exercise, restore a backup).
