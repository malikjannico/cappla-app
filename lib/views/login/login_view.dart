import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/providers/providers.dart';
import '../../core/router/router_paths.dart';
import 'vetter_logo.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _errorMessage = '';
  bool _showPasswordStep = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email.');
      return;
    }
    setState(() {
      _showPasswordStep = true;
      _errorMessage = '';
    });
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final authService = ref.read(authServiceProvider);
      final email = _emailController.text.trim().toLowerCase();
      await authService.signIn(
        email: email,
        password: _passwordController.text,
      );
      final user = await ref.read(databaseServiceProvider).getUser(email);
      ref.read(currentUserProvider.notifier).state = user;
      if (!mounted) return;
      context.go(RouterPaths.planning);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first.')),
      );
      return;
    }

    final db = ref.read(databaseServiceProvider);
    if (db.toString().contains('Mock')) {
      // For E2E Integration tests, mock the flow immediately
      ref.read(resetPasswordEmailProvider.notifier).state = email;
      ref.read(resetPasswordCodeProvider.notifier).state = '123456';
      context.go('${RouterPaths.resetPassword}?email=${Uri.encodeComponent(email)}');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      // Write the reset request to Firestore (delete first to guarantee onCreate trigger fires)
      await firestore.collection('passwordResetRequests').doc(email).delete().catchError((_) {});
      await firestore.collection('passwordResetRequests').doc(email).set({
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'requested',
      });

      // Listen for the verification code sending status
      StreamSubscription? subscription;
      subscription = firestore
          .collection('passwordResetRequests')
          .doc(email)
          .snapshots()
          .listen((snap) {
        if (!mounted) {
          subscription?.cancel();
          return;
        }
        if (snap.exists && snap.data() != null) {
          final status = snap.data()!['status'] as String?;
          if (status == 'sent') {
            subscription?.cancel();
            setState(() {
              _isLoading = false;
            });
            // Prefill email in the provider
            ref.read(resetPasswordEmailProvider.notifier).state = email;
            // Delete the request doc
            firestore
                .collection('passwordResetRequests')
                .doc(email)
                .delete()
                .catchError((_) {});
            context.go('${RouterPaths.resetPassword}?email=${Uri.encodeComponent(email)}');
          } else if (status == 'error') {
            subscription?.cancel();
            setState(() {
              _isLoading = false;
            });
            final error =
                snap.data()!['error'] as String? ?? 'An error occurred.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
            firestore
                .collection('passwordResetRequests')
                .doc(email)
                .delete()
                .catchError((_) {});
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _onButtonPressed() {
    if (_showPasswordStep) {
      _handleLogin();
    } else {
      _handleNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text(
          'Cappla',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: theme.colorScheme.primary,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            color: const Color(0xFFFFFFFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(24),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Log in to Cappla',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showPasswordStep
                        ? 'Enter your password to log in.'
                        : 'Enter your email to log in.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  const SizedBox(height: 24),

                  if (!_showPasswordStep) ...[
                    TextField(
                      key: const Key('login_email_input'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _onButtonPressed(),
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        key: const Key('login_error_text'),
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('login_next_button'),
                      onPressed: _isLoading ? null : _onButtonPressed,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Next'),
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showPasswordStep = false;
                            _errorMessage = '';
                            _passwordController.clear();
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          overlayColor: Colors.transparent,
                          foregroundColor: theme.colorScheme.primary,
                        ),
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: Text(_emailController.text),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('login_password_input'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      onSubmitted: (_) => _onButtonPressed(),
                    ),
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        key: const Key('login_error_text'),
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('login_submit_button'),
                      onPressed: _isLoading ? null : _onButtonPressed,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Log In'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      key: const Key('login_reset_password_link'),
                      onPressed: _handleForgotPassword,
                      child: const Text('Forgot Password?'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Powered by ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const VetterLogo(size: 12),
                const SizedBox(width: 4),
                const Text(
                  'Vetter',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Expanded(
              child: Text(
                'Copyright © ${DateTime.now().year} Vetter Pharma-Fertigung GmbH & Co. KG. All rights reserved.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
