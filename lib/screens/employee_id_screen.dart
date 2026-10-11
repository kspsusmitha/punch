import 'dart:ui';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'home_screen.dart';

class EmployeeIdScreen extends StatefulWidget {
  const EmployeeIdScreen({super.key});

  @override
  State<EmployeeIdScreen> createState() => _EmployeeIdScreenState();
}

class _EmployeeIdScreenState extends State<EmployeeIdScreen> with TickerProviderStateMixin {
  final TextEditingController _idController = TextEditingController();
  bool _isLoading = false;
  
  late AnimationController _entryController;
  late AnimationController _glowController;
  late AnimationController _blobController;
  late AnimationController _hoverController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _blobAnimation;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    
    // Staggered Entry Sequence
    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.1, 0.7, curve: Curves.easeOut)),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.2, 1.0, curve: Curves.easeOutQuart)),
    );

    // Input Glow Pulse
    _glowController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.0, end: 12.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Cinematic Floating Background Blobs
    _blobController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _blobAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_blobController);

    // Continuous Card Hover Effect
    _hoverController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _hoverAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );

    _entryController.forward();
  }

  Future<void> _submitId() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your Employee ID'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: Colors.black87,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final ref = FirebaseDatabase.instance.ref('employees/$id');
      final snapshot = await ref.get();
      final prefs = await SharedPreferences.getInstance();

      // Clear previous user data to prevent leakage
      await prefs.clear();
      await prefs.setString('employee_id', id);

      if (snapshot.exists) {
        // User exists, retrieve their data
        final data = snapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          final profile = data['profile'] as Map<dynamic, dynamic>?;
          if (profile != null) {
            if (profile['user_name'] != null) await prefs.setString('user_name', profile['user_name']);
            if (profile['profile_image_path'] != null) await prefs.setString('profile_image_path', profile['profile_image_path']);
          }

          final shiftData = data['shift_data'] as Map<dynamic, dynamic>?;
          if (shiftData != null) {
            if (shiftData['shift_goal_hours'] != null) await prefs.setInt('shift_goal_hours', shiftData['shift_goal_hours']);
            if (shiftData['shift_goal_minutes'] != null) await prefs.setInt('shift_goal_minutes', shiftData['shift_goal_minutes']);
            if (shiftData['shift_goal_seconds'] != null) await prefs.setInt('shift_goal_seconds', shiftData['shift_goal_seconds']);
            
            if (shiftData['is_clocked_in'] != null) await prefs.setBool('is_clocked_in', shiftData['is_clocked_in']);
            if (shiftData['is_paused'] != null) await prefs.setBool('is_paused', shiftData['is_paused']);
            if (shiftData['start_time'] != null) await prefs.setString('start_time', shiftData['start_time']);
            if (shiftData['pause_start_time'] != null) await prefs.setString('pause_start_time', shiftData['pause_start_time']);
            if (shiftData['logout_time'] != null) await prefs.setString('logout_time', shiftData['logout_time']);
            if (shiftData['total_paused_duration_ms'] != null) await prefs.setInt('total_paused_duration_ms', shiftData['total_paused_duration_ms']);
          }

          if (data['logged_activities'] != null) {
            try {
              final List<dynamic> activitiesList;
              if (data['logged_activities'] is List) {
                activitiesList = data['logged_activities'] as List<dynamic>;
              } else if (data['logged_activities'] is Map) {
                activitiesList = (data['logged_activities'] as Map<dynamic, dynamic>).values.toList();
                // Optional: sort by time if needed, but HomeScreen handles parsing it
              } else {
                activitiesList = [];
              }
              await prefs.setString('logged_activities', json.encode(activitiesList));
            } catch (e) {
              debugPrint('Error parsing activities: $e');
            }
          }
        }
      } else {
        // User does not exist, create a new node
        final newUserData = {
          'profile': {
            'user_name': 'New Employee',
            'profile_image_path': 'assets/images/avatar_gifi.png',
          },
          'shift_data': {
            'shift_goal_hours': 8,
            'shift_goal_minutes': 0,
            'shift_goal_seconds': 0,
          },
        };
        await ref.set(newUserData);
        
        // Setup initial shared preferences
        await prefs.setString('user_name', 'New Employee');
        await prefs.setString('profile_image_path', 'assets/images/avatar_gifi.png');
        await prefs.setInt('shift_goal_hours', 8);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed. Please try again. Error: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _glowController.dispose();
    _blobController.dispose();
    _hoverController.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Base Gradient Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF050806), Color(0xFF0D1411), Color(0xFF080C0A)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          
          // 2. Animated Floating Soft Blobs
          AnimatedBuilder(
            animation: _blobAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  // Top left mint blob
                  Positioned(
                    top: size.height * 0.15 + math.sin(_blobAnimation.value) * 60,
                    left: size.width * 0.1 + math.cos(_blobAnimation.value) * 80,
                    child: _buildSoftBlob(const Color(0xFF2C6B46).withOpacity(0.25), 250),
                  ),
                  // Bottom right lavender blob
                  Positioned(
                    bottom: size.height * 0.15 + math.cos(_blobAnimation.value + math.pi) * 70,
                    right: size.width * 0.05 + math.sin(_blobAnimation.value + math.pi) * 50,
                    child: _buildSoftBlob(const Color(0xFF8B5E3C).withOpacity(0.2), 300),
                  ),
                  // Center blue blob
                  Positioned(
                    top: size.height * 0.45 + math.sin(_blobAnimation.value * 1.5) * 40,
                    left: size.width * 0.3 + math.cos(_blobAnimation.value * 1.5) * 40,
                    child: _buildSoftBlob(const Color(0xFF1ED760).withOpacity(0.25), 200),
                  ),
                ],
              );
            },
          ),
          
          // 3. Foreground Content
          SafeArea(
            child: Column(
              children: [
                // Optional Top Padding if we remove the header
                const SizedBox(height: 40),
                
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: AnimatedBuilder(
                            animation: _hoverAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _hoverAnimation.value),
                                child: child,
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 28.0),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // The Premium Glass Card
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(40),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                                      child: Container(
                                        padding: const EdgeInsets.all(40.0),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF15201A).withOpacity(0.55),
                                          borderRadius: BorderRadius.circular(40),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.08),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.4),
                                              blurRadius: 30,
                                              spreadRadius: -5,
                                            )
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Dynamic bouncy monkey emoji
                                            TweenAnimationBuilder<double>(
                                              tween: Tween(begin: 0, end: 1),
                                              duration: const Duration(milliseconds: 1800),
                                              curve: Curves.elasticOut,
                                              builder: (context, value, child) {
                                                return Transform.scale(
                                                  scale: value,
                                                  child: Transform.rotate(
                                                    angle: (1 - value) * math.pi / 4,
                                                    child: child,
                                                  ),
                                                );
                                              },
                                              child: const Text(
                                                '🐵',
                                                style: TextStyle(
                                                  fontSize: 70,
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black26,
                                                      blurRadius: 15,
                                                      offset: Offset(0, 10),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            const Text(
                                              'Welcome to PUNCH',
                                              style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Enter your Employee ID to start your shift.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.white.withOpacity(0.7),
                                                fontWeight: FontWeight.w500,
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 45),
                                            
                                            // Glowing Input Field
                                            AnimatedBuilder(
                                              animation: _glowAnimation,
                                              builder: (context, child) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(20),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFF1ED760).withOpacity(0.08 + (_glowAnimation.value * 0.01)),
                                                        blurRadius: 15 + _glowAnimation.value,
                                                        spreadRadius: _glowAnimation.value * 0.4,
                                                      ),
                                                    ],
                                                  ),
                                                  child: child,
                                                );
                                              },
                                              child: TextField(
                                                controller: _idController,
                                                style: const TextStyle(
                                                  fontSize: 20, 
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 2.0,
                                                  color: Colors.white,
                                                ),
                                                textAlign: TextAlign.center,
                                                decoration: InputDecoration(
                                                  hintText: 'ID NUMBER',
                                                  hintStyle: TextStyle(
                                                    color: Colors.white.withOpacity(0.3),
                                                    letterSpacing: 3.0,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.white.withOpacity(0.06),
                                                  contentPadding: const EdgeInsets.symmetric(vertical: 22, horizontal: 24),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(20),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(20),
                                                    borderSide: const BorderSide(color: Color(0xFF1ED760), width: 3),
                                                  ),
                                                ),
                                                keyboardType: TextInputType.text,
                                                textInputAction: TextInputAction.done,
                                                onSubmitted: (_) => _submitId(),
                                              ),
                                            ),
                                            const SizedBox(height: 40),
                                            
                                            // Premium Gradient Action Button
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              width: double.infinity,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFF2C6B46), Color(0xFF1B4E30)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF2C6B46).withOpacity(0.4),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap: _isLoading ? null : _submitId,
                                                  borderRadius: BorderRadius.circular(20),
                                                  splashColor: Colors.white.withOpacity(0.2),
                                                  highlightColor: Colors.white.withOpacity(0.1),
                                                  child: Center(
                                                    child: _isLoading
                                                        ? const SizedBox(
                                                            width: 28,
                                                            height: 28,
                                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                                          )
                                                        : const Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Text(
                                                                'Start Your Shift',
                                                                style: TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: Colors.white,
                                                                  letterSpacing: 0.5,
                                                                ),
                                                              ),
                                                              SizedBox(width: 10),
                                                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
                                                            ],
                                                          ),
                                                  ),
                                                ),
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
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Creates soft, glowing, gradient-based orbs without expensive backdrop filters
  Widget _buildSoftBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0.0),
          ],
          stops: const [0.2, 1.0],
        ),
      ),
    );
  }
}
