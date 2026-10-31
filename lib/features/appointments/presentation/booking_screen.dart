import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/utils/formatters.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.doctor});
  final Map<String, dynamic> doctor;
  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  DateTime? _date;
  String _type = 'consultation';
  bool _paid = false, _loading = false;
  final _symptoms = TextEditingController();
  final _notes = TextEditingController();
  @override
  void dispose() {
    _symptoms.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = str(
      widget.doctor['name'] ?? widget.doctor['user']?['name'],
      'Doctor',
    );
    final doctorId = str(widget.doctor['_id'] ?? widget.doctor['id']);
    return Scaffold(
      appBar: AppBar(title: const Text('Book an appointment')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const _StepDot('1', true),
              Expanded(child: Container(height: 2, color: primaryBlue)),
              _StepDot('2', _paid),
              Expanded(
                child: Container(
                  height: 2,
                  color: _paid ? primaryBlue : const Color(0xFFE0E6EF),
                ),
              ),
              const _StepDot('3', false),
            ],
          ),
          const SizedBox(height: 22),
          SurfaceCard(
            child: Row(
              children: [
                avatar(name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        str(widget.doctor['specialty'], 'Consultation'),
                        style: const TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  money(widget.doctor['consultationFee'] ?? 3000),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Choose date and time'),
          const SizedBox(height: 10),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final today = DateTime.now();
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: today,
                      lastDate: today.add(const Duration(days: 120)),
                      initialDate: today.add(const Duration(days: 1)),
                    );
                    if (selected == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null)
                      setState(
                        () => _date = DateTime(
                          selected.year,
                          selected.month,
                          selected.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    _date == null
                        ? 'Select a date and time'
                        : dateLabel(_date!.toIso8601String()),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Consultation type',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'consultation',
                      child: Text('General consultation'),
                    ),
                    DropdownMenuItem(
                      value: 'follow-up',
                      child: Text('Follow-up'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'consultation'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _symptoms,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Symptoms or reason for visit',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Additional notes (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Payment'),
          const SizedBox(height: 10),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_outlined, color: primaryBlue),
                    SizedBox(width: 10),
                    Text(
                      'Bank transfer',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Fee: ${money(widget.doctor['consultationFee'] ?? 3000)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Complete payment using the method shown in the web booking flow, then confirm below.',
                  style: TextStyle(color: muted),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _paid,
                  onChanged: (v) => setState(() => _paid = v ?? false),
                  title: const Text('I have completed the payment transfer'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _loading
                ? null
                : () async {
                    if (_date == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a date and time'),
                        ),
                      );
                      return;
                    }
                    if (!_paid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Confirm payment before booking'),
                        ),
                      );
                      return;
                    }
                    setState(() => _loading = true);
                    try {
                      await ref.read(apiProvider).post('/appointments/create', {
                        'doctorId': doctorId,
                        'appointmentDate': _date!.toIso8601String(),
                        'appointmentTime': TimeOfDay.fromDateTime(_date!)
                            .format(context),
                        'consultationType': _type,
                        'reasonForVisit':
                            'Symptoms: ${_symptoms.text}. Notes: ${_notes.text}',
                        'paymentStatus': 'payment_pending_verification',
                        'paymentMethod': 'bank_transfer',
                        'amount': widget.doctor['consultationFee'] ?? 3000,
                      });
                      if (context.mounted)
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Request submitted'),
                            content: const Text(
                              'Your appointment request is awaiting confirmation.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.popUntil(
                                  ctx,
                                  (route) => route.isFirst,
                                ),
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        );
                    } catch (error) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Booking failed: $error')),
                        );
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Confirm appointment'),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot(this.text, this.active);
  final String text;
  final bool active;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 16,
    backgroundColor: active ? primaryBlue : const Color(0xFFE2E8F0),
    child: Text(
      text,
      style: TextStyle(
        color: active ? Colors.white : muted,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
