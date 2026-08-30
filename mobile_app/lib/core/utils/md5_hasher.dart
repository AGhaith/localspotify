import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class Md5Hasher {
  Md5Hasher._();

  static String generateSalt([int length = 8]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  static String hashToken(String password, String salt) {
    final bytes = utf8.encode('$password$salt');
    final digest = md5.convert(bytes);
    return digest.toString();
  }
}
