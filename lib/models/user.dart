class User {
  final String id;
  final String name;
  final String linkedinUrl;
  final String? profilePictureUrl;
  final Set<int> scannedBoxes;

  User({
    required this.id,
    required this.name,
    required this.linkedinUrl,
    this.profilePictureUrl,
    this.scannedBoxes = const {},
  });

  User copyWith({
    String? id,
    String? name,
    String? linkedinUrl,
    String? profilePictureUrl,
    Set<int>? scannedBoxes,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      scannedBoxes: scannedBoxes ?? this.scannedBoxes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'linkedinUrl': linkedinUrl,
      'profilePictureUrl': profilePictureUrl,
      'scannedBoxes': scannedBoxes.toList(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      linkedinUrl: json['linkedinUrl'] ?? '',
      profilePictureUrl: json['profilePictureUrl'],
      scannedBoxes: Set<int>.from(json['scannedBoxes'] ?? []),
    );
  }
}

class BingoBox {
  final int id;
  final bool isSelected;
  final String? scannedBy;
  final String? scannedByName;
  final String? scannedByProfilePicture;
  final String? scannedByLinkedIn;
  final String? questionAnswered;
  final DateTime? scannedAt;

  BingoBox({
    required this.id,
    this.isSelected = false,
    this.scannedBy,
    this.scannedByName,
    this.scannedByProfilePicture,
    this.scannedByLinkedIn,
    this.questionAnswered,
    this.scannedAt,
  });

  BingoBox copyWith({
    int? id,
    bool? isSelected,
    String? scannedBy,
    String? scannedByName,
    String? scannedByProfilePicture,
    String? scannedByLinkedIn,
    String? questionAnswered,
    DateTime? scannedAt,
  }) {
    return BingoBox(
      id: id ?? this.id,
      isSelected: isSelected ?? this.isSelected,
      scannedBy: scannedBy ?? this.scannedBy,
      scannedByName: scannedByName ?? this.scannedByName,
      scannedByProfilePicture: scannedByProfilePicture ?? this.scannedByProfilePicture,
      scannedByLinkedIn: scannedByLinkedIn ?? this.scannedByLinkedIn,
      questionAnswered: questionAnswered ?? this.questionAnswered,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }
}