import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/m2d_mark.dart';

/// The two colours of the logo artwork.
const _logoMaroon = Color(0xFF5D011A);
const _logoGold = Color(0xFFDDA10D);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();
  late final Animation<double> _scale = Tween<double>(begin: 0.7, end: 1)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Always aim for home; the router redirect sends signed-out users to
    // login and users without a delivery pincode to the pincode screen.
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) context.go(Routes.home);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // White, like the native launch screen that shows before Flutter
    // starts, so the logo stays in place while the app loads.
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox(
        width: double.infinity,
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: const M2dMark(width: 200),
                ),
              ),
              const SizedBox(height: 22),
              FadeTransition(
                opacity: _fade,
                child: const Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: _logoMaroon,
                    ),
                    children: [
                      TextSpan(text: 'mart'),
                      TextSpan(text: '2', style: TextStyle(color: _logoGold)),
                      TextSpan(text: 'door'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FadeTransition(
                opacity: _fade,
                child: const Text(
                  'Delivery partner',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const Spacer(flex: 3),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _logoMaroon,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
