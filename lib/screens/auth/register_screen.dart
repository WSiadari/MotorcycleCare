import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';

/// Registration screen. Opens the login screen when the account is created.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _workshop = TextEditingController();
  final _staffCode = TextEditingController();
  UserRole _role = UserRole.owner;
  bool _busy = false;
  String? _nameError, _emailError, _passwordError, _confirmError, _extraError, _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm, _workshop, _staffCode]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _checkPassword(String s) {
    if (s.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _nameError = _name.text.trim().length < 3 ? 'Enter your full name.' : null;
      _emailError = AppState.validateEmail(_email.text);
      _passwordError = _checkPassword(_password.text);
      _confirmError = _confirm.text != _password.text ? "Passwords don't match." : null;
      _extraError = switch (_role) {
        UserRole.mechanic when _workshop.text.trim().isEmpty => 'Enter the workshop where you work.',
        UserRole.admin when _staffCode.text.trim().isEmpty => 'Enter the staff code from the head admin.',
        _ => null,
      };
    });
    if ([_nameError, _emailError, _passwordError, _confirmError, _extraError].any((e) => e != null)) {
      return;
    }
    setState(() => _busy = true);
    final (err, needsConfirmation) = await AppScope.read(context).register(
      fullName: _name.text,
      email: _email.text,
      password: _password.text,
      role: _role,
      workshopName: _role == UserRole.mechanic ? _workshop.text : null,
      staffCode: _role == UserRole.admin ? _staffCode.text : null,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() {
        if (err.contains('already exists') || err.contains('already registered')) {
          _emailError = 'This email is already registered. Log in or use another email.';
        } else if (err.contains('Staff code') || err.contains('workshop')) {
          _extraError = err;
        } else {
          _error = err;
        }
      });
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => LoginScreen(
        prefillEmail: _email.text.trim(),
        justRegistered: true,
        needsConfirmation: needsConfirmation,
      ),
    ));
  }

  Widget _field(String label, Widget input, {String? error, String? helper}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        FieldLabel(label),
        input,
        if (error != null) ErrorLine(error) else if (helper != null) Helper(helper),
      ]);

  @override
  Widget build(BuildContext context) {
    return AppPage(children: [
      const TopBar('Create Account'),
      Text('One account for all your motorcycles.', style: ts(14, regular, AppColors.muted)),
      if (_error != null) ErrorBanner(_error!),
      // Role
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        const FieldLabel('I am a'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(12)),
          child: Row(spacing: 4, children: [
            for (final r in UserRole.values)
              Expanded(
                child: Material(
                  color: _role == r ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => setState(() {
                      _role = r;
                      _extraError = null;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Center(
                        child: Text(r == UserRole.owner ? 'Owner' : r.label,
                            style: ts(13, semiBold, _role == r ? AppColors.accentStrong : AppColors.muted)),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ]),
      _field(
        'Full name',
        AppInput(
          controller: _name,
          icon: 'user',
          hint: 'e.g. Rizky Yudha',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          hasError: _nameError != null,
          onChanged: (_) => setState(() => _nameError = null),
        ),
        error: _nameError,
      ),
      _field(
        'Email',
        AppInput(
          controller: _email,
          icon: 'mail',
          hint: 'name@mail.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          hasError: _emailError != null,
          onChanged: (_) => setState(() => _emailError = null),
        ),
        error: _emailError,
      ),
      _field(
        'Password',
        AppInput(
          controller: _password,
          icon: 'lock',
          obscure: true,
          textInputAction: TextInputAction.next,
          hasError: _passwordError != null,
          onChanged: (_) => setState(() => _passwordError = null),
        ),
        error: _passwordError,
        helper: 'At least 8 characters.',
      ),
      _field(
        'Confirm password',
        AppInput(
          controller: _confirm,
          icon: 'lock',
          obscure: true,
          hasError: _confirmError != null,
          onChanged: (_) => setState(() => _confirmError = null),
          onSubmitted: (_) => _submit(),
        ),
        error: _confirmError,
      ),
      if (_role == UserRole.mechanic)
        _field(
          'Workshop name',
          AppInput(
            controller: _workshop,
            icon: 'wrench',
            hint: 'e.g. Maju Jaya Motor',
            textCapitalization: TextCapitalization.words,
            hasError: _extraError != null,
            onChanged: (_) => setState(() => _extraError = null),
          ),
          error: _extraError,
          helper: 'Owners see this name on the services you record.',
        ),
      if (_role == UserRole.admin)
        _field(
          'Staff code',
          AppInput(
            controller: _staffCode,
            icon: 'lock',
            hint: 'e.g. ADM-2026',
            textCapitalization: TextCapitalization.characters,
            hasError: _extraError != null,
            onChanged: (_) => setState(() => _extraError = null),
          ),
          error: _extraError,
          helper: 'Admin accounts need a staff code from the head admin.',
        ),
      AppButton('Create Account', busy: _busy, onPressed: _submit),
      Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 4, children: [
        Text('Already have an account?', style: ts(13, regular, AppColors.muted)),
        GestureDetector(
          onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('Log in', style: ts(13, semiBold, AppColors.accentStrong)),
          ),
        ),
      ]),
    ]);
  }
}
