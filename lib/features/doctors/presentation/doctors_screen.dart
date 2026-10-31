import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../appointments/presentation/booking_screen.dart';

class DoctorsScreen extends ConsumerStatefulWidget {
  const DoctorsScreen({super.key});
  @override
  ConsumerState<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends ConsumerState<DoctorsScreen> {
  final _search = TextEditingController();
  late Future<dynamic> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<dynamic> _load() =>
      ref.read(apiProvider).get('/doctors', {'search': _search.text.trim()});
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find a doctor',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 5),
            const Text(
              'Browse verified specialists and book a visit.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _search,
              onSubmitted: (_) => setState(() => _future = _load()),
              decoration: InputDecoration(
                hintText: 'Search doctors or specialty',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _future = _load()),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<dynamic>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return Padding(
                padding: const EdgeInsets.all(20),
                child: ErrorPanel(
                  message: 'Could not load doctors. Try again.',
                  onRetry: () => setState(() => _future = _load()),
                ),
              );
            final raw = snapshot.data;
            final list = raw is List
                ? raw
                : raw is Map
                ? (raw['doctors'] ?? raw['data'] ?? [])
                : [];
            final doctors = list is List ? list : [];
            if (doctors.isEmpty)
              return const Center(child: Text('No doctors found.'));
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: doctors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doctor = doctors[index] is Map
                    ? Map<String, dynamic>.from(doctors[index])
                    : <String, dynamic>{};
                final name = str(
                  doctor['name'] ?? doctor['user']?['name'],
                  'Doctor',
                );
                final specialty = str(
                  doctor['specialty'] ?? doctor['specialization'],
                  'General practice',
                );
                return SurfaceCard(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DoctorDetailScreen(doctor: doctor),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      avatar(name, size: 58),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              specialty,
                              style: const TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFB020),
                                  size: 17,
                                ),
                                Text(
                                  ' ${str(doctor['rating'], '4.8')}  •  ${str(doctor['experience'], 'Experienced')}',
                                ),
                                const Spacer(),
                                Text(
                                  money(doctor['consultationFee'] ?? 3000),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BookingScreen(doctor: doctor),
                                  ),
                                ),
                                child: const Text('Book consultation'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: muted),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class DoctorDetailScreen extends StatelessWidget {
  const DoctorDetailScreen({super.key, required this.doctor});
  final Map<String, dynamic> doctor;
  @override
  Widget build(BuildContext context) {
    final name = str(doctor['name'] ?? doctor['user']?['name'], 'Doctor');
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SurfaceCard(
            child: Column(
              children: [
                avatar(name, size: 92),
                const SizedBox(height: 14),
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  str(
                    doctor['specialty'] ?? doctor['specialization'],
                    'General practice',
                  ),
                  style: const TextStyle(color: primaryBlue),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFB020)),
                    Text(
                      ' ${str(doctor['rating'], '4.8')}  •  ${str(doctor['experience'], 'Experienced')}',
                      style: const TextStyle(color: muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('About'),
          const SizedBox(height: 10),
          SurfaceCard(
            child: Text(
              str(
                doctor['bio'] ?? doctor['about'],
                'A dedicated healthcare professional focused on compassionate, patient-centered care.',
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Consultation fee'),
          const SizedBox(height: 10),
          SurfaceCard(
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, color: primaryBlue),
                const SizedBox(width: 10),
                Text(
                  money(doctor['consultationFee'] ?? 3000),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BookingScreen(doctor: doctor)),
            ),
            icon: const Icon(Icons.calendar_month),
            label: const Text('Book an appointment'),
          ),
        ],
      ),
    );
  }
}
