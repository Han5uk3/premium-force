/// User model representing a registered user in the Premium Force app.
///
/// Fields match the AWS/MongoDB backend schema:
/// - [uid]: MongoDB ObjectId (assigned by backend)
/// - [username]: Display name
/// - [email]: Email address
/// - [countryCode]: Phone country code (e.g. "+966")
/// - [phoneNumber]: Phone number without country code
/// - [location]: Human-readable address string
/// - [lat] / [long]: Geo-coordinates of the location
/// - [profileImageUrl]: URL of the uploaded profile picture
/// - [specialId]: Optional special ID entered during signup
/// - [role]: User role (e.g. "customer", "admin")
/// - [isActive]: Whether the account is active
/// - [createdAt]: Account creation timestamp
class UserModel {
  final String uid;
  final String username;
  final String email;
  final String countryCode;
  final String phoneNumber;
  final String? location;
  final double? lat;
  final double? long;
  final String? profileImageUrl;
  final String? specialId;
  final String role;
  final bool isActive;
  final String? isDiscountApproved;
  final String? companyEmail;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.countryCode,
    required this.phoneNumber,
    this.location,
    this.lat,
    this.long,
    this.profileImageUrl,
    this.specialId,
    this.role = 'customer',
    this.isActive = true,
    this.isDiscountApproved,
    this.companyEmail,
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // JSON Serialization
  // ---------------------------------------------------------------------------

  /// Creates a [UserModel] from a JSON map returned by the backend.
  ///
  /// Handles the backend's nested objects:
  /// - `profileImage` can be a `String` (URL) or `{ url: "..." }` object
  /// - `location` can be a `String` or `{ lat: ..., long: ... }` object
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // ── Profile image ──────────────────────────────────────
    String? imageUrl;
    final profileRaw = json['profileImage'] ?? json['profileImageUrl'];
    if (profileRaw is String) {
      imageUrl = profileRaw;
    } else if (profileRaw is Map<String, dynamic>) {
      imageUrl = profileRaw['url'] as String?;
    }

    // Modernize relative paths if they don't start with http/https
    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        !imageUrl.startsWith('http')) {
      // Backend images are usually in /uploads or relative to root
      const String host =
          'https://api.premiumforcegroup.com';
      if (imageUrl.startsWith('/')) {
        imageUrl = '$host$imageUrl';
      } else {
        imageUrl = '$host/$imageUrl';
      }
    }

    // ── Location ───────────────────────────────────────────
    String? locationStr;
    double? lat;
    double? lng;
    final locationRaw = json['location'];
    if (locationRaw is String) {
      locationStr = locationRaw;
      lat = (json['lat'] as num?)?.toDouble();
      lng = (json['long'] as num?)?.toDouble();
    } else if (locationRaw is Map<String, dynamic>) {
      lat = (locationRaw['lat'] as num?)?.toDouble();
      lng = (locationRaw['long'] as num?)?.toDouble();
    } else {
      lat = (json['lat'] as num?)?.toDouble();
      lng = (json['long'] as num?)?.toDouble();
    }

    return UserModel(
      uid: (json['_id'] ?? json['id'] ?? json['uid'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      countryCode: (json['countryCode'] ?? '+966').toString(),
      phoneNumber: (json['phoneNumber'] ?? '').toString(),
      location: locationStr,
      lat: lat,
      long: lng,
      profileImageUrl: imageUrl,
      specialId: json['specialId']?.toString(),
      role: (json['role'] ?? 'customer').toString(),
      isActive: (json['isActive'] is bool)
          ? json['isActive'] as bool
          : (json['isactive'] is bool ? json['isactive'] as bool : true),
      isDiscountApproved: json['isDiscountApproved']?.toString(),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is DateTime
                ? json['createdAt'] as DateTime
                : DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      companyEmail: (json['companyEmail'] ?? json['companyMail'])?.toString()
    );
  }

  /// Converts this [UserModel] to a JSON-compatible map for local storage.
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'countryCode': countryCode,
      'phoneNumber': phoneNumber,
      'location': location,
      'lat': lat,
      'long': long,
      'profileImageUrl': profileImageUrl,
      'specialId': specialId,
      'role': role,
      'isActive': isActive,
      'isDiscountApproved': isDiscountApproved,
      'companyEmail': companyEmail,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // Copy With
  // ---------------------------------------------------------------------------

  UserModel copyWith({
    String? uid,
    String? username,
    String? email,
    String? countryCode,
    String? phoneNumber,
    String? location,
    double? lat,
    double? long,
    String? profileImageUrl,
    String? specialId,
    String? role,
    bool? isActive,
    String? isDiscountApproved,
    String? companyEmail,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      countryCode: countryCode ?? this.countryCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      location: location ?? this.location,
      lat: lat ?? this.lat,
      long: long ?? this.long,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      specialId: specialId ?? this.specialId,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      companyEmail: companyEmail ?? this.companyEmail,
      isDiscountApproved: isDiscountApproved ?? this.isDiscountApproved,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Equality & Hashing
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.username == username &&
        other.email == email &&
        other.countryCode == countryCode &&
        other.phoneNumber == phoneNumber &&
        other.location == location &&
        other.lat == lat &&
        other.long == long &&
        other.profileImageUrl == profileImageUrl &&
        other.specialId == specialId &&
        other.role == role &&
        other.isActive == isActive &&
        other.companyEmail == companyEmail &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      uid,
      username,
      email,
      countryCode,
      phoneNumber,
      location,
      lat,
      long,
      profileImageUrl,
      specialId,
      role,
      isActive,
      companyEmail,
      createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Debug
  // ---------------------------------------------------------------------------

  @override
  String toString() {
    return 'UserModel(uid: $uid, username: $username, email: $email, '
        'countryCode: $countryCode, phoneNumber: $phoneNumber, '
        'location: $location, lat: $lat, long: $long, '
        'profileImageUrl: $profileImageUrl, specialId: $specialId, '
        'role: $role, isActive: $isActive, createdAt: $createdAt, '
        'companyEmail: $companyEmail)';
  }
}
