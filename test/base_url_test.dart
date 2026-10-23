import 'package:flutter_test/flutter_test.dart';
import 'package:audioapp/shared/services/backend_api_service.dart';

void main() {
  test('kDefaultBackendBaseUrl reflects configuration', () {
    expect(kDefaultBackendBaseUrl, isNotEmpty);
    expect(kDefaultBackendBaseUrl.startsWith('http'), isTrue);
  });
}
