import 'dart:isolate';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) async {
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    final prefs = await SharedPreferences.getInstance();
    final String? startStr = prefs.getString('start_time');
    if (startStr == null) return;

    final DateTime startTime = DateTime.parse(startStr);
    final int pausedMs = prefs.getInt('total_paused_duration_ms') ?? 0;
    final Duration totalPausedDuration = Duration(milliseconds: pausedMs);

    final bool isPaused = prefs.getBool('is_paused') ?? false;
    final String? pauseStartStr = prefs.getString('pause_start_time');
    final String? activeBreakType = prefs.getString('active_break_type');

    int activeBreakSeconds = 0;
    if (isPaused && pauseStartStr != null) {
      try {
        final DateTime pauseStartTime = DateTime.parse(pauseStartStr);
        activeBreakSeconds = DateTime.now().difference(pauseStartTime).inSeconds;
      } catch (_) {}
    }

    final DateTime now = DateTime.now();
    int elapsedSeconds =
        now.difference(startTime).inSeconds - (totalPausedDuration.inSeconds + activeBreakSeconds);
    if (elapsedSeconds < 0) elapsedSeconds = 0;

    final int goalHours = prefs.getInt('shift_goal_hours') ?? 8;
    final int goalMinutes = prefs.getInt('shift_goal_minutes') ?? 0;
    final int goalSeconds = prefs.getInt('shift_goal_seconds') ?? 0;
    final int totalGoalSeconds =
        goalHours * 3600 + goalMinutes * 60 + goalSeconds;

    int remainingSeconds = totalGoalSeconds - elapsedSeconds;
    if (remainingSeconds < 0) remainingSeconds = 0;

    final hours = (remainingSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((remainingSeconds % 3600) ~/ 60).toString().padLeft(
      2,
      '0',
    );
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

    final h = (elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');

    if (isPaused) {
      final breakHours = (activeBreakSeconds ~/ 3600).toString().padLeft(2, '0');
      final breakMinutes = ((activeBreakSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final breakSeconds = (activeBreakSeconds % 60).toString().padLeft(2, '0');

      FlutterForegroundTask.updateService(
        notificationTitle: 'On Break: ${activeBreakType ?? "Break"} ☕',
        notificationText: 'Break Time: $breakHours:$breakMinutes:$breakSeconds',
      );
    } else {
      FlutterForegroundTask.updateService(
        notificationTitle: remainingSeconds > 0
            ? 'Shift Countdown'
            : 'Shift Completed 🎉',
        notificationText: remainingSeconds > 0
            ? 'Time Left: $hours:$minutes:$seconds'
            : 'Total Work Time: $h:$m:$s',
      );
    }

    await prefs.setInt('current_elapsed_seconds', elapsedSeconds);
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) async {}
}

