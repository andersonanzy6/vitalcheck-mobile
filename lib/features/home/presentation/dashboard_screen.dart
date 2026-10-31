import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../appointments/presentation/appointments_screen.dart';
import '../../doctors/presentation/doctors_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, required this.doctor});
  final bool doctor;
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late Future<dynamic> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<dynamic> _load() => ref
      .read(apiProvider)
      .get(
        widget.doctor
            ? '/appointments/my-appointments'
            : '/appointments/my-appointments',
      );
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user ?? {};
    final name = str(user['name'], 'there').split(' ').first;
    return RefreshIndicator(
      onRefresh: () async => setState(() => _future = _load()),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            widget.doctor ? 'Good morning, Dr. $name' : 'Hello, $name!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            widget.doctor
                ? 'Here is your practice at a glance.'
                : 'What are your concerns today?',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 20),
          if (!widget.doctor)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF4F86F7)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Care that fits your life',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Find trusted specialists and book a consultation.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryBlue,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DoctorsScreen()),
                    ),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Find a doctor'),
                  ),
                ],
              ),
            ),
          if (!widget.doctor) const SizedBox(height: 22),
          SectionTitle(
            widget.doctor ? 'Practice overview' : 'Your care overview',
          ),
          const SizedBox(height: 12),
          FutureBuilder<dynamic>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              if (snapshot.hasError)
                return ErrorPanel(
                  message: 'Appointments could not be loaded. Check your connection and try again.',
                  onRetry: () => setState(() => _future = _load()),
                );
              final data = snapshot.data;
              final list = data is List
                  ? data
                  : data is Map && data['appointments'] is List
                  ? data['appointments'] as List
                  : const [];
              final completed = list
                  .where((e) => e is Map && e['status'] == 'completed')
                  .length;
              final upcoming = list
                  .where(
                    (e) =>
                        e is Map &&
                        e['status'] != 'cancelled' &&
                        e['status'] != 'completed',
                  )
                  .length;
              return Column(
                children: [
                  Row(
                    children: [
                      _stat(
                        'Total visits',
                        list.length.toString(),
                        Icons.assignment_outlined,
                      ),
                      const SizedBox(width: 10),
                      _stat(
                        widget.doctor ? 'Today' : 'Upcoming',
                        upcoming.toString(),
                        Icons.schedule_rounded,
                      ),
                      const SizedBox(width: 10),
                      _stat(
                        'Completed',
                        completed.toString(),
                        Icons.check_circle_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SectionTitle(
                    widget.doctor
                        ? 'Upcoming appointments'
                        : 'Next appointment',
                    action: 'See all',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AppointmentsScreen(doctor: widget.doctor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (list.isEmpty)
                    SurfaceCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_available_outlined,
                            color: primaryBlue,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Your upcoming appointments will appear here.',
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...list.take(3).map((item) {
                      final apt = item is Map
                          ? Map<String, dynamic>.from(item)
                          : <String, dynamic>{};
                      final other = apt['doctor'] ?? apt['patient'] ?? {};
                      final display = other is Map
                          ? str(other['name'], 'Consultation')
                          : 'Consultation';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SurfaceCard(
                          child: Row(
                            children: [
                              avatar(display),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      display,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateLabel(apt['appointmentDate']),
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: muted),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          const SectionTitle('Why VitalCheck'),
          const SizedBox(height: 12),
          const SurfaceCard(
            child: Column(
              children: [
                _Benefit(
                  icon: Icons.verified_user_outlined,
                  title: 'Trusted care',
                  body: 'Connect with qualified healthcare professionals.',
                ),
                Divider(height: 24),
                _Benefit(
                  icon: Icons.lock_outline,
                  title: 'Private by design',
                  body: 'Your conversations and health information stay protected.',
                ),
                Divider(height: 24),
                _Benefit(
                  icon: Icons.access_time_rounded,
                  title: 'Care on your time',
                  body: 'Book convenient consultations and follow up in one place.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String title, String value, IconData icon) => Expanded(
    child: SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryBlue),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          Text(title, style: const TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: primaryBlue),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(body, style: const TextStyle(color: muted, fontSize: 12)),
          ],
        ),
      ),
    ],
  );
}
