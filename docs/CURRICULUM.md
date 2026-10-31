# Curriculum v2: assumptions and limits

This is an original development curriculum, not a copied Zen Labs or Higdon schedule and not a scientifically validated prescription. Software tests establish consistent definitions, not physiological safety or guaranteed race readiness. A qualified coach must review the original full tables, prerequisites, weekly volumes, recovery, and taper before longer-distance production release.

## Research basis

- [Zen Labs C25K support](https://www.zenlabsfitness.com/support): gradual beginner walk/run work, eight weeks, three weekly sessions. The app is a functional reference, not a source of copied interval tables.
- [Zen Labs 10K publisher listing](https://apps.apple.com/us/app/10k-trainer-by-c25k/id511600311): three weekly workouts, progressive walk/run training and audio guidance. An iOS listing does not establish Android implementation details.
- [NHS Couch to 5K](https://www.nhs.uk/better-health/get-active/get-running-with-couch-to-5k/): gradual beginner progression with rest between runs.
- [Higdon novice 10K](https://www.halhigdon.com/training-programs/10k-training/novice-10k/): entering a distance-specific block requires an existing running base.
- [Higdon novice half](https://www.halhigdon.com/training-programs/half-marathon-training/novice-1-half-marathon/): published entry base and four weekly runs, not proof of the suitability of an original three-run adaptation.
- [Higdon novice marathon](https://www.halhigdon.com/training-programs/marathon-training/novice-1-marathon/): easy volume, long runs, stepbacks and taper.
- [Higdon Marathon 3](https://www.halhigdon.com/training-programs/marathon-training/marathon-3/): three running days are intended for experienced runners and accompanied by supporting activity, not three identical short workouts for a nonrunner.

These verified structural principles informed the original parameters below. Numeric readiness screens and adaptations are product assumptions pending review, not thresholds proven by the cited sources. A universal percentage-increase rule is not used as a safety guarantee.

## Supported combinations

| Goal | Beginner | Intermediate | Experienced |
|---|---|---|---|
| 5K | 10–999 weeks, recommend 10 | 8–999, recommend 10 | 8–999, recommend 10 |
| 10K | 18–999, recommend 18 | 10–999, recommend 12 | 10–999, recommend 12 |
| Half | Redirect to a 5K/10K foundation first | 20–999, recommend 20, base/support checks | 16–999, recommend 16, base/support checks |
| Marathon | Foundation first | Foundation first | 24–999, recommend 30, stronger base/support checks |

Unsupported requests are rejected with a visible explanation. They are not silently compressed. The 16-week beginner 10K suggestion in the original brief has been replaced with an 18-week minimum including the full foundation. A beginner's 20-week half or 30-week marathon is not generated automatically.

Half prerequisite screen: six weeks of consistent three-day running, comfortable 5K runs, and a recent comfortable 8–10K outing. Marathon: experienced runner for at least a year, 25–35 km weekly for eight weeks, and a recent comfortable 12–16K long run. Longer goals also require confirming supporting activity and recovery. These coarse screens cannot detect all readiness issues.

## Generation rules

Implementation: lib/src/training/plan.dart. Inspect [generated default weekly tables](CURRICULUM-SAMPLES.md) before reviewing training volume. Programs store the exact generated definitions and curriculum version, so later algorithm changes never rewrite an active or historical program.

- Every session has five-minute walking warm-up/cooldown, matching bundled duration-specific speech assets.
- The default ten-week beginner foundation retains ten original stages. Longer beginner plans (20+ weeks) use a gentler 21-stage ladder with additional ratios, including 30 seconds run / 3 minutes walk, 45 seconds / 3 minutes, 1 minute / 3 minutes, 1 minute / 2 minutes 30 seconds, and intermediate combinations through continuous running. Stages are distributed across the requested foundation duration. The standard ten-stage parameters are: Run seconds: 60, 90, 120, 180, 240, 300, 480, 600, 900, 1800. Walk seconds: 90, 90, 90, 90, 90, 60, 60, 60, 60, 0. Repetitions: 8, 7, 6, 5, 4, 4, 3, 2, 2, 1. The brief supplied the first-stage example. Repeating stages is encouraged; no speed or distance claim is attached.
- Longer beginner 10K programs first preserve the full foundation block, then add distance-preparation time.
- After foundation, each week has an easy run, a shorter recovery run, and a longer easy run. Running is conversational, not speed training.
- Original long-run time parameters start at 25/30/45/75 minutes for 5K/10K/half/marathon. Build increments are five minutes per non-extended template week, capped at 35/65/120/180 minutes respectively.
- Supporting run times grow with long-run volume at approximately 60% and 50% of the long-run time, within 20–120 minutes. This prevents concentrating most weekly running in one day. Exact totals depend on rounding, cutbacks and taper.
- Every fourth non-foundation template week reduces running time to 75%, except during taper. Half/short-goal taper reserves the last two weeks; marathon reserves three. Final-week running time is reduced to 45%, preceding taper week 60%, and the first marathon taper week 75%.
- Longer requested timelines distribute consolidation across the full build. A 60-week 5K is supported directly, without spending fifty weeks on the opening workout. The taper remains at the end for distance-specific plans. Timelines can be selected from presets or entered as a whole number up to the three-digit input limit (999 weeks). The previous goal-specific upper limits were removed at the user’s request.

The initial design proposed a reviewed-template catalog. This prototype implements a versioned parameterized catalog of original stages with strict supported ranges. Independent curriculum review remains outstanding; production must not represent this adaptation as a validated catalog. Replacing individual templates is supported by versioned serialized program definitions.

## Completion, repetition and distance

Only finishing the prescribed sequence automatically completes an attempt. Stopping early saves incomplete history and never advances the normal cursor. Unexpected process termination resumes paused/interrupted at the last durable checkpoint; elapsed downtime is not credited. Missed days never advance anything.

Repeat Workout adds another attempt without moving the normal cursor. Repeat Week queues three sessions and resumes the saved normal progression afterward; newly completed sessions in an unfinished week can satisfy their original scheduled slots. All previous attempts remain. Restarting appends a new program and preserves archived definitions/history.

Workout completion, scheduled-program completion, and a self-reported distance are separate facts. Optional km entry is explicitly user-reported, not measured. Time alone cannot establish distance, pace, marathon readiness or a successful race. Long-distance runners must independently select/know routes and assess the adequacy of their distance preparation; the time cap may not suit every pace.

Extended breaks may require backing up further than the current week. The app supports pausing, repeating and restarting, but does not infer injury recovery or prescribe a return-to-running protocol.

## Written workouts and skipping

Every workout is described from its actual stored intervals in complete sentences, including warm-up, repeated run/walk pairs, cooldown and total time. Program view groups each week into Day 1, Day 2 and Day 3. Existing program/history definitions retain their original prescriptions.

Skip Interval advances to the next step without adding omitted time to exercise duration. Skips and their durations are checkpointed and retained in history, including after interruption. Paused workouts stay paused when skipped. Finishing a sequence with skips records a modified result and does not automatically advance the program; the user can explicitly confirm Continue to next day or repeat. Whole-workout halfway/final-minute milestones are suppressed after a skip because the prescribed timeline has changed.
