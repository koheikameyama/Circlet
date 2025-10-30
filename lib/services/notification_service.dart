import 'package:cloud_firestore/cloud_firestore.dart';
import 'logger_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final _uuid = const Uuid();

  // FCMトークンを取得して保存
  Future<void> initializeNotifications(String userId) async {
    try {
      AppLogger.info('Initializing notifications for user: $userId');

      // 通知権限をリクエスト
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      AppLogger.info('Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // FCMトークンを取得
        final token = await _messaging.getToken();
        AppLogger.info('FCM token: ${token != null ? "取得成功" : "取得失敗"}');

        if (token != null) {
          // トークンをFirestoreに保存（mergeを使用してドキュメントがなければ作成）
          try {
            await _firestore.collection('users').doc(userId).set({
              'fcmToken': token,
              'updatedAt': Timestamp.now(),
            }, SetOptions(merge: true));

            AppLogger.info('FCM token saved successfully');
          } catch (saveError) {
            AppLogger.error('Error saving FCM token: $saveError');
          }
        } else {
          AppLogger.warning('FCM token is null');
        }

        // トークンのリフレッシュを監視
        _messaging.onTokenRefresh.listen((newToken) {
          AppLogger.info('FCM token refreshed');
          _firestore.collection('users').doc(userId).set({
            'fcmToken': newToken,
            'updatedAt': Timestamp.now(),
          }, SetOptions(merge: true));
        });
      } else {
        AppLogger.warning('Notification permission denied: ${settings.authorizationStatus}');
      }
    } catch (e) {
      AppLogger.error('Error initializing notifications: $e');
    }
  }

  // フォアグラウンドメッセージを処理
  void setupForegroundNotificationHandling() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.info('Got a message whilst in the foreground!');
      AppLogger.info('Message data: ${message.data}');

      if (message.notification != null) {
        AppLogger.info('Message also contained a notification: ${message.notification}');
      }
    });
  }

  // 通知を送信（個別）
  Future<void> sendNotification({
    required String circleId,
    required String recipientUserId,
    required String title,
    required String body,
    NotificationType type = NotificationType.general,
    String? eventId,
  }) async {
    await _createNotificationRecord(
      circleId: circleId,
      recipientUserIds: [recipientUserId],
      title: title,
      body: body,
      type: type,
      eventId: eventId,
    );
  }

  // 通知を送信（一括）
  Future<void> sendBulkNotification({
    required String circleId,
    required List<String> recipientUserIds,
    required String title,
    required String body,
    NotificationType type = NotificationType.general,
    String? eventId,
  }) async {
    await _createNotificationRecord(
      circleId: circleId,
      recipientUserIds: recipientUserIds,
      title: title,
      body: body,
      type: type,
      eventId: eventId,
    );
  }

  // 通知レコードを作成
  Future<void> _createNotificationRecord({
    required String circleId,
    required List<String> recipientUserIds,
    required String title,
    required String body,
    required NotificationType type,
    String? eventId,
  }) async {
    try {
      final notificationId = _uuid.v4();
      final notification = NotificationModel(
        notificationId: notificationId,
        circleId: circleId,
        eventId: eventId,
        title: title,
        body: body,
        type: type,
        recipientUserIds: recipientUserIds,
        sentAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set(notification.toFirestore());

      // TODO: Cloud Functionsで実際のプッシュ通知を送信
      // この実装では、Firestoreに通知レコードを作成し、
      // Cloud FunctionsのトリガーでFCMメッセージを送信する想定
    } catch (e) {
      AppLogger.error('Error creating notification: $e');
      rethrow;
    }
  }

  // ユーザーの通知一覧を取得
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('recipientUserIds', arrayContains: userId)
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
  }

  // サークルの通知履歴を取得
  Stream<List<NotificationModel>> getCircleNotifications(String circleId) {
    return _firestore
        .collection('notifications')
        .where('circleId', isEqualTo: circleId)
        .orderBy('sentAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
  }

  // イベントリマインダーを送信
  Future<void> sendEventReminder({
    required String eventId,
    required String circleId,
    required List<String> recipientUserIds,
    required String eventName,
    required DateTime eventDatetime,
  }) async {
    await sendBulkNotification(
      circleId: circleId,
      recipientUserIds: recipientUserIds,
      title: 'イベントリマインダー',
      body: '$eventName が ${_formatDateTime(eventDatetime)} に開催されます',
      type: NotificationType.eventReminder,
      eventId: eventId,
    );
  }

  // 支払いリマインダーを送信
  Future<void> sendPaymentReminder({
    required String eventId,
    required String circleId,
    required String recipientUserId,
    required String eventName,
    required int amount,
  }) async {
    await sendNotification(
      circleId: circleId,
      recipientUserId: recipientUserId,
      title: '参加費のお支払いをお願いします',
      body: '$eventName の参加費 ¥$amount のお支払いが未完了です',
      type: NotificationType.paymentReminder,
      eventId: eventId,
    );
  }

  // キャンセル待ち繰り上げ通知を送信
  Future<void> sendWaitlistPromotionNotification({
    required String eventId,
    required String circleId,
    required String recipientUserId,
    required String eventName,
  }) async {
    await sendNotification(
      circleId: circleId,
      recipientUserId: recipientUserId,
      title: 'イベント参加が確定しました',
      body: '$eventName のキャンセル待ちから参加予定に変更されました',
      type: NotificationType.waitlistPromotion,
      eventId: eventId,
    );
  }

  String _formatDateTime(DateTime datetime) {
    return '${datetime.month}月${datetime.day}日 ${datetime.hour}:${datetime.minute.toString().padLeft(2, '0')}';
  }
}
