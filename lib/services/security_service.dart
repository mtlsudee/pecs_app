import 'package:encrypt/encrypt.dart' as encrypt;

class SecurityService {
  // NOT: Gerçek bir prodüksiyon uygulamasında bu anahtarı (key) kodun içine gömmeyiz.
  // .env dosyasında veya Flutter Secure Storage'da saklarız.
  // Ancak proje ödevi için bu yöntem (Hardcoded Key) kabul edilebilir ve daha pratiktir.

  // AES-256 şifreleme için 32 karakterlik sabit bir anahtar belirliyoruz.
  static final key = encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows1');

  // IV (Initialization Vector), şifrelemenin rastgeleliğini artırır.
  // Basit olması için burada 16 byte'lık sabit uzunluk kullanıyoruz.
  static final iv = encrypt.IV.fromLength(16);

  static final encrypter = encrypt.Encrypter(encrypt.AES(key));

  /// Veriyi şifreler (Örn: "Ali" -> "U2FsdGVkX1...")
  static String encryptData(String plainText) {
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64; // Veritabanında saklanabilir string formatına çevirir
  }

  /// Şifreli veriyi çözer (Örn: "U2FsdGVkX1..." -> "Ali")
  static String decryptData(String encryptedText) {
    return encrypter.decrypt(encrypt.Encrypted.fromBase64(encryptedText), iv: iv);
  }
}