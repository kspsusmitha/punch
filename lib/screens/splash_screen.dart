import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'employee_id_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _introController;
  late AnimationController _loadingController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _spotlightOpacity;

  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    // Cinematic Intro Controller
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Loading Bar Controller
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Scanner Pulse Controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Gradual fade-in from darkness
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeIn),
      ),
    );

    // Subtle movie-like zoom-in
    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.02).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Soft spotlight fade-in
    _spotlightOpacity = Tween<double>(begin: 0.0, end: 0.8).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeInOut),
      ),
    );

    // Neon green scanner pulse animations
    _pulseScale = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOutQuad,
      ),
    );

    _pulseOpacity = Tween<double>(begin: 0.8, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOutQuad,
      ),
    );

    // Start intro sequence
    _introController.forward();
    _loadingController.forward();

    // Start pulsing slightly after the monkey becomes visible
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _pulseController.repeat(reverse: false);
      }
    });

    // Navigate to home or ID screen after animation finishes
    Timer(const Duration(milliseconds: 4500), () async {
      final prefs = await SharedPreferences.getInstance();
      final String? empId = prefs.getString('employee_id');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (context, animation, secondaryAnimation) =>
                (empId != null && empId.isNotEmpty) ? const HomeScreen() : const EmployeeIdScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _loadingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final imageWidth = size.width * 0.85;

    return Scaffold(
      backgroundColor: const Color(0xFF050806), // Deep green-black background
      body: AnimatedBuilder(
        animation: Listenable.merge([_introController, _pulseController, _loadingController]),
        builder: (context, child) {
          return Stack(
            children: [
              // 1. Soft spotlight slowly appearing in the center
              Positioned.fill(
                child: Opacity(
                  opacity: _spotlightOpacity.value,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF1ED760).withOpacity(0.15),
                          const Color(0xFF1ED760).withOpacity(0.0),
                        ],
                        stops: const [0.1, 0.8],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Monkey Mascot with cinematic zoom and fade
              Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Subtle depth/glow behind the mascot
                        Container(
                          width: imageWidth * 0.7,
                          height: imageWidth * 0.7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1ED760).withOpacity(0.25),
                                blurRadius: 80,
                                spreadRadius: 25,
                              ),
                            ],
                          ),
                        ),

                        // Main Illustration
                        Image.asset(
                          'assets/images/monkey_punch.png',
                          width: imageWidth,
                          fit: BoxFit.contain,
                        ),

                        // Fingerprint Scanner Pulse
                        Positioned(
                          right: imageWidth * 0.26, // Centroid x_frac=0.7398 relative to width (1 - 0.7398 = 0.26)
                          top: imageWidth * 0.82,   // Centroid y_frac=0.5458 relative to height (1.5 * 0.5458 = 0.82)
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulsing neon light
                              Transform.scale(
                                scale: _pulseScale.value,
                                child: Opacity(
                                  opacity: _pulseOpacity.value,
                                  child: Container(
                                    width: 25,
                                    height: 25,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.greenAccent.withOpacity(0.7),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.greenAccent.withOpacity(0.8),
                                          blurRadius: 25,
                                          spreadRadius: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Core steady neon glow
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.greenAccent,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.greenAccent.withOpacity(0.8),
                                      blurRadius: 15,
                                      spreadRadius: 4,
                                    ),
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.5),
                                      blurRadius: 5,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Top Branding (Logo + PUNCH)
              Positioned(
                top: size.height * 0.08,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            width: 32,
                            height: 32,
                            errorBuilder: (c, e, s) => const Icon(Icons.fingerprint, color: Color(0xFF1ED760), size: 32),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'PUNCH',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Smart Attendance System',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Bottom Text & Loading
              Positioned(
                bottom: size.height * 0.06,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    children: [
                      const Text(
                        'Punch In. Show Up.',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Own Your Day.',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1ED760), // Neon green
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      // Fingerprint icon
                      const Icon(
                        Icons.fingerprint,
                        color: Color(0xFF1ED760),
                        size: 26,
                      ),
                      const SizedBox(height: 12),
                      
                      // Loading text
                      Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      // Loading bar
                      Container(
                        width: size.width * 0.45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _loadingController.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1ED760),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1ED760).withOpacity(0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
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
            ],
          );
        },
      ),
    );
  }
}
