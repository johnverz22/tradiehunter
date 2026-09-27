import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme/design_tokens.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Mockup 01-splash: full-bleed brand gradient, wordmark + tagline.
/// Boot logic: first-launch → onboarding, JWT present → fetch role → /home or /tradie.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  Future<void> _checkAppState() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    if (isFirstLaunch) {
      await prefs.setBool('is_first_launch', false);
      if (mounted) context.go('/onboarding');
      return;
    }

    final token = await _storage.read(key: 'jwt_token');

    if (!mounted) return;

    if (token != null) {
      // Determine which home screen to show based on actual profile role.
      final destination = await getRoleRoute(
        ref.read(sharedProfileRepositoryProvider),
      );
      if (mounted) context.go(destination);
    } else {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [DesignTokens.brand900, DesignTokens.brand500],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: DesignTokens.fontDisplay,
                    fontWeight: FontWeight.w700,
                    fontSize: 48,
                    letterSpacing: -0.96,
                    color: DesignTokens.paperLight,
                  ),
                  children: [
                    TextSpan(text: 'Fixo'),
                    TextSpan(
                        text: '.',
                        style: TextStyle(color: DesignTokens.amber)),
                  ],
                ),
              ),
              // Amber dot is part of the wordmark; rendered via span above
              // in HTML — here the trailing dot uses amber.
              SizedBox(height: 16),
              Text(
                'Get it sorted.',
                style: TextStyle(
                  fontFamily: DesignTokens.fontBody,
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                  color: Color(0xCCF6F4EE),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
