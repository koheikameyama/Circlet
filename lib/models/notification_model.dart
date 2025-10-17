import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  eventReminder,
  paymentReminder,
  waitlistPromotion,
  general,
}

class NotificationModel {
  final String notificationId;
  final String circleId;
  final String? eventId;
  final String title;
  final String body;
  final NotificationType type;
  final List<String> recipientUserIds; // 受信者のユーザーIDリスト
  final DateTime sentAt;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.circleId,
    this.eventId,
    required this.title,
    required this.body,
    required this.type,
    required this.recipientUserIds,
    required this.sentAt,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      notificationId: doc.id,
      circleId: data['circleId'] ?? '',
      eventId: data['eventId'],
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.general,
      ),
      recipientUserIds: List<String>.from(data['recipientUserIds'] ?? []),
      sentAt: (data['sentAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'circleId': circleId,
      'eventId': eventId,
      'title': title,
      'body': body,
      'type': type.name,
      'recipientUserIds': recipientUserIds,
      'sentAt': Timestamp.fromDate(sentAt),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  NotificationModel copyWith({
    String? notificationId,
    String? circleId,
    String? eventId,
    String? title,
    String? body,
    NotificationType? type,
    List<String>? recipientUserIds,
    DateTime? sentAt,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      notificationId: notificationId ?? this.notificationId,
      circleId: circleId ?? this.circleId,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      recipientUserIds: recipientUserIds ?? this.recipientUserIds,
      sentAt: sentAt ?? this.sentAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
