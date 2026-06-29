import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

class CryptoHelper {
  // A 32-byte key matching the backend's key for decryption
  static final _key = enc.Key.fromUtf8('panggilin_super_secret_32_bytes_');
  // A 16-byte zero initialization vector (IV) for standard CBC alignment
  static final _iv = enc.IV(Uint8List(16));

  /// Encrypts latitude and longitude values into a Base64-encoded AES-256 ciphertext.
  static String encryptCoordinates(double latitude, double longitude) {
    final plainText = '{"latitude":$latitude,"longitude":$longitude}';
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }
  
  /// Decrypts the coordinates for local testing/verification purposes.
  static Map<String, double> decryptCoordinates(String encryptedBase64) {
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decrypt64(encryptedBase64, iv: _iv);
    
    // Parse json
    final RegExp latRegex = RegExp(r'"latitude":([\d.-]+)');
    final RegExp lngRegex = RegExp(r'"longitude":([\d.-]+)');
    
    final latMatch = latRegex.firstMatch(decrypted);
    final lngMatch = lngRegex.firstMatch(decrypted);
    
    if (latMatch != null && lngMatch != null) {
      return {
        'latitude': double.parse(latMatch.group(1)!),
        'longitude': double.parse(lngMatch.group(1)!),
      };
    }
    
    throw Exception('Failed to parse decrypted coordinate JSON');
  }
}
