import 'package:flutter_test/flutter_test.dart';
import 'package:vitalcheck_mobile/main.dart';

void main() {
  test('app entrypoint is a widget', () {
    expect(const VitalCheckApp(), isNotNull);
  });
}
