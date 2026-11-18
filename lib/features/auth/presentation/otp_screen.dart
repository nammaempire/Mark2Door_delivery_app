import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/app_user.dart';
import 'auth_header.dart';

class OtpArgs {
  const OtpArgs({required this.phone, required this.verificationId});

  final String phone;
  final String verificationId;
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});

  final OtpArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _otpLength = 6;
  static const _resendAfter = 30;

  final _codeController = TextEditingController();
  late String _verificationId = widget.args.verificationId;
  bool _loading = false;
  String? _error;
  int _secondsLeft = _resendAfter;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _ticker?.cancel();
    setState(() => _secondsLeft = _resendAfter);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      if (mounted) setState(() => _secondsLeft--);
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text;
    if (_loading || code.length != _otpLength) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // On success the auth stream fires and the router redirect moves the
      // user on, so there is no navigation here.
      await ref.read(authRepositoryProvider).verifyOtp(
            verificationId: _verificationId,
            code: code,
          );
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      final id =
          await ref.read(authRepositoryProvider).sendOtp(widget.args.phone);
      if (!mounted) return;
      _verificationId = id;
      _codeController.clear();
      _startCountdown();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('OTP sent again')));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canVerify = _codeController.text.length == _otpLength && !_loading;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              const AuthHeader(compact: true),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter OTP',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Sent to ${widget.args.phone}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('otp-field'),
                      controller: _codeController,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(_otpLength),
                      ],
                      onChanged: (value) {
                        setState(() => _error = null);
                        if (value.length == _otpLength) _verify();
                      },
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: canVerify ? _verify : null,
                      child: LoadingLabel('Verify', loading: _loading),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: _secondsLeft > 0
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Resend OTP in ${_secondsLeft}s',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            )
                          : TextButton(
                              onPressed: _resend,
                              child: const Text('Resend OTP'),
                            ),
                    ),
                    if (!Env.useFirebase) ...[
                      const SizedBox(height: 12),
                      const HintBanner(
                        'Sample-data mode: no SMS is sent. '
                        'Use OTP ${AppConfig.demoOtp}.',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
