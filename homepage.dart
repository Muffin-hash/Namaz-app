import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'auth.dart';

// --- Prayer Status Enum ---
enum PrayerStatus { passed, active, upcoming }

// --- Data Model ---
class PrayerTime {
  final String name;
  final String time;
  final IconData icon;
  final int durationMinutes;

  PrayerTime({
    required this.name,
    required this.time,
    required this.icon,
    required this.durationMinutes,
  });
}

// --- Main Page ---
class NamazTimingPage extends StatefulWidget {
  const NamazTimingPage({super.key});

  @override
  State<NamazTimingPage> createState() => _NamazTimingPageState();
}

class _NamazTimingPageState extends State<NamazTimingPage>
    with SingleTickerProviderStateMixin {
  List<PrayerTime> _prayers = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _timer;
  Map<int, PrayerStatus> _statuses = {};
  int? _activePrayerIndex;
  int? _nextPrayerIndex;
  Duration _timeLeft = Duration.zero;
  String _statusMessage = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
    _fetchLocationAndData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationAndData() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = "Location services are disabled. Please enable GPS.";
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _errorMessage =
              "Location permission is required to get accurate Namaz times.";
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _fetchPrayerTimes(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to get location. Please ensure GPS is enabled.";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPrayerTimes(double lat, double lon) async {
    final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String url =
        'https://api.aladhan.com/v1/timings/$timestamp?latitude=$lat&longitude=$lon&method=2';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Map<String, dynamic> timings = data['data']['timings'];

        setState(() {
          _prayers = [
            PrayerTime(
              name: "Fajr",
              time: timings['Fajr'],
              icon: Icons.dark_mode_outlined,
              durationMinutes: 25,
            ),
            PrayerTime(
              name: "Dhuhr",
              time: timings['Dhuhr'],
              icon: Icons.wb_sunny_outlined,
              durationMinutes: 30,
            ),
            PrayerTime(
              name: "Asr",
              time: timings['Asr'],
              icon: Icons.cloud_outlined,
              durationMinutes: 30,
            ),
            PrayerTime(
              name: "Maghrib",
              time: timings['Maghrib'],
              icon: Icons.nights_stay_outlined,
              durationMinutes: 20,
            ),
            PrayerTime(
              name: "Isha",
              time: timings['Isha'],
              icon: Icons.bedtime_outlined,
              durationMinutes: 30,
            ),
          ];
          _updateAllStatuses();
          _startCountdownTimer();
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load prayer times");
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to fetch data. Check your internet connection.";
        _isLoading = false;
      });
    }
  }

  void _updateAllStatuses() {
    if (_prayers.isEmpty) return;

    final now = DateTime.now();
    final currentSeconds = now.hour * 3600 + now.minute * 60 + now.second;

    _activePrayerIndex = null;
    _nextPrayerIndex = null;

    for (int i = 0; i < _prayers.length; i++) {
      final parts = _prayers[i].time.split(':');
      final prayerSeconds =
          int.parse(parts[0]) * 3600 + int.parse(parts[1]) * 60;
      final endSeconds = prayerSeconds + (_prayers[i].durationMinutes * 60);

      if (currentSeconds >= prayerSeconds && currentSeconds < endSeconds) {
        _statuses[i] = PrayerStatus.active;
        _activePrayerIndex = i;
      } else if (currentSeconds >= endSeconds) {
        _statuses[i] = PrayerStatus.passed;
      } else {
        _statuses[i] = PrayerStatus.upcoming;
        if (_nextPrayerIndex == null) {
          _nextPrayerIndex = i;
        }
      }
    }

    if (_nextPrayerIndex == null) {
      _nextPrayerIndex = 0;
    }

    _updateStatusMessageAndTime();
  }

  void _updateStatusMessageAndTime() {
    final now = DateTime.now();

    if (_activePrayerIndex != null) {
      final parts = _prayers[_activePrayerIndex!].time.split(':');
      DateTime endTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      ).add(Duration(minutes: _prayers[_activePrayerIndex!].durationMinutes));

      _timeLeft = endTime.difference(now);
      _statusMessage = "It's time for ${_prayers[_activePrayerIndex!].name}!";
    } else if (_nextPrayerIndex != null) {
      final parts = _prayers[_nextPrayerIndex!].time.split(':');
      DateTime nextTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      if (nextTime.isBefore(now) || nextTime.isAtSameMomentAs(now)) {
        if (_nextPrayerIndex == 0) {
          nextTime = nextTime.add(const Duration(days: 1));
        }
      }

      _timeLeft = nextTime.difference(now);
      _statusMessage = "Next: ${_prayers[_nextPrayerIndex!].name} in";
    }
  }

  void _startCountdownTimer() {
    _updateAllStatuses();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _updateAllStatuses();
      });
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00:00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  String _getStatusText(PrayerStatus status, int index) {
    switch (status) {
      case PrayerStatus.active:
        return "Pray Now • ${_formatDuration(_timeLeft).substring(0, 5)} left";
      case PrayerStatus.passed:
        return "Completed";
      case PrayerStatus.upcoming:
        final now = DateTime.now();
        final parts = _prayers[index].time.split(':');
        DateTime prayerTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        if (prayerTime.isBefore(now)) {
          prayerTime = prayerTime.add(const Duration(days: 1));
        }
        final diff = prayerTime.difference(now);
        return "in ${_formatDuration(diff).substring(0, 5)}";
    }
  }

  Color _getStatusColor(PrayerStatus status) {
    switch (status) {
      case PrayerStatus.active:
        return const Color(0xFF4CAF50);
      case PrayerStatus.passed:
        return Colors.grey;
      case PrayerStatus.upcoming:
        return const Color(0xFF64B5F6);
    }
  }

  IconData _getStatusIcon(PrayerStatus status) {
    switch (status) {
      case PrayerStatus.active:
        return Icons.notifications_active;
      case PrayerStatus.passed:
        return Icons.check_circle;
      case PrayerStatus.upcoming:
        return Icons.schedule;
    }
  }

  double _getPrayerProgress() {
    if (_activePrayerIndex == null) return 0.0;

    final now = DateTime.now();
    final parts = _prayers[_activePrayerIndex!].time.split(':');
    DateTime startTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    final totalDuration = Duration(
      minutes: _prayers[_activePrayerIndex!].durationMinutes,
    );
    final elapsed = now.difference(startTime);

    if (elapsed.isNegative) return 0.0;
    if (elapsed > totalDuration) return 1.0;
    return elapsed.inSeconds / totalDuration.inSeconds;
  }

  // Logout function
  Future<void> _logout() async {
    await AuthService.deleteToken();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF1A2332);
    const cardColor = Color(0xFF243447);
    const accentColor = Color(0xFFD4AF37);
    const activeGreen = Color(0xFF4CAF50);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          "Prayer Timings",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = '';
              });
              _fetchLocationAndData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: accentColor),
                )
              : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _errorMessage = '';
                                _isLoading = true;
                              });
                              _fetchLocationAndData();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 30),

                        // --- Status Card ---
                        _buildStatusCard(
                          accentColor: accentColor,
                          activeGreen: activeGreen,
                        ),
                        const SizedBox(height: 25),

                        // --- Column Headers ---
                        const Row(
                          children: [
                            SizedBox(width: 50),
                            Expanded(
                              child: Text(
                                "Prayer",
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                "Time",
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(
                              width: 130,
                              child: Text(
                                "Status",
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.grey, height: 20),

                        // --- Prayer List ---
                        Expanded(
                          child: ListView.builder(
                            itemCount: _prayers.length,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final prayer = _prayers[index];
                              final status =
                                  _statuses[index] ?? PrayerStatus.upcoming;
                              final isActive = status == PrayerStatus.active;
                              final isPassed = status == PrayerStatus.passed;

                              return _buildPrayerRow(
                                index: index,
                                prayer: prayer,
                                status: status,
                                isActive: isActive,
                                isPassed: isPassed,
                                cardColor: cardColor,
                                accentColor: accentColor,
                                activeGreen: activeGreen,
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            "Updated: ${DateFormat('hh:mm:ss a').format(DateTime.now())}",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  // --- Status Card ---
  Widget _buildStatusCard({
    required Color accentColor,
    required Color activeGreen,
  }) {
    final hasActive = _activePrayerIndex != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: hasActive
            ? activeGreen.withOpacity(0.12)
            : accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasActive ? activeGreen : accentColor,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasActive ? Icons.mosque : Icons.timer_outlined,
                color: hasActive ? activeGreen : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _statusMessage,
                style: TextStyle(
                  color: hasActive ? activeGreen : Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (hasActive)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeGreen.withOpacity(
                              0.3 + _pulseAnimation.value * 0.7,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    const SizedBox(width: 14, height: 14),
                  const SizedBox(width: 12),
                  Text(
                    _activePrayerIndex != null
                        ? _prayers[_activePrayerIndex!].name
                        : _prayers[_nextPrayerIndex!].name,
                    style: TextStyle(
                      color: hasActive ? activeGreen : accentColor,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                _formatDuration(_timeLeft),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          if (hasActive) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _getPrayerProgress(),
              backgroundColor: activeGreen.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(activeGreen),
              borderRadius: BorderRadius.circular(10),
              minHeight: 6,
            ),
            const SizedBox(height: 4),
            Text(
              "${(_getPrayerProgress() * 100).toStringAsFixed(0)}% of prayer time elapsed",
              style: TextStyle(
                color: activeGreen.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Prayer Row ---
  Widget _buildPrayerRow({
    required int index,
    required PrayerTime prayer,
    required PrayerStatus status,
    required bool isActive,
    required bool isPassed,
    required Color cardColor,
    required Color accentColor,
    required Color activeGreen,
  }) {
    final statusColor = _getStatusColor(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isActive
            ? activeGreen.withOpacity(0.08)
            : isPassed
                ? Colors.transparent
                : cardColor,
        borderRadius: BorderRadius.circular(15),
        border: isActive
            ? Border.all(color: activeGreen.withOpacity(0.4), width: 1)
            : null,
      ),
      child: Row(
        children: [
          // Icon box
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? activeGreen.withOpacity(0.15)
                  : isPassed
                      ? Colors.grey.withOpacity(0.1)
                      : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              prayer.icon,
              color: isPassed
                  ? Colors.grey
                  : isActive
                      ? activeGreen
                      : Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Prayer name
          Expanded(
            child: Text(
              prayer.name,
              style: TextStyle(
                color: isPassed
                    ? Colors.grey
                    : isActive
                        ? activeGreen
                        : Colors.white,
                fontSize: 18,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                decoration: isPassed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),

          // Time
          SizedBox(
            width: 70,
            child: Text(
              DateFormat.jm().format(DateFormat("H:mm").parse(prayer.time)),
              style: TextStyle(
                color: isPassed
                    ? Colors.grey
                    : isActive
                        ? activeGreen
                        : Colors.white70,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(width: 10),

          // Status badge
          Container(
            width: 130,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isActive)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Icon(
                        _getStatusIcon(status),
                        color: statusColor.withOpacity(
                          0.5 + _pulseAnimation.value * 0.5,
                        ),
                        size: 14,
                      );
                    },
                  )
                else
                  Icon(_getStatusIcon(status), color: statusColor, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _getStatusText(status, index),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}