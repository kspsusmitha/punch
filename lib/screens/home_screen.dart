import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/task_handler.dart';
import 'calendar_activity_page.dart';
import 'edit_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool isClockedIn = false;

  Timer? _timer;
  DateTime? _startTime;
  Duration _totalPausedDuration = Duration.zero;
  DateTime? _pauseStartTime;
  DateTime? _logoutTime;
  bool _isPaused = false;
  List<Map<String, dynamic>> _activities = [];
  int _shiftGoalHours = 8;
  int _shiftGoalMinutes = 0;
  int _shiftGoalSeconds = 0;
  String _userName = 'Gifi';
  String _profileImagePath = 'assets/images/avatar_gifi.png';
  int _selectedDateOffset = 0;
  String? _activeBreakType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initForegroundTask();
    _loadUserProfile();
    _loadActivities();
    _loadStartTime();
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {}); // Refresh UI
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveTimerState();
    }
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'shift_tracker_channel',
        channelName: 'Shift Tracker Notification',
        channelDescription: 'Shows the active shift timer',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 1000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> _startForegroundTask() async {
    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        // This is optional but recommended
      }
    }

    // Check notification permission
    final NotificationPermission permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_elapsed_seconds', _elapsedTime.inSeconds);

    await FlutterForegroundTask.startService(
      notificationTitle: 'Shift Tracker Active',
      notificationText: 'Timer is running...',
      callback: startCallback,
    );
  }

  Future<void> _stopForegroundTask() async {
    await FlutterForegroundTask.stopService();
  }

  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Gifi';
        _profileImagePath =
            prefs.getString('profile_image_path') ??
            'assets/images/avatar_gifi.png';
      });
    } catch (_) {}
  }

  Future<void> _loadActivities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int savedGoalHours = prefs.getInt('shift_goal_hours') ?? 8;
      final int savedGoalMinutes = prefs.getInt('shift_goal_minutes') ?? 0;
      final int savedGoalSeconds = prefs.getInt('shift_goal_seconds') ?? 0;
      final String? activitiesJson = prefs.getString('logged_activities');
      if (activitiesJson != null) {
        final List<dynamic> decoded = json.decode(activitiesJson);
        setState(() {
          _shiftGoalHours = savedGoalHours;
          _shiftGoalMinutes = savedGoalMinutes;
          _shiftGoalSeconds = savedGoalSeconds;
          _activities = decoded
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      } else {
        setState(() {
          _shiftGoalHours = savedGoalHours;
          _shiftGoalMinutes = savedGoalMinutes;
          _shiftGoalSeconds = savedGoalSeconds;
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadStartTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? startStr = prefs.getString('start_time');

      if (startStr != null) {
        final DateTime savedStart = DateTime.parse(startStr);
        final DateTime now = DateTime.now();
        // If the saved start time is from a different day, reset current shift state
        if (savedStart.year != now.year ||
            savedStart.month != now.month ||
            savedStart.day != now.day) {
          await _resetCurrentShift(clearActivities: false);
          return;
        }
        _startTime = savedStart;
      }

      setState(() {
        isClockedIn = prefs.getBool('is_clocked_in') ?? false;
        _isPaused = prefs.getBool('is_paused') ?? false;
        _activeBreakType = prefs.getString('active_break_type');

        final String? pauseStartStr = prefs.getString('pause_start_time');
        if (pauseStartStr != null) {
          _pauseStartTime = DateTime.parse(pauseStartStr);
        }

        final String? logoutStr = prefs.getString('logout_time');
        if (logoutStr != null) _logoutTime = DateTime.parse(logoutStr);

        final int pausedMs = prefs.getInt('total_paused_duration_ms') ?? 0;
        _totalPausedDuration = Duration(milliseconds: pausedMs);
      });
    } catch (_) {}
  }

  Future<void> _resetCurrentShift({bool clearActivities = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_clocked_in');
      await prefs.remove('is_paused');
      await prefs.remove('start_time');
      await prefs.remove('pause_start_time');
      await prefs.remove('logout_time');
      await prefs.remove('total_paused_duration_ms');
      await prefs.remove('current_elapsed_seconds');
      await prefs.remove('active_break_type');

      if (clearActivities) {
        // Only remove activities for the current day
        _activities.removeWhere((a) => _isSameDate(a['date'] as String?, 0));
        await _saveActivitiesToPrefs();
      }

      setState(() {
        isClockedIn = false;
        _isPaused = false;
        _startTime = null;
        _pauseStartTime = null;
        _logoutTime = null;
        _totalPausedDuration = Duration.zero;
        _activeBreakType = null;
      });

      await _stopForegroundTask();
    } catch (_) {}
  }

  Future<void> _saveTimerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_clocked_in', isClockedIn);
      await prefs.setBool('is_paused', _isPaused);

      if (_startTime != null) {
        await prefs.setString('start_time', _startTime!.toIso8601String());
      } else {
        await prefs.remove('start_time');
      }

      if (_pauseStartTime != null) {
        await prefs.setString(
          'pause_start_time',
          _pauseStartTime!.toIso8601String(),
        );
      } else {
        await prefs.remove('pause_start_time');
      }

      if (_logoutTime != null) {
        await prefs.setString('logout_time', _logoutTime!.toIso8601String());
      } else {
        await prefs.remove('logout_time');
      }

      await prefs.setInt(
        'total_paused_duration_ms',
        _totalPausedDuration.inMilliseconds,
      );

      if (_activeBreakType != null) {
        await prefs.setString('active_break_type', _activeBreakType!);
      } else {
        await prefs.remove('active_break_type');
      }
    } catch (_) {}
  }

  Future<void> _saveActivity(
    String type,
    String activity, {
    DateTime? customTime,
  }) async {
    final timeToUse = customTime ?? DateTime.now();
    final String formattedTime = _formatTime(timeToUse);

    final newActivity = {
      "type": type,
      "activity": activity,
      "time": formattedTime,
      "date": timeToUse.toIso8601String(),
      "elapsed_seconds": _elapsedTime.inSeconds,
    };

    setState(() {
      _activities.insert(0, newActivity);
    });

    await _saveActivitiesToPrefs();
  }

  Future<void> _saveActivitiesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String activitiesJson = json.encode(_activities);
      await prefs.setString('logged_activities', activitiesJson);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _editLoginTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      final now = DateTime.now().add(Duration(days: _selectedDateOffset));
      final newDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );
      final formatted = _formatTime(newDateTime);

      setState(() {
        if (_selectedDateOffset == 0) {
          _startTime = newDateTime;
        }

        final index = _activities.indexWhere(
          (a) =>
              a['type'] == 'Clock In' &&
              _isSameDate(a['date'] as String?, _selectedDateOffset),
        );
        if (index != -1) {
          _activities[index]['time'] = formatted;
          // Update the date field as well for data consistency
          _activities[index]['date'] = newDateTime.toIso8601String();
        }
      });
      _saveActivitiesToPrefs();
      _saveTimerState(); // Persist the new start time for the timer and background service
    }
  }

  void _showPunchOutOptionsDialog() {
    String selectedActivity = 'Tea Break';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111A16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Select Punch Out Reason',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildRadioOption(
                    'Tea Break',
                    selectedActivity,
                    setModalState,
                    (val) {
                      setModalState(() {
                        selectedActivity = val;
                      });
                    },
                    Icons.coffee,
                  ),
                  _buildRadioOption('Lunch', selectedActivity, setModalState, (
                    val,
                  ) {
                    setModalState(() {
                      selectedActivity = val;
                    });
                  }, Icons.restaurant),
                  _buildRadioOption(
                    'Emergency',
                    selectedActivity,
                    setModalState,
                    (val) {
                      setModalState(() {
                        selectedActivity = val;
                      });
                    },
                    Icons.emergency_outlined,
                  ),
                  _buildRadioOption('Leave', selectedActivity, setModalState, (
                    val,
                  ) {
                    setModalState(() {
                      selectedActivity = val;
                    });
                  }, Icons.directions_run),
                  _buildRadioOption(
                    'End Shift',
                    selectedActivity,
                    setModalState,
                    (val) {
                      setModalState(() {
                        selectedActivity = val;
                      });
                    },
                    Icons.power_settings_new,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5E3C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmPunchOut(selectedActivity);
                      },
                      child: const Text(
                        'Confirm Punch Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRadioOption(
    String title,
    String current,
    StateSetter setModalState,
    ValueChanged<String> onChanged,
    IconData icon,
  ) {
    final isSelected = title == current;
    return GestureDetector(
      onTap: () {
        onChanged(title);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8B5E3C).withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5E3C) : Colors.white.withOpacity(0.05),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? const Color(0xFF8B5E3C) : Colors.white.withOpacity(0.5),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF8B5E3C)
                        : Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF8B5E3C) : Colors.white.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmPunchOut(String activityType) {
    if (activityType == 'End Shift') {
      _saveActivity('Punch Out', 'End of Shift');
      setState(() {
        isClockedIn = false;
        _activeBreakType = null;
        if (_isPaused) {
          _logoutTime = _pauseStartTime ?? DateTime.now();
          _isPaused = false;
          _pauseStartTime = null;
        } else {
          _logoutTime = DateTime.now();
        }
      });
      _stopForegroundTask();
      _saveTimerState();
    } else {
      // It's a break (Tea Break, Lunch, Emergency, Leave)
      _saveActivity('Pause', activityType);
      setState(() {
        _isPaused = true;
        _pauseStartTime = DateTime.now();
        _activeBreakType = activityType;
      });
      _saveTimerState();
    }
  }

  void _resumeShift() {
    if (_pauseStartTime != null) {
      _totalPausedDuration += DateTime.now().difference(_pauseStartTime!);
    }
    setState(() {
      _isPaused = false;
      _pauseStartTime = null;
      _activeBreakType = null;
    });
    _saveActivity('Resume', 'Resumed Work');
    _saveTimerState();
  }

  Widget _buildGoalRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 36),
            color: Colors.white.withOpacity(0.5),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 90,
            child: Text(
              '$value $label',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 36),
            color: const Color(0xFF1ED760),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  void _showShiftGoalDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111A16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
              ),
              title: const Text(
                'Edit Shift Goal',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGoalRow(
                    label: 'Hrs',
                    value: _shiftGoalHours,
                    min: 0,
                    max: 24,
                    onChanged: (val) {
                      setDialogState(() {
                        _shiftGoalHours = val;
                      });
                      setState(() {});
                      _saveShiftGoal();
                    },
                  ),
                  _buildGoalRow(
                    label: 'Min',
                    value: _shiftGoalMinutes,
                    min: 0,
                    max: 59,
                    onChanged: (val) {
                      setDialogState(() {
                        _shiftGoalMinutes = val;
                      });
                      setState(() {});
                      _saveShiftGoal();
                    },
                  ),
                  _buildGoalRow(
                    label: 'Sec',
                    value: _shiftGoalSeconds,
                    min: 0,
                    max: 59,
                    onChanged: (val) {
                      setDialogState(() {
                        _shiftGoalSeconds = val;
                      });
                      setState(() {});
                      _saveShiftGoal();
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1ED760),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveShiftGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('shift_goal_hours', _shiftGoalHours);
      await prefs.setInt('shift_goal_minutes', _shiftGoalMinutes);
      await prefs.setInt('shift_goal_seconds', _shiftGoalSeconds);
    } catch (_) {}
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && (isClockedIn || _startTime != null)) {
        setState(() {});
      }
    });
  }

  bool _isSameDate(String? dateString, int offset) {
    if (dateString == null) return false;
    try {
      final date = DateTime.parse(dateString);
      final targetDate = DateTime.now().add(Duration(days: offset));
      return date.year == targetDate.year &&
          date.month == targetDate.month &&
          date.day == targetDate.day;
    } catch (_) {
      return false;
    }
  }

  Duration get _elapsedTime {
    if (_startTime == null) return Duration.zero;

    // Safety check: if _startTime is not from today, return zero
    final now = DateTime.now();
    if (_startTime!.year != now.year ||
        _startTime!.month != now.month ||
        _startTime!.day != now.day) {
      return Duration.zero;
    }

    DateTime current;
    if (!isClockedIn && _logoutTime != null) {
      current = _logoutTime!;
    } else if (_isPaused && _pauseStartTime != null) {
      current = _pauseStartTime!;
    } else {
      current = DateTime.now();
    }

    Duration elapsed = current.difference(_startTime!) - _totalPausedDuration;
    if (elapsed.isNegative) return Duration.zero;

    return elapsed;
  }

  String _formatDurationSeconds(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  Duration get _displayDuration {
    if (_selectedDateOffset == 0) return _elapsedTime;

    final dayActivities = _activities
        .where((a) => _isSameDate(a['date'] as String?, _selectedDateOffset))
        .toList();

    if (dayActivities.isEmpty) return Duration.zero;

    int maxSeconds = 0;
    for (var a in dayActivities) {
      final s = a['elapsed_seconds'] as int? ?? 0;
      if (s > maxSeconds) maxSeconds = s;
    }
    return Duration(seconds: maxSeconds);
  }

  String get _formattedTime {
    if (!isClockedIn && _selectedDateOffset == 0) {
      return "00:00:00";
    }
    Duration duration = _displayDuration;
    String hours = duration.inHours.toString().padLeft(2, '0');
    String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  double get _progressValue {
    double totalSeconds =
        _shiftGoalHours * 3600.0 + _shiftGoalMinutes * 60.0 + _shiftGoalSeconds;
    if (totalSeconds <= 0) return 0.0;
    return (_displayDuration.inSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  String get _formattedRemainingTime {
    Duration elapsed = _displayDuration;
    Duration total = Duration(
      hours: _shiftGoalHours,
      minutes: _shiftGoalMinutes,
      seconds: _shiftGoalSeconds,
    );
    Duration remaining = total - elapsed;

    if (remaining.isNegative) {
      return "00:00";
    }

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(remaining.inHours);
    String minutes = twoDigits(remaining.inMinutes.remainder(60));

    return "$hours:$minutes";
  }

  Duration get _effectiveBreakDuration {
    Duration breakTime = _totalPausedDuration;
    if (_isPaused && _pauseStartTime != null) {
      breakTime += DateTime.now().difference(_pauseStartTime!);
    }
    return breakTime;
  }

  String get _formattedBreakTime {
    Duration breakTime = _effectiveBreakDuration;

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(breakTime.inHours);
    String minutes = twoDigits(breakTime.inMinutes.remainder(60));
    String seconds = twoDigits(breakTime.inSeconds.remainder(60));

    return "$hours:$minutes:$seconds";
  }

  String _formatTime(
    DateTime? time, {
    bool lowerCaseAmPm = false,
    bool spaceBeforeAmPm = true,
  }) {
    if (time == null) return '--:--';
    String hour =
        (time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour))
            .toString()
            .padLeft(2, '0');
    String minute = time.minute.toString().padLeft(2, '0');
    String ampm = time.hour >= 12 ? 'PM' : 'AM';
    if (lowerCaseAmPm) ampm = ampm.toLowerCase();
    String space = spaceBeforeAmPm ? ' ' : '';
    return '$hour:$minute$space$ampm';
  }

  String _getMonthYearString() {
    final date = DateTime.now().add(Duration(days: _selectedDateOffset));
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning 👋';
    } else if (hour < 17) {
      return 'Good Afternoon ☀️';
    } else {
      return 'Good Evening 🌙';
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime? expectedOutTime = _startTime
        ?.add(
          Duration(
            hours: _shiftGoalHours,
            minutes: _shiftGoalMinutes,
            seconds: _shiftGoalSeconds,
          ),
        )
        .add(_effectiveBreakDuration);

    return Scaffold(
      backgroundColor: const Color(0xFF080C0A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF050806), Color(0xFF0D1411), Color(0xFF080C0A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfileScreen(
                              currentName: _userName,
                              currentImagePath: _profileImagePath,
                            ),
                          ),
                        );
                        if (result != null && result is Map) {
                          setState(() {
                            _userName = result['name'] as String;
                            _profileImagePath = result['imagePath'] as String;
                          });
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('user_name', _userName);
                          await prefs.setString(
                            'profile_image_path',
                            _profileImagePath,
                          );

                          final empId = prefs.getString('employee_id');
                          if (empId != null) {
                            try {
                              final ref = FirebaseDatabase.instance.ref('employees/$empId/profile');
                              await ref.update({
                                'user_name': _userName,
                                'profile_image_path': _profileImagePath,
                              });
                            } catch (e) {
                              debugPrint('Failed to save profile to RTDB: $e');
                            }
                          }
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: _profileImagePath.startsWith('data:image')
                                ? MemoryImage(base64Decode(_profileImagePath.split(',').last)) as ImageProvider
                                : _profileImagePath.startsWith('http')
                                    ? NetworkImage(_profileImagePath) as ImageProvider
                                    : _profileImagePath.startsWith('assets/')
                                        ? AssetImage(_profileImagePath) as ImageProvider
                                        : (kIsWeb ? NetworkImage(_profileImagePath) : FileImage(File(_profileImagePath))) as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi $_userName !',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _getGreeting(),
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Month & Year Indication
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Text(
                      _getMonthYearString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Date Strip
              SizedBox(
                height: 85,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: List.generate(43, (index) {
                    final offset = index - 2;
                    final date = DateTime.now().add(Duration(days: offset));
                    final dayStr = date.day.toString().padLeft(2, '0');
                    const weekDays = [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ];
                    final weekDayStr = weekDays[date.weekday - 1];
                    final isSelected = offset == _selectedDateOffset;
                    final isFuture = offset > 0;
                    return GestureDetector(
                      onTap: isFuture
                          ? null
                          : () {
                              setState(() {
                                _selectedDateOffset = offset;
                              });
                            },
                      child: _buildDateItem(
                        dayStr,
                        weekDayStr,
                        isSelected,
                        isDisabled: isFuture,
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 15),

              // Login Time & Shift Goal
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: isClockedIn ? null : _editLoginTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isClockedIn
                                ? Colors.white.withOpacity(0.04)
                                : const Color(0xFF17241E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Login Time:',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Builder(
                                builder: (context) {
                                  final clockIn = _activities.firstWhere(
                                    (a) =>
                                        a['type'] == 'Clock In' &&
                                        _isSameDate(
                                          a['date'] as String?,
                                          _selectedDateOffset,
                                        ),
                                    orElse: () => {},
                                  );
                                  String timeStr = '--:--';
                                  if (clockIn.containsKey('time')) {
                                    timeStr = clockIn['time'] as String;
                                  } else if (_selectedDateOffset == 0 &&
                                      _startTime != null) {
                                    timeStr = _formatTime(_startTime);
                                  }
                                  return Text(
                                    timeStr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isClockedIn
                                          ? Colors.white.withOpacity(0.4)
                                          : const Color(0xFF1ED760),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _showShiftGoalDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF17241E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  'Shift Goal:',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_shiftGoalHours.toString().padLeft(2, '0')}:${_shiftGoalMinutes.toString().padLeft(2, '0')}:${_shiftGoalSeconds.toString().padLeft(2, '0')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Dashboard scroll area
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Total Working Hours Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111A16),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Builder(
                              builder: (context) {
                                final screenWidth = MediaQuery.of(
                                  context,
                                ).size.width;
                                final isSmallScreen = screenWidth <= 360;
                                // Calculation: screenWidth - 40 (ScrollView horizontal padding) - 48 (Card horizontal padding) = 88
                                final availableWidth = screenWidth - 88;

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // LEFT SIDE: Title + Status
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Total Working Hours',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 14 : 16,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          // Status Indicator
                                          Builder(
                                            builder: (context) {
                                              Color statusColor;
                                              String statusText;
                                              if (!isClockedIn) {
                                                statusColor = Colors.white.withOpacity(0.4);
                                                statusText = "Not Working";
                                              } else if (_isPaused) {
                                                statusColor = const Color(
                                                  0xFF8B5E3C,
                                                );
                                                statusText = "Paused";
                                              } else {
                                                statusColor = const Color(
                                                  0xFF1ED760,
                                                );
                                                statusText = "Working";
                                              }
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: statusColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    statusText,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // RIGHT SIDE: Status + Icon
                                    SizedBox(
                                      width: isSmallScreen
                                          ? availableWidth * 0.50
                                          : availableWidth * 0.45,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              mainAxisSize: MainAxisSize.min,
                                              children:
                                                  _displayDuration >=
                                                      Duration(
                                                        hours: _shiftGoalHours,
                                                        minutes:
                                                            _shiftGoalMinutes,
                                                        seconds:
                                                            _shiftGoalSeconds,
                                                      )
                                                  ? [
                                                      Text(
                                                        'Shift Completed',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize:
                                                              isSmallScreen
                                                              ? 14
                                                              : 16,
                                                          color: const Color(0xFF1ED760),
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                        textAlign:
                                                            TextAlign.right,
                                                      ),
                                                    ]
                                                  : (!isClockedIn &&
                                                        _displayDuration
                                                                .inSeconds >
                                                            0)
                                                  ? [
                                                      Text(
                                                        'Shift Incomplete',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize:
                                                              isSmallScreen
                                                              ? 14
                                                              : 16,
                                                          color: const Color(0xFF8B5E3C),
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                        textAlign:
                                                            TextAlign.right,
                                                      ),
                                                    ]
                                                  : [
                                                      Text(
                                                        'Expected Out',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.white.withOpacity(0.5),
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        textAlign:
                                                            TextAlign.right,
                                                      ),
                                                      Text(
                                                        _formatTime(
                                                          expectedOutTime,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize:
                                                              isSmallScreen
                                                              ? 14
                                                              : 16,
                                                          color: const Color(0xFF1ED760),
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                        textAlign:
                                                            TextAlign.right,
                                                      ),
                                                    ],
                                            ),
                                          ),
                                          if (_displayDuration.inSeconds > 0 &&
                                              (!isClockedIn ||
                                                  _displayDuration >=
                                                      Duration(
                                                        hours: _shiftGoalHours,
                                                        minutes:
                                                            _shiftGoalMinutes,
                                                        seconds:
                                                            _shiftGoalSeconds,
                                                      ))) ...[
                                            SizedBox(
                                              width: isSmallScreen ? 6 : 8,
                                            ),
                                            GestureDetector(
                                              onTap: () => _resetCurrentShift(
                                                clearActivities: true,
                                              ),
                                              child: Icon(
                                                Icons.refresh,
                                                color: const Color(0xFF8B5E3C),
                                                size: isSmallScreen ? 18 : 22,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 15),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _formattedTime,
                                  style: const TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                  ),
                                ),
                                if (isClockedIn) ...[
                                  const SizedBox(width: 14),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF8B5E3C),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.refresh,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _resetCurrentShift(
                                          clearActivities: true,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 20),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _progressValue,
                                minHeight: 12,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _progressValue >= 1.0
                                      ? const Color(0xFF1ED760)
                                      : const Color(0xFF2C6B46),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Break & Remaining
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111A16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5E3C).withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.notifications_active,
                                      color: Color(0xFF8B5E3C),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Break Time',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(0.5),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formattedBreakTime,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111A16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1ED760).withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.hourglass_empty,
                                      color: Color(0xFF1ED760),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Remaining',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(0.5),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formattedRemainingTime,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Recent Activity
                      Builder(
                        builder: (context) {
                          final screenWidth = MediaQuery.of(context).size.width;
                          final availableWidth =
                              screenWidth - 40; // ScrollView padding
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: availableWidth * 0.6,
                                child: const Text(
                                  'Recent Activity',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: availableWidth * 0.35,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CalendarActivityPage(
                                                activities: _activities,
                                              ),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'View All',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFF1ED760),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),

                      // Activity Items
                      Builder(
                        builder: (context) {
                          final filtered = _activities
                              .where(
                                (a) => _isSameDate(
                                  a['date'] as String?,
                                  _selectedDateOffset,
                                ),
                              )
                              .toList();

                          if (filtered.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'No entry found',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: filtered.map((activity) {
                              final type = activity['type'] ?? 'Punch Out';
                              final act = activity['activity'] ?? '';
                              final isWork = type == 'Clock In' || type == 'Resume';
                              final itemColor = isWork ? const Color(0xFF1ED760) : const Color(0xFF8B5E3C);
                              return _buildActivityItem(
                                type,
                                act,
                                activity['time'] ?? '',
                                (type == 'Clock In')
                                    ? Icons.login
                                    : (act == 'Tea Break'
                                          ? Icons.coffee
                                          : (act == 'Lunch'
                                                ? Icons.restaurant
                                                : (type == 'Resume' ? Icons.play_arrow : Icons.exit_to_app))),
                                itemColor,
                                duration:
                                    activity.containsKey('elapsed_seconds')
                                    ? _formatDurationSeconds(
                                        activity['elapsed_seconds'] as int,
                                      )
                                    : null,
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 100), // space for bottom buttons
                    ],
                  ),
                ),
              ),

              // Bottom Buttons
              Builder(
                builder: (context) {
                  final bool isDisabled = _selectedDateOffset != 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    color: Colors.transparent,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      child: isClockedIn
                          ? (_isPaused
                                ? GestureDetector(
                                    key: const ValueKey('resume_btn'),
                                    onTap: isDisabled ? null : _resumeShift,
                                    child: Container(
                                      height: 56,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: isDisabled
                                            ? Colors.grey
                                            : const Color(0xFF2C6B46),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                (isDisabled
                                                        ? Colors.grey
                                                        : const Color(
                                                            0xFF2C6B46,
                                                          ))
                                                    .withOpacity(0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Resume Work',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : GestureDetector(
                                    key: const ValueKey('punch_out_btn'),
                                    onTap: (isDisabled || _progressValue >= 1.0)
                                        ? null
                                        : _showPunchOutOptionsDialog,
                                    child: Container(
                                      height: 56,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: isDisabled
                                            ? Colors.grey
                                            : (_progressValue >= 1.0
                                                  ? const Color(0xFF1ED760)
                                                  : const Color(0xFF8B5E3C)),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                (isDisabled
                                                        ? Colors.grey
                                                        : (_progressValue >= 1.0
                                                              ? const Color(0xFF1ED760)
                                                              : const Color(
                                                                  0xFF8B5E3C,
                                                                )))
                                                    .withOpacity(0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _progressValue >= 1.0
                                                ? Icons.check_circle
                                                : Icons.pause,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _progressValue >= 1.0
                                                ? 'Shift completed'
                                                : 'Take Break / End Shift',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ))
                          : GestureDetector(
                              key: const ValueKey('punch_in_btn'),
                              onTap: isDisabled
                                  ? null
                                  : () {
                                      setState(() {
                                        _startTime ??= DateTime.now();
                                        isClockedIn = true;
                                        if (_logoutTime != null) {
                                          _totalPausedDuration += DateTime.now()
                                              .difference(_logoutTime!);
                                          _logoutTime = null;
                                        }
                                        _isPaused = false;
                                        _pauseStartTime = null;
                                      });
                                      _saveActivity(
                                        'Clock In',
                                        'Start of Shift',
                                        customTime: _startTime,
                                      );
                                      _startForegroundTask();
                                      _saveTimerState();
                                    },
                              child: Container(
                                height: 56,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDisabled
                                      ? Colors.grey
                                      : const Color(0xFF2C6B46),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (isDisabled
                                                  ? Colors.grey
                                                  : const Color(0xFF2C6B46))
                                              .withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Punch In',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateItem(
    String dayNum,
    String dayStr,
    bool isSelected, {
    bool isDisabled = false,
  }) {
    return Opacity(
      opacity: isDisabled ? 0.3 : 1.0,
      child: Container(
        width: 55,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2C6B46)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2C6B46).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayNum,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
            Text(
              dayStr,
              style: TextStyle(
                color: isSelected ? Colors.white.withOpacity(0.85) : Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    String time,
    IconData icon,
    Color iconColor, {
    String? duration,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111A16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (duration != null) ...[
                const SizedBox(height: 2),
                Text(
                  duration,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

