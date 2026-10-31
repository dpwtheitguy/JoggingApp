import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/coach_store.dart';
import '../training/plan.dart';
import '../training/workout_description.dart';
import 'digital_rain.dart';
import 'history_screen.dart';
import 'timeline_dialog.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, this.store});
  final CoachStore? store;
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> with WidgetsBindingObserver {
  late final CoachStore store;
  final distanceController = TextEditingController();
  int tab = 0;
  bool configuring = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store = widget.store ?? CoachStore();
    unawaited(store.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(store.initialize());
    } else {
      store.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    distanceController.dispose();
    store.stopPolling();
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  Map<String, dynamic> get copy =>
      jsonDecode(jsonEncode(store.state)) as Map<String, dynamic>;
  Future<bool> confirm(String title, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      if (!store.loaded) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: store.error == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(store.error!),
                        FilledButton(
                          onPressed: () => store.refresh(clearError: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
            ),
          ),
        );
      }
      final p = store.program;
      final runtime = store.runtime;
      final active = runtime != null;
      final setup = !active && (p == null || configuring);
      final body = active
          ? player(runtime)
          : setup
          ? SetupScreen(
              onInitialize: (plan) async {
                final ok = await store.command(
                  'newProgram',
                  plan.toJson(DateTime.now().microsecondsSinceEpoch.toString()),
                );
                if (ok && mounted) {
                  setState(() {
                    configuring = false;
                    tab = 0;
                  });
                }
              },
            )
          : switch (tab) {
              0 => dashboard(p!),
              1 => programView(p!),
              2 => history(),
              _ => settings(),
            };
      return Scaffold(
        appBar: AppBar(
          title: const Text('RUN//PROGRAM'),
          actions: [
            if (configuring && p != null)
              IconButton(
                onPressed: () => setState(() => configuring = false),
                icon: const Icon(Icons.close),
                tooltip: 'Cancel new program',
              ),
          ],
        ),
        body: Stack(
          children: [
            if (!active &&
                store.settings['rain'] != false &&
                !MediaQuery.disableAnimationsOf(context))
              const Positioned.fill(child: DigitalRain()),
            Column(
              children: [
                if (store.error != null)
                  MaterialBanner(
                    content: Text(store.error!),
                    actions: [
                      TextButton(
                        onPressed: () => store.refresh(clearError: true),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                Expanded(child: body),
              ],
            ),
            if (store.busy)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(),
              ),
          ],
        ),
        bottomNavigationBar: setup || active
            ? null
            : NavigationBar(
                selectedIndex: tab,
                onDestinationSelected: (i) => setState(() => tab = i),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.view_list_outlined),
                    label: 'Program',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.history),
                    label: 'History',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    label: 'Settings',
                  ),
                ],
              ),
      );
    },
  );
  Widget page(List<Widget> children) => ListView(
    padding: const EdgeInsets.all(24),
    children: children.expand((w) => [w, const SizedBox(height: 16)]).toList(),
  );
  Widget title(String text) =>
      Text(text, style: Theme.of(context).textTheme.headlineSmall);
  Widget primary(String text, VoidCallback? action) => FilledButton(
    onPressed: store.busy ? null : action,
    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
    child: Text(text),
  );
  List<dynamic> workouts(Map<String, dynamic> p) => p['workouts'] as List;
  int nextIndex(Map<String, dynamic> p) => (p['replay'] as List).isNotEmpty
      ? (p['replay'] as List).first as int
      : p['cursor'] as int;
  Future<void> start(Map<String, dynamic> p, int index, {String? mode}) async {
    await store.command('start', {
      'programId': p['id'],
      'index': index,
      'mode': mode ?? ((p['replay'] as List).isNotEmpty ? 'week' : 'normal'),
      'workout': workouts(p)[index],
    });
  }

  Widget workoutBreakdown(Map workout) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final line in workoutInstructions(workout))
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(line)),
    ],
  );
  Widget dashboard(Map<String, dynamic> p) {
    final all = workouts(p);
    final index = nextIndex(p);
    final done = index >= all.length;
    final w = done ? null : Map<String, dynamic>.from(all[index] as Map);
    final goal = RunningGoal.values.byName(p['goal'] as String);
    return page([
      Text(
        p['paused'] == true
            ? 'TRAINING PAUSED'
            : done
            ? 'PROGRAM COMPLETE'
            : 'SIMULATION READY',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      title('Your next training sequence'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title('TARGET · ${goal.label}'),
              const SizedBox(height: 16),
              Text('${p['weeks']} weeks · 3 runs per week'),
              const SizedBox(height: 8),
              if (w != null) ...[
                Text('Week ${w['week']} · Day ${w['session']}'),
                Text('${w['role']} · ${durationLabel(w['seconds'] as int)}'),
                const SizedBox(height: 8),
                Text(workoutSummary(w)),
              ],
              if ((p['replay'] as List).isNotEmpty)
                const Text('Repeating week · history preserved'),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: (p['cursor'] as int) / all.length),
              const SizedBox(height: 8),
              Text(
                '${p['cursor']} / ${all.length} scheduled workouts complete · ${all.length - (p['cursor'] as int)} remaining',
              ),
            ],
          ),
        ),
      ),
      if (!done)
        primary(
          p['paused'] == true ? 'Resume Training' : 'Start Workout',
          () async {
            if (p['paused'] == true) {
              await store.command('pauseTraining', {'paused': false});
            } else {
              await start(p, index);
            }
          },
        ),
      if (done) ...[
        const Text(
          'You completed the scheduled training program. This does not verify that you ran the target race distance.',
        ),
        primary(
          'Repeat final workout',
          () => start(p, all.length - 1, mode: 'repeat'),
        ),
      ],
      if (w != null) ...[
        title('Week ${w['week']} · Day ${w['session']} workout'),
        workoutBreakdown(w),
      ],
      if (w != null)
        ExpansionTile(
          title: Text('Week ${w['week']} · All three days'),
          children: [
            for (final day in all.where(
              (item) => (item as Map)['week'] == w['week'],
            ))
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title('Day ${(day as Map)['session']}'),
                    workoutBreakdown(day),
                  ],
                ),
              ),
          ],
        ),
      OutlinedButton(
        onPressed: () async {
          if (await confirm(
            'Repeat this week?',
            'Replay three sessions without erasing previous attempts. Normal progression resumes afterward.',
          )) {
            await store.command('repeatWeek');
          }
        },
        child: const Text('Repeat Week'),
      ),
      const Text(
        'Run at an easy, conversational effort. Rest between beginner sessions. Repeat whenever you need; missed days never advance the plan.',
      ),
      if (goal == RunningGoal.half || goal == RunningGoal.marathon)
        const Text(
          'Long-distance development curriculum: route distance and supporting activity matter. Timed completion alone cannot establish race readiness. Templates await independent coach review.',
        ),
    ]);
  }

  Widget programView(Map<String, dynamic> p) {
    final all = workouts(p);
    final currentWeek = (nextIndex(p).clamp(0, all.length - 1) ~/ 3);
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: (all.length / 3).ceil(),
      itemBuilder: (context, week) => Card(
        child: ExpansionTile(
          key: PageStorageKey('${p['id']}-week-$week'),
          initiallyExpanded: week == currentWeek,
          title: Text('Week ${week + 1} of ${p['weeks']}'),
          children: [
            for (var day = 0; day < 3 && week * 3 + day < all.length; day++)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title('Day ${day + 1}'),
                    Text(
                      '${(all[week * 3 + day] as Map)['role']} · ${durationLabel((all[week * 3 + day] as Map)['seconds'] as int)}${week * 3 + day < (p['cursor'] as int) ? ' · Complete' : ''}',
                    ),
                    const SizedBox(height: 8),
                    workoutBreakdown(all[week * 3 + day] as Map),
                    if (week * 3 + day <= (p['cursor'] as int) ||
                        week * 3 + day == nextIndex(p))
                      OutlinedButton(
                        onPressed: () => start(
                          p,
                          week * 3 + day,
                          mode: week * 3 + day < (p['cursor'] as int)
                              ? 'repeat'
                              : null,
                        ),
                        child: Text(
                          week * 3 + day < (p['cursor'] as int)
                              ? 'Repeat Day ${day + 1}'
                              : 'Start Day ${day + 1}',
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget history() => WorkoutHistory(
    attempts: store.history,
    programs: (store.state['programs'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(),
  );
  Widget settings() {
    final prefs = store.settings;
    return page([
      title('System settings'),
      for (final entry in {
        'voice': 'Voice coaching',
        'halfway': 'Whole-workout halfway cue',
        'warning': 'One minute left in workout',
        'duck': 'Duck other audio during coaching',
        'vibration': 'Vibration at cues',
        'rain': 'Digital rain',
      }.entries)
        SwitchListTile(
          title: Text(entry.value),
          value: prefs[entry.key] as bool? ?? entry.key != 'vibration',
          onChanged: store.busy
              ? null
              : (value) =>
                    store.command('settings', {...prefs, entry.key: value}),
        ),
      const Text(
        'Voice clips are bundled and work offline. Other audio apps may pause instead of ducking. Digital rain is disabled during workouts and respects reduced motion.',
      ),
      OutlinedButton(
        onPressed: () async {
          final p = store.program!;
          await store.command('pauseTraining', {'paused': p['paused'] != true});
        },
        child: Text(
          store.program?['paused'] == true
              ? 'Resume training program'
              : 'Pause training program',
        ),
      ),
      OutlinedButton(
        onPressed: () async {
          if (await confirm(
            'Initialize another program?',
            'Previous programs and every workout attempt will stay in local history.',
          )) {
            if (mounted) setState(() => configuring = true);
          }
        },
        child: const Text('Restart / change program'),
      ),
      const Text(
        'Privacy: no account, GPS, analytics, or cloud backup. History lives on this device; uninstalling or losing the device can lose it.',
      ),
    ]);
  }

  Widget player(Map<String, dynamic> r) {
    final status = r['status'] as String;
    final terminal = const {
      'completed',
      'stopped',
      'modified',
      'modified_confirmed',
    }.contains(status);
    final modified = status == 'modified' || status == 'modified_confirmed';
    final w = Map<String, dynamic>.from(r['workout'] as Map);
    final steps = w['intervals'] as List;
    final elapsed = (r['elapsedMs'] as num? ?? 0).toInt();
    var index = (r['intervalIndex'] as num? ?? 0).toInt();
    var remaining =
        (r['remainingMs'] as num? ??
                ((steps.first as Map)['seconds'] as int) * 1000)
            .toInt();
    final skipped = (r['skippedMs'] as num? ?? 0).toInt();
    final position = elapsed + skipped;
    if (status == 'interrupted') {
      var cumulative = 0;
      for (var i = 0; i < steps.length; i++) {
        cumulative += ((steps[i] as Map)['seconds'] as int) * 1000;
        if (position < cumulative) {
          index = i;
          remaining = cumulative - position;
          break;
        }
      }
    }
    final activity = activityLabel((steps[index] as Map)['activity'] as String);
    final total = (w['seconds'] as int) * 1000;
    return page([
      Text(
        terminal
            ? 'SEQUENCE · ${attemptResultLabel(status).toUpperCase()}'
            : 'TRAINING SEQUENCE · ${status.toUpperCase()}',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      Text(
        terminal
            ? modified
                  ? 'Workout finished with skips'
                  : status == 'completed'
                  ? 'Workout complete'
                  : 'Workout stopped early'
            : activity,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          durationLabel(terminal ? elapsed ~/ 1000 : (remaining + 999) ~/ 1000),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 72,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
      if (!terminal)
        Text(
          index + 1 < steps.length
              ? 'NEXT: ${activityLabel((steps[index + 1] as Map)['activity'] as String)} · ${durationLabel((steps[index + 1] as Map)['seconds'] as int)}'
              : 'NEXT: Workout complete',
        ),
      LinearProgressIndicator(value: (position / total).clamp(0, 1)),
      Text(
        'Sequence ${(position * 100 / total).floor()}% · ${durationLabel(elapsed ~/ 1000)} active / ${durationLabel(total ~/ 1000)} prescribed',
      ),
      if (skipped > 0)
        Text(
          '${writtenDuration((skipped + 999) ~/ 1000)} skipped. Skipped time is not recorded as exercise.',
        ),
      if (r['message'] != null) Text(r['message'] as String),
      if (!terminal) ...[
        primary(
          status == 'running' ? 'Pause' : 'Resume',
          () => store.command(status == 'running' ? 'pause' : 'resume'),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.skip_next),
          label: const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Skip Interval'),
          ),
          onPressed: store.busy || status == 'interrupted'
              ? null
              : () async {
                  if (index == steps.length - 1 &&
                      !await confirm(
                        'Skip the final interval?',
                        'Finish with skipped time recorded. You can choose whether to advance this day afterward.',
                      )) {
                    return;
                  }
                  await store.command('skip');
                },
        ),
        OutlinedButton(
          onPressed: () async {
            if (await confirm(
              'End workout?',
              'This attempt will be saved as incomplete. It will not advance your program.',
            )) {
              await store.command('end');
            }
          },
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text('End Workout'),
          ),
        ),
        TextButton(
          onPressed: () => store.command('settings', {
            ...store.settings,
            'voice': store.settings['voice'] == false,
          }),
          child: Text(
            store.settings['voice'] == false
                ? 'Unmute coaching'
                : 'Mute coaching',
          ),
        ),
      ] else ...[
        Text(
          modified
              ? 'Skipped intervals are saved in history. This day will not advance unless you explicitly choose to continue.'
              : status == 'completed'
              ? 'Scheduled workout completed. No distance was measured.'
              : 'Your attempt is saved. Repeat this session whenever you are ready.',
        ),
        if (status == 'completed') ...[
          TextField(
            controller: distanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Optional distance (km)',
              helperText: 'Self-reported; never measured by the app',
            ),
          ),
          TextButton(
            onPressed: () async {
              final km = double.tryParse(distanceController.text);
              if (km == null || !km.isFinite || km <= 0 || km > 200) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a distance above 0 and at most 200 km.',
                    ),
                  ),
                );
                return;
              }
              final ok = await store.command('reportedDistance', {
                'attemptId': r['attemptId'],
                'km': km,
              });
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Self-reported distance saved to history.'),
                  ),
                );
              }
            },
            child: const Text('Save reported distance'),
          ),
        ],
        if (status == 'modified')
          primary('Continue to next day', () async {
            if (await confirm(
              'Continue after a modified workout?',
              'Some prescribed time was skipped. Count this day toward your program and keep the skip details in history?',
            )) {
              if (await store.command('acceptModified', {
                'attemptId': r['attemptId'],
              })) {
                await store.command('dismiss');
              }
            }
          }),
        primary('Return to Home', () {
          distanceController.clear();
          store.command('dismiss');
        }),
        OutlinedButton(
          onPressed: () async {
            await store.command('dismiss');
            final p = store.program!;
            await start(p, r['index'] as int, mode: 'repeat');
          },
          child: const Text('Repeat Workout'),
        ),
      ],
      title('Week ${w['week']} · Day ${w['session']} · Full workout'),
      workoutBreakdown(w),
    ]);
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.onInitialize});
  final Future<void> Function(TrainingPlan) onInitialize;
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  RunningGoal goal = RunningGoal.fiveK;
  Ability ability = Ability.beginner;
  int weeks = 10;
  bool base = false, support = false;
  void recommend() => weeks = PlanGenerator.recommended(goal, ability);
  @override
  Widget build(BuildContext context) {
    final request = PlanRequest(
      goal: goal,
      ability: ability,
      weeks: weeks,
      baseReady: base,
      supportReady: support,
    );
    final issue = PlanGenerator.concern(request);
    final long = goal == RunningGoal.half || goal == RunningGoal.marathon;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'INITIALIZE TRAINING',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 16),
        Text(
          'Select your goal.\nAccept the defaults.\nStart running.',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        const Text('Running goal'),
        Wrap(
          spacing: 8,
          children: [
            for (final g in RunningGoal.values)
              ChoiceChip(
                label: Text(g.label),
                selected: g == goal,
                onSelected: (_) => setState(() {
                  goal = g;
                  base = false;
                  support = false;
                  recommend();
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<Ability>(
          isExpanded: true,
          initialValue: ability,
          decoration: const InputDecoration(labelText: 'Starting ability'),
          items: Ability.values
              .map(
                (a) => DropdownMenuItem(
                  value: a,
                  child: Text(a.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (a) => setState(() {
            ability = a!;
            base = false;
            support = false;
            recommend();
          }),
        ),
        const SizedBox(height: 8),
        Text(switch (ability) {
          Ability.beginner => 'I cannot comfortably run for five minutes.',
          Ability.intermediate => 'I can comfortably run approximately 5K.',
          Ability.experienced => 'I can comfortably run 10K or farther.',
        }),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          isExpanded: true,
          key: ValueKey(weeks),
          initialValue: weeks,
          decoration: const InputDecoration(
            labelText: 'Training timeline (weeks)',
          ),
          items:
              {
                    8,
                    10,
                    12,
                    15,
                    16,
                    18,
                    20,
                    24,
                    25,
                    28,
                    30,
                    32,
                    36,
                    40,
                    52,
                    60,
                    78,
                    104,
                    weeks,
                  }
                  .toList()
                  .map(
                    (n) => DropdownMenuItem(value: n, child: Text('$n weeks')),
                  )
                  .toList()
                ..sort((a, b) => a.value!.compareTo(b.value!)),
          onChanged: (n) => setState(() => weeks = n!),
        ),
        TextButton(
          onPressed: () async {
            final chosen = await showDialog<int>(
              context: context,
              builder: (_) => TimelineDialog(weeks: weeks),
            );
            if (chosen != null && mounted) setState(() => weeks = chosen);
          },
          child: const Text('Enter another number of weeks'),
        ),
        if (long) ...[
          const SizedBox(height: 16),
          Text(
            goal == RunningGoal.marathon
                ? 'Marathon prerequisites: experienced runner for at least a year; 25–35 km weekly for eight weeks; a recent comfortable 12–16 km long run.'
                : 'Half-marathon prerequisites: at least six weeks of consistent three-day running; comfortable 5K runs and a recent comfortable 8–10K outing.',
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('I meet the running-base prerequisites'),
            value: base,
            onChanged: (v) => setState(() => base = v!),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('I can include supporting activity and recovery'),
            value: support,
            onChanged: (v) => setState(() => support = v!),
          ),
          const Text(
            'Development curriculum: these screening checks do not guarantee race readiness. Independent coach review is pending.',
          ),
        ],
        const SizedBox(height: 16),
        if (issue != null) ...[
          Text(
            issue,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(
            onPressed: () => setState(() {
              goal = RunningGoal.fiveK;
              ability = Ability.beginner;
              weeks = 10;
              base = false;
              support = false;
            }),
            child: const Text('Use recommended 5K foundation'),
          ),
        ],
        Text(
          '${goal.label} · $weeks weeks · 3 workouts per week\nFirst workout: ${issue == null ? durationLabel(PlanGenerator.generate(request).workouts.first['seconds'] as int) : 'confirm an eligible plan'}',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: issue == null
              ? () => widget.onInitialize(PlanGenerator.generate(request))
              : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: const Text('INITIALIZE PROGRAM'),
        ),
        if (issue == null)
          ...workoutInstructions(PlanGenerator.generate(request).workouts.first)
              .map(
                (line) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(line),
                ),
              ),
        const SizedBox(height: 16),
        const Text(
          'Walk comfortably for 30 minutes before starting. Take rest days between beginner sessions. Stop if unwell or in pain. Timed workouts do not measure race distance.',
        ),
      ],
    );
  }
}
