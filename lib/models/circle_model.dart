import 'package:cloud_firestore/cloud_firestore.dart';

class CircleMember {
  final String userId;
  final String role;
  final List<String> tags;
  final DateTime joinedAt;

  CircleMember({
    required this.userId,
    required this.role,
    required this.tags,
    required this.joinedAt,
  });

  factory CircleMember.fromMap(Map<String, dynamic> data) {
    return CircleMember(
      userId: data['userId'] ?? '',
      role: data['role'] ?? 'member',
      tags: List<String>.from(data['tags'] ?? []),
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'role': role,
      'tags': tags,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}

class CircleModel {
  final String circleId;
  final String name;
  final String description;
  final String? iconUrl;
  final String adminId;
  final List<CircleMember> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  CircleModel({
    required this.circleId,
    required this.name,
    required this.description,
    this.iconUrl,
    required this.adminId,
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
      adminId: data['adminId'] ?? '',
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
      'adminId': adminId,
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
    String? adminId,
    List<CircleMember>? members,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CircleModel(
      circleId: circleId ?? this.circleId,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      adminId: adminId ?? this.adminId,
      members: members ?? this.members,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool isAdmin(String userId) => adminId == userId;

  bool isMember(String userId) =>
      members.any((member) => member.userId == userId);
}
