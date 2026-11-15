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
- [ ] **Meet planner:** enter the meet date, and the program aligns its peak and taper to it.
- [ ] **Attempt selector:** suggests 1st/2nd/3rd from recent top singles. On meet day, record attempts with white and red lights per referee (3 lights), and show the live total and GL.
- [ ] **Federation rules:** IPF classes and GL now. Add USAPL, WRPF and other classes, plus DOTS and Wilks.
- [ ] **Weigh-in plan:** water and food timeline for a 2-hour vs 24-hour weigh-in.
- [ ] **Equipment checklist:** IPF-approved belt, sleeves, wraps, singlet, socks, ID.

### Phase 4: growth
- [x] **Accounts and cloud sync** with Supabase: email sign-in, automatic sync, restore on a new phone, analysis tables and views (v2.2).
- [ ] **Progress prediction in the app:** show the 4-week e1RM forecast from `analysis/progress_model.py` once there are enough lifters.
- [ ] **GL standing:** compare a lifter's GL and total with real competition results in their class (OpenPowerlifting data).
- [ ] **Coach mode:** a coach builds programs, assigns them to athletes, and reads their logs and check-ins. This is how TrainHeroic and TrueCoach make money.
- [ ] **Video:** attach a set video, frame-by-frame review, bar path, maybe bar speed (VBT).
- [ ] **iOS build** (same Flutter code; needs a Mac and an Apple developer account).
- [ ] **Watch app** (Wear OS first) for logging sets and the rest timer.
- [ ] **Localization:** Arabic (RTL) and English, for the GCC market where there's little competition.

### Business model that undercuts the market
- **Free forever:** logging, all templates, plate math, body tracking, GL points. That's more than most competitors' free tiers.
- **Pro (~$2.99/mo or $24.99/yr, plus a lifetime option):** auto-regulation, meet planner, attempt selector, sync, video.
- **Coach plan:** per-athlete pricing.

## Before a public release
- Rename the app (Meet Prep Log is fine for personal use) and design an original icon. Don't use federation logos or names in the branding.
- Privacy policy (body data is health data). Play Store listing with screenshots.
- Crash reporting (Sentry or Firebase Crashlytics) and a small beta group from your gym.
- Widget tests for the main flows (log a set, add an exercise, restore a backup).
