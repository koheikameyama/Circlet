import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  admin,
  member,
}

class UserModel {
  final String userId;
  final String name;
  final String? lineUserId;  // オプショナルに変更
  final String? profileImageUrl;
  final String? email;
  final List<String> circleIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.userId,
    required this.name,
    this.lineUserId,  // オプショナルに変更
    this.profileImageUrl,
    this.email,
    required this.circleIds,
    required this.createdAt,
    required this.updatedAt,
  });

  // Firestore からデータを取得
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      userId: doc.id,
      name: data['name'] ?? '',
      lineUserId: data['lineUserId'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      email: data['email'],
      circleIds: List<String>.from(data['circleIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Firestore へデータを保存
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'lineUserId': lineUserId,
      'profileImageUrl': profileImageUrl,
      'email': email,
      'circleIds': circleIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? userId,
    String? name,
    String? lineUserId,
    String? profileImageUrl,
    String? email,
    List<String>? circleIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      lineUserId: lineUserId ?? this.lineUserId,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      email: email ?? this.email,
      circleIds: circleIds ?? this.circleIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
