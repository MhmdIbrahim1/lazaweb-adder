class Product {
  final String id;
  final String name;
  final String lowercaseName;
  final String brand;
  final double price;
  final double? offerPercentage;
  final String? description;
  final List<int>? colors;
  final List<String>? sizes;
  final List<String> images;

  Product({
    required this.id,
    required this.name,
    required this.lowercaseName,
    required this.brand,
    required this.price,
    this.offerPercentage,
    this.description,
    this.colors,
    this.sizes,
    required this.images,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lowercaseName': lowercaseName,
      'brand': brand,
      'price': price,
      'offerPercentage': offerPercentage,
      'description': description,
      'colors': colors,
      'sizes': sizes,
      'images': images,
    };
  }
}
