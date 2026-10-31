import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String str(dynamic value, [String fallback = '']) =>
    value?.toString() ?? fallback;
String initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((s) => s.isNotEmpty)
    .take(2)
    .map((s) => s[0].toUpperCase())
    .join();
String dateLabel(dynamic date) {
  final parsed = DateTime.tryParse(str(date));
  return parsed == null
      ? 'Date to be confirmed'
      : DateFormat('EEE, d MMM • h:mm a').format(parsed.toLocal());
}

String money(dynamic amount) =>
    '₦${NumberFormat('#,##0').format(num.tryParse(str(amount)) ?? 3000)}';
Widget avatar(
  String name, {
  double size = 50,
  Color color = const Color(0xFFEAF1FF),
}) => CircleAvatar(
  radius: size / 2,
  backgroundColor: color,
  child: Text(
    initials(name).isEmpty ? 'VC' : initials(name),
    style: TextStyle(
      color: const Color(0xFF2563EB),
      fontWeight: FontWeight.w800,
      fontSize: size * .32,
    ),
  ),
);
