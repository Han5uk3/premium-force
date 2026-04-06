/// Model for Banner data from the backend.
class BannerModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String imageUrlAr;
  final bool isActive;
  final DateTime createdAt;

  BannerModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.imageUrlAr,
    required this.isActive,
    required this.createdAt,
  });

  /// Factory constructor to create a BannerModel from JSON.
  factory BannerModel.fromJson(Map<String, dynamic> json) {
    String imageUrl = '';
    final imageRaw = json['imageUrl'] ?? json['image'];

    if (imageRaw is String) {
      imageUrl = imageRaw;
    } else if (imageRaw is Map<String, dynamic>) {
      imageUrl = (imageRaw['url'] ?? imageRaw['imageUrl'] ?? '').toString();
    }

    String imageUrlAr = '';
    final imageArRaw = json['imageAr'];
    if (imageArRaw is String) {
      imageUrlAr = imageArRaw;
    } else if (imageArRaw is Map<String, dynamic>) {
      imageUrlAr =
          (imageArRaw['url'] ?? imageArRaw['imageUrl'] ?? '').toString();
    }

    // Modernize relative paths if they don't start with http/https
    const String host = 'https://api.premiumforcegroup.com';

    if (imageUrl.isNotEmpty &&
        !imageUrl.startsWith('http') &&
        !imageUrl.startsWith('assets/')) {
      if (imageUrl.startsWith('/')) {
        imageUrl = '$host$imageUrl';
      } else {
        imageUrl = '$host/$imageUrl';
      }
    }

    if (imageUrlAr.isNotEmpty &&
        !imageUrlAr.startsWith('http') &&
        !imageUrlAr.startsWith('assets/')) {
      if (imageUrlAr.startsWith('/')) {
        imageUrlAr = '$host$imageUrlAr';
      } else {
        imageUrlAr = '$host/$imageUrlAr';
      }
    }

    return BannerModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: imageUrl,
      imageUrlAr: imageUrlAr,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }

  /// Convert BannerModel to JSON.
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'imageUrlAr': imageUrlAr,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
