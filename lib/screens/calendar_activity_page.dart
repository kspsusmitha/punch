import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarActivityPage extends StatefulWidget {
  final List<Map<String, dynamic>> activities;

  const CalendarActivityPage({super.key, required this.activities});

  @override
  State<CalendarActivityPage> createState() => _CalendarActivityPageState();
}

class _CalendarActivityPageState extends State<CalendarActivityPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _getActivitiesForDay(DateTime day) {
    return widget.activities.where((activity) {
      final dateString = activity['date'] as String?;
      if (dateString == null) return false;
      try {
        final date = DateTime.parse(dateString);
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final selectedActivities = _getActivitiesForDay(
      _selectedDay ?? _focusedDay,
    );
    final isUpcoming =
        _selectedDay != null &&
        _selectedDay!.isAfter(
          DateTime.now().copyWith(hour: 23, minute: 59, second: 59),
        );

    // Calculate Break Time
    int totalBreakSeconds = 0;
    final sortedActivities = List<Map<String, dynamic>>.from(selectedActivities)
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
        final bDate = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
        return aDate.compareTo(bDate);
      });

    DateTime? lastPauseTime;
    for (var act in sortedActivities) {
      final type = act['type'];
      final actDate = DateTime.tryParse(act['date'] ?? '');
      if (actDate == null) continue;

      if (type == 'Pause') {
        lastPauseTime = actDate;
      } else if (type == 'Resume' || type == 'Punch Out') {
        if (lastPauseTime != null) {
          totalBreakSeconds += actDate.difference(lastPauseTime).inSeconds;
          lastPauseTime = null;
        }
      }
    }
    
    if (lastPauseTime != null && _isSameDay(_selectedDay ?? _focusedDay, DateTime.now())) {
      totalBreakSeconds += DateTime.now().difference(lastPauseTime).inSeconds;
    }

    String formattedBreakTime = "00:00:00";
    {
      int h = totalBreakSeconds ~/ 3600;
      int m = (totalBreakSeconds % 3600) ~/ 60;
      int s = totalBreakSeconds % 60;
      formattedBreakTime = "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080C0A),
      appBar: AppBar(
        title: const Text(
          'Activity History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF050806), Color(0xFF0D1411), Color(0xFF080C0A)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111A16),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 30, color: Color(0xFF1ED760)),
                    onPressed: () {
                      setState(() {
                        _selectedDay = (_selectedDay ?? _focusedDay).subtract(const Duration(days: 1));
                        _focusedDay = _selectedDay!;
                      });
                    },
                  ),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('EEEE, d MMM yyyy').format(_selectedDay ?? _focusedDay),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 30, color: Color(0xFF1ED760)),
                    onPressed: () {
                      setState(() {
                        _selectedDay = (_selectedDay ?? _focusedDay).add(const Duration(days: 1));
                        _focusedDay = _selectedDay!;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: isUpcoming || selectedActivities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isUpcoming
                                ? 'No records found for upcoming date'
                                : 'No records found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Summary Card
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111A16),
                            borderRadius: BorderRadius.circular(16),
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
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5E3C).withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_active,
                                  color: Color(0xFF8B5E3C),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Break Time',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.5),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formattedBreakTime,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Text(
                          'Activity Logs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...selectedActivities.map((activity) {
                          final type = activity['type'] ?? 'Punch Out';
                          final act = activity['activity'] ?? '';
                          final isWork = type == 'Clock In' || type == 'Resume';
                          final itemColor = isWork ? const Color(0xFF1ED760) : const Color(0xFF8B5E3C);
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
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: itemColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    (type == 'Clock In')
                                        ? Icons.login
                                        : (act == 'Tea Break'
                                              ? Icons.coffee
                                              : (act == 'Lunch'
                                                    ? Icons.restaurant
                                                    : (type == 'Resume' ? Icons.play_arrow : Icons.exit_to_app))),
                                    color: itemColor,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        type,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        act,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  activity['time'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

