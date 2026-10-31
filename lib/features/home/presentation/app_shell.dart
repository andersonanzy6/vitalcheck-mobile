import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../appointments/presentation/appointments_screen.dart';
import '../../chat/presentation/conversations_screen.dart';
import '../../doctors/presentation/doctors_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import 'dashboard_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  late bool _doctor;
  @override
  void initState() {
    super.initState();
    _doctor =
        (ref.read(authProvider).user?['role'] ?? 'patient')
            .toString()
            .toLowerCase() ==
        'doctor';
  }

  @override
  Widget build(BuildContext context) {
    final labels = _doctor
        ? ['Home', 'Appointments', 'Messages', 'Notifications', 'Profile']
        : ['Home', 'Doctors', 'Appointments', 'Messages', 'Profile'];
    final icons = _doctor
        ? [
            Icons.grid_view_rounded,
            Icons.calendar_month_rounded,
            Icons.chat_bubble_outline,
            Icons.notifications_none,
            Icons.person_outline,
          ]
        : [
            Icons.home_rounded,
            Icons.medical_services_outlined,
            Icons.calendar_month_rounded,
            Icons.chat_bubble_outline,
            Icons.person_outline,
          ];
    final pages = _doctor
        ? <Widget>[
            const DashboardScreen(doctor: true),
            const AppointmentsScreen(doctor: true),
            const ConversationsScreen(),
            const NotificationsScreen(),
            const ProfileScreen(),
          ]
        : <Widget>[
            const DashboardScreen(doctor: false),
            const DoctorsScreen(),
            const AppointmentsScreen(doctor: false),
            const ConversationsScreen(),
            const ProfileScreen(),
          ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'VitalCheck',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _doctor
                ? setState(() => _index = 3)
                : Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: List.generate(
          labels.length,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
    );
  }
}
