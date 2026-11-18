import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/l10n/strings.dart';
import '../../core/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _messageFor(FirebaseAuthException e, Strings s) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
      case 'user-disabled':
        return s('auth.errors.invalidCredential');
      case 'network-request-failed':
        return s('auth.errors.network');
      case 'too-many-requests':
        return s('auth.errors.tooManyRequests');
      default:
        return s('auth.errors.generic');
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(firebaseAuthProvider).signInWithEmailAndPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
      // Yonlendirmeyi router yapar (authStateChanges).
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e, s));
    } catch (_) {
      if (mounted) setState(() => _error = s('auth.errors.generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tokensProvider);
    final s = ref.watch(stringsProvider);
    final pad = t.screenPadding;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s('app.name'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: t.fontSize('headline'),
                        fontWeight: t.fontWeight('bold'),
                        color: t.color('accent'),
                        letterSpacing: 1.4,
                      ),
                    ),
                    SizedBox(height: t.spacing('sm')),
                    Text(
                      s('auth.subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: t.fontSize('body'),
                        color: t.color('textSecondary'),
                      ),
                    ),
                    SizedBox(height: t.spacing('xxl')),
                    TextFormField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: s('auth.email'),
                        prefixIcon: const Icon(LucideIcons.mail, size: 20),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? s('auth.required')
                          : null,
                    ),
                    SizedBox(height: t.spacing('lg')),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: s('auth.password'),
                        prefixIcon: const Icon(LucideIcons.lock, size: 20),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                            size: 20,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? s('auth.required') : null,
                    ),
                    if (_error != null) ...[
                      SizedBox(height: t.spacing('lg')),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: t.color('negative'),
                          fontSize: t.fontSize('body'),
                        ),
                      ),
                    ],
                    SizedBox(height: t.spacing('xl')),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(s('auth.signIn')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
