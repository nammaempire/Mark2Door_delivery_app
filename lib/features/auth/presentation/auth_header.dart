import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_logo.dart';

/// Green curved header shared by the login, OTP and pincode screens.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        topInset + (compact ? 20 : 36),
        24,
        compact ? 24 : 36,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        children: [
          BrandLogo(size: compact ? 56 : 76),
          if (!compact) ...[
            const SizedBox(height: 8),
            const Text(
              'Delivery partner app',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small informational strip, used for sample-data hints.
class HintBanner extends StatelessWidget {
  const HintBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Button label that swaps to a spinner while [loading].
class LoadingLabel extends StatelessWidget {
  const LoadingLabel(this.label, {super.key, required this.loading});

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (!loading) return Text(label);
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
    );
  }
}
