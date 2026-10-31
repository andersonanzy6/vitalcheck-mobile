import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/login_screen.dart';
import '../../payments/presentation/payments_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user ?? {};
    final name = str(user['name'], 'VitalCheck member');
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Row(
              children: [
                avatar(name, size: 70),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        str(user['email']),
                        style: const TextStyle(color: muted),
                      ),
                      Text(
                        str(user['role'], 'patient').toUpperCase(),
                        style: const TextStyle(
                          color: primaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _edit(context, ref),
                  icon: const Icon(Icons.edit_outlined, color: primaryBlue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _tile(
            context,
            Icons.medical_information_outlined,
            'Medical records',
            'Manage your health documents',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _RecordsScreen()),
              );
            },
          ),
          const SizedBox(height: 10),
          _tile(
            context,
            Icons.payments_outlined,
            'Payments',
            'Payment history and receipts',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentsScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _tile(
            context,
            Icons.lock_outline,
            'Privacy and security',
            'Your account security settings',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Account security is managed by your VitalCheck account.',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted)
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => SurfaceCard(
    onTap: onTap,
    child: Row(
      children: [
        Icon(icon, color: primaryBlue),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: muted),
      ],
    ),
  );
  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(
      text: str(ref.read(authProvider).user?['name']),
    );
    final phone = TextEditingController(
      text: str(ref.read(authProvider).user?['phone']),
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save == true) {
      try {
        await ref.read(apiProvider).put('/auth/profile', {
          'name': name.text,
          'phone': phone.text,
        });
        if (context.mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Profile updated')));
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update profile: $e')),
          );
      }
    }
    name.dispose();
    phone.dispose();
  }
}

class _RecordsScreen extends ConsumerStatefulWidget {
  const _RecordsScreen();
  @override
  ConsumerState<_RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<_RecordsScreen> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = ref.read(apiProvider).get('/medical-records');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Medical records')),
    body: FutureBuilder<dynamic>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorPanel(
              message: 'Records could not be loaded.',
              onRetry: () => setState(
                () => future = ref.read(apiProvider).get('/medical-records'),
              ),
            ),
          );
        final value = snapshot.data;
        final rows = value is List
            ? value
            : value is Map && value['records'] is List
            ? value['records'] as List
            : const [];
        if (rows.isEmpty)
          return const Center(child: Text('No medical records yet'));
        return ListView(
          padding: const EdgeInsets.all(20),
          children: rows.map((e) {
            final r = e is Map ? e : {};
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfaceCard(
                child: ListTile(
                  leading: const Icon(
                    Icons.description_outlined,
                    color: primaryBlue,
                  ),
                  title: Text(str(r['title'] ?? r['name'], 'Medical record')),
                  subtitle: Text(str(r['createdAt'])),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}
