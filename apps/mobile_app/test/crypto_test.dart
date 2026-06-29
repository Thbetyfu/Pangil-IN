import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/utils/crypto_helper.dart';

void main() {
  test('CryptoHelper encrypts and decrypts coordinates correctly', () {
    const double lat = -6.90344;
    const double lng = 107.61872;

    // 1. Encrypt coordinates
    final String encrypted = CryptoHelper.encryptCoordinates(lat, lng);
    expect(encrypted, isNotNull);
    expect(encrypted, isNotEmpty);
    expect(encrypted, isNot(equals('{"latitude":-6.90344,"longitude":107.61872}')));

    // 2. Decrypt coordinates and verify original values match
    final Map<String, double> decrypted = CryptoHelper.decryptCoordinates(encrypted);
    expect(decrypted['latitude'], equals(lat));
    expect(decrypted['longitude'], equals(lng));
  });
}
