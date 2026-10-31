import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'core/theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: VitalCheckApp()));
}

class VitalCheckApp extends ConsumerWidget {
  const VitalCheckApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return MaterialApp(
      title: 'VitalCheck',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: auth.loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : auth.token == null
          ? const LoginScreen()
          : const AppShell(),
    );
  }
}
