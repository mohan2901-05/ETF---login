import 'package:intl/intl.dart';

final _rupeeGroups = NumberFormat.decimalPattern('en_IN');

String formatLoanAmount(int paise) {
  final magnitude = paise.abs();
  final rupees = _rupeeGroups.format(magnitude ~/ 100);
  final fraction = magnitude % 100;
  final sign = paise < 0 ? '−' : '';
  return fraction == 0
      ? '$sign₹$rupees'
      : '$sign₹$rupees.${fraction.toString().padLeft(2, '0')}';
}
