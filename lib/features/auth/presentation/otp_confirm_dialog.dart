import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/env.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';

/// Asks the signed-in user to confirm a fresh OTP before something that
/// cannot be undone, such as deleting the account. Completes with true once
/// the OTP is confirmed, false if the user backs out.
Future<bool> confirmWithOtp(
  BuildContext context, {
  required AuthRepository auth,
  required String phone,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OtpConfirmDialog(auth: auth, phone: phone),
  );
  return ok ?? false;
}

class _OtpConfirmDialog extends StatefulWidget {
  const _OtpConfirmDialog({required this.auth, required this.phone});

  final AuthRepository auth;
  final String phone;

  @override
  State<_OtpConfirmDialog> createState() => _OtpConfirmDialogState();
}

class _OtpConfirmDialogState extends State<_OtpConfirmDialog> {
  static const _length = 6;

  final _code = TextEditingController();
  String? _verificationId;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    _send();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.auth.sendOtp(widget.phone);
      if (mounted) setState(() => _verificationId = id);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final id = _verificationId;
    if (id == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.verifyOtp(verificationId: id, code: _code.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      // Android can read the SMS and confirm it before the code is typed,
      // which uses the code up. The user is confirmed all the same.
      if (widget.auth.signedInRecently) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = e.message;
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _verificationId != null;
    return AlertDialog(
      title: const Text('Confirm it is you'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sent
                ? 'Enter the $_length-digit OTP sent to ${widget.phone}.'
                : 'Sending an OTP to ${widget.phone}…',
          ),
          if (!Env.useFirebase) ...[
            const SizedBox(height: 6),
            const Text(
              'Sample-data mode: the OTP is ${AppConfig.demoOtp}.',
              style: TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('confirm-otp-field'),
            controller: _code,
            enabled: sent && !_busy,
            keyboardType: TextInputType.number,
            maxLength: _length,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'OTP',
              counterText: '',
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        if (!sent && !_busy)
          TextButton(onPressed: _send, child: const Text('Send again'))
        else
          TextButton(
            key: const ValueKey('confirm-otp-button'),
            onPressed:
                _busy || _code.text.length != _length ? null : _verify,
            child: const Text('Confirm'),
          ),
      ],
    );
  }
}
