import 'package:cloud_firestore/cloud_firestore.dart';

class CircleMember {
  final String userId;
  final String role;
  final List<String> tags;
  final DateTime joinedAt;
  final String? displayName; // サークル内での表示名（任意）
  final String? profileImageUrl; // サークル内のプロフィール画像URL

  CircleMember({
    required this.userId,
    required this.role,
    required this.tags,
    required this.joinedAt,
    this.displayName,
    this.profileImageUrl,
  });

  factory CircleMember.fromMap(Map<String, dynamic> data) {
    return CircleMember(
      userId: data['userId'] ?? '',
      role: data['role'] ?? 'member',
      tags: List<String>.from(data['tags'] ?? []),
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      displayName: data['displayName'],
      profileImageUrl: data['profileImageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'role': role,
      'tags': tags,
      'joinedAt': Timestamp.fromDate(joinedAt),
      if (displayName != null) 'displayName': displayName,
      if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
    };
  }
}

class CircleModel {
  final String circleId;
  final String name;
  final String description;
  final String? iconUrl;
  final List<CircleMember> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  CircleModel({
    required this.circleId,
    required this.name,
    required this.description,
    this.iconUrl,
    required this.members,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CircleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CircleModel(
      circleId: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      iconUrl: data['iconUrl'],
      members: (data['members'] as List<dynamic>?)
              ?.map((m) => CircleMember.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'members': members.map((m) => m.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CircleModel copyWith({
    String? circleId,
    String? name,
    String? description,
    String? iconUrl,
    List<CircleMember>? members,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CircleModel(
      circleId: circleId ?? this.circleId,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // メンバーのroleで管理者判定
  bool isAdmin(String userId) {
    final member = members.where((m) => m.userId == userId).firstOrNull;
    return member?.role == 'admin';
  }

  bool isMember(String userId) =>
      members.any((member) => member.userId == userId);
}
