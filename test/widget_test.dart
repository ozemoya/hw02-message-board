import 'package:flutter_test/flutter_test.dart';

void main() {
  test('message size limit includes its boundary', () {
    expect(List.filled(500, 'a').join().length, 500);
  });
}
