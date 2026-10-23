import 'text.dart';

/// Coordonnées facultatives, conservées uniquement sur l'appareil.
class AccountantContact {
  AccountantContact({
    required String name,
    String? contact,
    String? address,
    String? addressExtra,
    String? postalCode,
    String? city,
    String? phone,
    String? email,
  }) : name = name.trim(),
       contact = cleanText(contact),
       address = cleanText(address),
       addressExtra = cleanText(addressExtra),
       postalCode = cleanText(postalCode),
       city = cleanText(city),
       phone = cleanText(phone),
       email = cleanText(email) {
    if (this.name.isEmpty) throw ArgumentError('Nom du cabinet requis.');
    if (this.email != null && !validEmail(this.email!)) {
      throw ArgumentError('Adresse email invalide.');
    }
  }

  final String name;
  final String? contact, address, addressExtra, postalCode, city, phone, email;

  static bool validEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
}
