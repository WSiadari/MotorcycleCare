import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../home_router.dart';
import 'register_screen.dart';

/// Login screen, also shown right after registration.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.prefillEmail, this.justRegistered = false, this.needsConfirmation = false});

  final String? prefillEmail;
  final bool justRegistered;
  final bool needsConfirmation;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _email = TextEditingController(text: widget.prefillEmail ?? '');
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error, _emailError, _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _emailError = AppState.validateEmail(_email.text);
      _passwordError = _password.text.isEmpty ? 'Enter your password.' : null;
    });
    if (_emailError != null || _passwordError != null) return;
    setState(() => _busy = true);
    final err = await AppScope.read(context).login(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final user = AppScope.read(context).currentUser!;
    Navigator.of(context).pushAndRemoveUntil(homeRouteFor(user), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final failed = _error != null;
    final isDemo = AppScope.of(context).backend.isDemo;
    return AppPage(children: [
      const TopBar('Log In'),
      if (widget.justRegistered)
        SuccessBanner(widget.needsConfirmation
            ? 'Account created. Open the confirmation link in your email, then log in.'
            : 'Account created. Log in to add your first motorcycle.'),
      Text(widget.justRegistered ? 'Log in to continue' : 'Welcome back', style: ts(22, bold)),
      Text(
        widget.justRegistered
            ? 'Use the email and password you just created.'
            : 'Log in to continue to your dashboard.',
        style: ts(14, regular, AppColors.muted, 1.43),
      ),
      // Login Form
      if (failed) ErrorBanner(_error!),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Email'),
        AppInput(
          controller: _email,
          icon: 'mail',
          hint: 'name@mail.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          hasError: failed || _emailError != null,
          onChanged: (_) => setState(() => _emailError = null),
        ),
        if (_emailError != null) ErrorLine(_emailError!),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('Password'),
        AppInput(
          controller: _password,
          icon: 'lock',
          hint: 'Your password',
          obscure: _hide,
          autofillHints: const [AutofillHints.password],
          hasError: failed || _passwordError != null,
          onChanged: (_) => setState(() => _passwordError = null),
          onSubmitted: (_) => _submit(),
          trailing: IconButton(
            tooltip: _hide ? 'Show password' : 'Hide password',
            icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 18, color: AppColors.muted),
            onPressed: () => setState(() => _hide = !_hide),
          ),
        ),
        if (_passwordError != null)
          ErrorLine(_passwordError!)
        else if (failed)
          const ErrorLine('Tap the field to type your password again.'),
      ]),
      AppButton('Log In', busy: _busy, onPressed: _submit),
      Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 4, children: [
        Text("Don't have an account?", style: ts(13, regular, AppColors.muted)),
        GestureDetector(
          onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RegisterScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('Create one', style: ts(13, semiBold, AppColors.accentStrong)),
          ),
        ),
      ]),
      if (isDemo && !widget.justRegistered) const Note('Demo accounts · Owner: rizky@mail.com / rizky123 · Mechanic: budi@mail.com / budi123 · '
            'Admin: dina@mail.com / dina123'),
    ]);
  }
}
