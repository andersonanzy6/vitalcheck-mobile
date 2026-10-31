import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/utils/formatters.dart';

class AppointmentsScreen extends ConsumerStatefulWidget {
  const AppointmentsScreen({super.key, required this.doctor});
  final bool doctor;
  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  late Future<dynamic> _future;
  @override
  void initState() {
    super.initState();
    _future = ref.read(apiProvider).get('/appointments/my-appointments');
  }

  Future<void> _reload() async {
    setState(
      () =>
          _future = ref.read(apiProvider).get('/appointments/my-appointments'),
    );
    await _future;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _reload,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.doctor ? 'Appointments' : 'Your appointments',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          widget.doctor
              ? 'Manage your patient visits.'
              : 'Keep track of your upcoming and past care.',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 18),
        FutureBuilder<dynamic>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              );
            if (snapshot.hasError)
              return ErrorPanel(
                message: 'Appointments are unavailable right now.',
                onRetry: _reload,
              );
            final value = snapshot.data;
            final list = value is List
                ? value
                : value is Map && value['appointments'] is List
                ? value['appointments'] as List
                : const [];
            if (list.isEmpty)
              return const SurfaceCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      color: primaryBlue,
                      size: 36,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No appointments yet',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Your scheduled visits will show up here.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              );
            return Column(
              children: list.map<Widget>((raw) {
                final apt = raw is Map
                    ? Map<String, dynamic>.from(raw)
                    : <String, dynamic>{};
                final person = apt[widget.doctor ? 'patient' : 'doctor'] ?? {};
                final name = person is Map
                    ? str(person['name'], 'Consultation')
                    : 'Consultation';
                final status = str(apt['status'], 'pending');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            avatar(name),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    str(
                                      apt['consultationType'],
                                      'Consultation',
                                    ),
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: status == 'completed'
                                    ? const Color(0xFFE8F8EE)
                                    : const Color(0xFFFFF4DD),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: status == 'completed'
                                      ? Colors.green
                                      : const Color(0xFFB36B00),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: primaryBlue,
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(dateLabel(apt['appointmentDate'])),
                            ),
                            Text(
                              money(apt['amount'] ?? 3000),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (!widget.doctor &&
                            status != 'cancelled' &&
                            status != 'completed') ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () async {
                                try {
                                  await ref
                                      .read(apiProvider)
                                      .dio
                                      .patch(
                                        '/appointments/${str(apt['_id'] ?? apt['id'])}/status',
                                        data: {'status': 'cancelled'},
                                      );
                                  await _reload();
                                } catch (e) {
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not cancel appointment: $e',
                                        ),
                                      ),
                                    );
                                }
                              },
                              child: const Text('Cancel appointment'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    ),
  );
}
