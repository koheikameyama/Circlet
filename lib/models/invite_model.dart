import 'package:cloud_firestore/cloud_firestore.dart';

class InviteModel {
  final String inviteId;
  final String circleId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;

  InviteModel({
    required this.inviteId,
    required this.circleId,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
    this.isActive = true,
  });

  factory InviteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InviteModel(
      inviteId: doc.id,
      circleId: data['circleId'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'circleId': circleId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': isActive,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => isActive && !isExpired;
}
