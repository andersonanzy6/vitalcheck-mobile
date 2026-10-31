import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/utils/formatters.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = ref.read(apiProvider).get('/payments/history');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payments')),
    body: FutureBuilder<dynamic>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorPanel(
              message: 'Payment history could not be loaded.',
              onRetry: () => setState(
                () => future = ref.read(apiProvider).get('/payments/history'),
              ),
            ),
          );
        final raw = snapshot.data;
        final rows = raw is List
            ? raw
            : raw is Map && raw['payments'] is List
            ? raw['payments'] as List
            : const [];
        if (rows.isEmpty)
          return const Center(child: Text('No payment activity yet'));
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final p = rows[i] is Map
                ? Map<String, dynamic>.from(rows[i])
                : <String, dynamic>{};
            return SurfaceCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEAF1FF),
                    child: Icon(
                      Icons.receipt_long_outlined,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          str(p['description'], 'Consultation payment'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          dateLabel(p['createdAt']),
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(p['amount']),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        str(p['status'], 'pending'),
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}
