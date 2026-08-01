import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_theme.dart';
import '../providers/auth_providers.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(authServiceProvider)
          .signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      if (mounted) {
        _showMessage('Account created.');
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Signup failed.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create your account',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Keep your notes and reminders synced across devices.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter your email.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter a password.';
                                }

                                if (value.trim().length < 6) {
                                  return 'Use at least 6 characters.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              decoration: const InputDecoration(
                                labelText: 'Confirm password',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Confirm your password.';
                                }

                                if (value.trim() !=
                                    _passwordController.text.trim()) {
                                  return 'Passwords do not match.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            FilledButton(
                              onPressed: _isSubmitting ? null : _signup,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Signup'),
                            ),
                          ],
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
    );
  }
}
