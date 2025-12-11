class Address {
  final String? street;
  final String? city;
  final String country;

  Address({this.street, this.city, this.country = 'Palestine'});

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'],
      city: json['city'],
      country: json['country'] ?? 'Palestine',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (street != null) 'street': street,
      if (city != null) 'city': city,
      'country': country,
    };
  }

  String get fullAddress {
    final parts = <String>[];
    if (street != null) parts.add(street!);
    if (city != null) parts.add(city!);
    if (country != 'Palestine') parts.add(country);
    return parts.join(', ') + (parts.isEmpty ? 'No address provided' : '');
  }
}
