import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../home/presentation/app_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  final _name = TextEditingController();
  final _specialty = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _specialty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.health_and_safety_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  _register ? 'Create your account' : 'Welcome to VitalCheck',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your care, connected.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: muted),
                ),
                const SizedBox(height: 28),
                if (_register) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: 'patient',
                    decoration: const InputDecoration(labelText: 'I am a'),
                    items: const [
                      DropdownMenuItem(
                        value: 'patient',
                        child: Text('Patient'),
                      ),
                      DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                    ],
                    onChanged: (value) => _role = value ?? 'patient',
                  ),
                  if (_role == 'doctor') ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _specialty,
                      decoration: const InputDecoration(labelText: 'Specialty'),
                    ),
                  ],
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Text(auth.error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: auth.loading
                      ? null
                      : () async {
                          if (_register) {
                            await ref.read(authProvider.notifier).register({
                              'name': _name.text.trim(),
                              'email': _email.text.trim(),
                              'password': _password.text,
                              'role': _role,
                              ...(_role == 'doctor'
                                  ? {'specialty': _specialty.text.trim()}
                                  : {}),
                            });
                          } else {
                            await ref
                                .read(authProvider.notifier)
                                .login(_email.text.trim(), _password.text);
                          }
                          if (!mounted) return;
                          if (ref.read(authProvider).token != null)
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const AppShell(),
                              ),
                            );
                        },
                  child: auth.loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_register ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => setState(() => _register = !_register),
                  child: Text(
                    _register
                        ? 'Already have an account? Sign in'
                        : 'New to VitalCheck? Create account',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _role = 'patient';
}
