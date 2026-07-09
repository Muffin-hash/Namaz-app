import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real Time Namaz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const NamazTimingPage(),
    );
  }
}

// --- Data Model ---
class PrayerTime {
  final String name;
  final String time;
  final IconData icon;

  PrayerTime({required this.name, required this.time, required this.icon});
}

// --- Main Page ---
class NamazTimingPage extends StatefulWidget {
  const NamazTimingPage({super.key});

  @override
  State<NamazTimingPage> createState() => _NamazTimingPageState();
}

class _NamazTimingPageState extends State<NamazTimingPage> {
  List<PrayerTime> _prayers = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int? _nextPrayerIndex;
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchLocationAndData();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Prevent memory leaks
    super.dispose();
  }

  // 1. Get Device Location
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
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = "Location permission is required to get accurate Namaz times.";
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

  // 2. Fetch Real-Time Data from Aladhan API (Timezone Bulletproof)
  Future<void> _fetchPrayerTimes(double lat, double lon) async {
    // Using universal Unix timestamp prevents timezone/date mismatch bugs
    final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // Method 2 is ISNA (Islamic Society of North America). 
    // You can change this (e.g., 1 for University of Islamic Sciences, Karachi)
    final String url = 'https://api.aladhan.com/v1/timings/$timestamp?latitude=$lat&longitude=$lon&method=2';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Map<String, dynamic> timings = data['data']['timings'];

        setState(() {
          _prayers = [
            PrayerTime(name: "Fajr", time: timings['Fajr'], icon: Icons.dark_mode_outlined),
            PrayerTime(name: "Dhuhr", time: timings['Dhuhr'], icon: Icons.wb_sunny_outlined),
            PrayerTime(name: "Asr", time: timings['Asr'], icon: Icons.cloud_outlined),
            PrayerTime(name: "Maghrib", time: timings['Maghrib'], icon: Icons.nights_stay_outlined),
            PrayerTime(name: "Isha", time: timings['Isha'], icon: Icons.bedtime_outlined),
          ];
          _nextPrayerIndex = _calculateNextPrayer();
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

  // 3. Determine which prayer is next based on current time
  int _calculateNextPrayer() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    for (int i = 0; i < _prayers.length; i++) {
      final parts = _prayers[i].time.split(':');
      final prayerMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      if (prayerMinutes > currentMinutes) {
        return i;
      }
    }
    return 0; // If all prayers have passed, next is Fajr (tomorrow)
  }

  // 4. Live Countdown Timer Logic
  void _startCountdownTimer() {
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    if (_nextPrayerIndex == null) return;
    
    final now = DateTime.now();
    final parts = _prayers[_nextPrayerIndex!].time.split(':');
    
    DateTime nextPrayerTime = DateTime(
      now.year, now.month, now.day,
      int.parse(parts[0]), int.parse(parts[1]),
    );

    // If the time has already passed today, target tomorrow's instance
    if (nextPrayerTime.isBefore(now)) {
      nextPrayerTime = nextPrayerTime.add(const Duration(days: 1));
    }

    setState(() {
      _timeLeft = nextPrayerTime.difference(now);
    });
  }

  // Formats Duration (e.g., 02:15:30)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF1A2332);
    const cardColor = Color(0xFF243447);
    const accentColor = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: accentColor))
              : _errorMessage.isNotEmpty
                  ? Center(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Date
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          "Prayer Timings",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 30),

                        // Next Prayer Countdown Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accentColor, width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Time remaining",
                                  style: TextStyle(color: Colors.grey, fontSize: 14)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _prayers[_nextPrayerIndex!].name,
                                    style: const TextStyle(
                                        color: accentColor,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _formatDuration(_timeLeft),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'monospace'), // Monospace prevents timer jitter
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Prayer List
                        Expanded(
                          child: ListView.builder(
                            itemCount: _prayers.length,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final prayer = _prayers[index];
                              bool isNext = index == _nextPrayerIndex;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                decoration: BoxDecoration(
                                  color: isNext ? cardColor.withOpacity(0.8) : cardColor,
                                  borderRadius: BorderRadius.circular(15),
                                  border: isNext
                                      ? Border.all(color: accentColor.withOpacity(0.5), width: 1)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(prayer.icon, color: isNext ? accentColor : Colors.grey, size: 24),
                                        const SizedBox(width: 15),
                                        Text(
                                          prayer.name,
                                          style: TextStyle(
                                            color: isNext ? Colors.white : Colors.grey.shade400,
                                            fontSize: 20,
                                            fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      // Converts 24h API format to 12h AM/PM format
                                      DateFormat.jm().format(DateFormat("H:mm").parse(prayer.time)),
                                      style: TextStyle(
                                        color: isNext ? accentColor : Colors.white,
                                        fontSize: 18,
                                        fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      ],
                    ),
        ),
      ),
    );
  }
}
