import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/jyotara_api.dart';

void main() {
  test('local HTTP requires an explicit QA flag and exact loopback host', () {
    const enabled = bool.fromEnvironment('JYOTARA_LOCAL_QA') ||
        bool.fromEnvironment('NIRAYANA_LOCAL_QA');
    if (enabled) {
      expect(
        () => JyotaraApiClient(baseUrl: 'http://127.0.0.1:8787'),
        returnsNormally,
      );
    } else {
      expect(
        () => JyotaraApiClient(baseUrl: 'http://127.0.0.1:8787'),
        throwsArgumentError,
      );
    }
    for (final url in [
      'http://example.com',
      'http://10.0.2.2',
      'http://127.0.0.1.example.com',
      'http://user:password@127.0.0.1',
      'http://localhost',
    ]) {
      expect(() => JyotaraApiClient(baseUrl: url), throwsArgumentError);
    }
    expect(
      () => JyotaraApiClient(baseUrl: 'https://example.com'),
      returnsNormally,
    );
  });
}
