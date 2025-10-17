import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/event_model.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // イベントを作成
  Future<String> createEvent({
    required String circleId,
    required String name,
    String? description,
    required DateTime datetime,
    String? location,
    required int maxParticipants,
    int? fee,
  }) async {
    try {
      final eventId = _uuid.v4();
      final event = EventModel(
        eventId: eventId,
        circleId: circleId,
        name: name,
        description: description,
        datetime: datetime,
        location: location,
        maxParticipants: maxParticipants,
        fee: fee,
        participants: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('events')
          .doc(eventId)
          .set(event.toFirestore());

      return eventId;
    } catch (e) {
      print('Error creating event: $e');
      rethrow;
    }
  }

  // イベント情報を取得
  Future<EventModel?> getEvent(String eventId) async {
    try {
      final doc = await _firestore.collection('events').doc(eventId).get();
      if (doc.exists) {
        return EventModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting event: $e');
      return null;
    }
  }

  // イベント情報のストリームを取得
  Stream<EventModel?> getEventStream(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .snapshots()
        .map((doc) => doc.exists ? EventModel.fromFirestore(doc) : null);
  }

  // サークルのイベント一覧を取得
  Stream<List<EventModel>> getCircleEvents(String circleId) {
    return _firestore
        .collection('events')
        .where('circleId', isEqualTo: circleId)
        .orderBy('datetime', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList());
  }

  // イベント情報を更新
  Future<void> updateEvent({
    required String eventId,
    String? name,
    String? description,
    DateTime? datetime,
    String? location,
    int? maxParticipants,
    int? fee,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': Timestamp.now(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (datetime != null) updates['datetime'] = Timestamp.fromDate(datetime);
      if (location != null) updates['location'] = location;
      if (maxParticipants != null) updates['maxParticipants'] = maxParticipants;
      if (fee != null) updates['fee'] = fee;

      await _firestore.collection('events').doc(eventId).update(updates);
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
  }

  // イベントに参加
  Future<void> joinEvent({
    required String eventId,
    required String userId,
  }) async {
    try {
      final event = await getEvent(eventId);
      if (event == null) return;

      // すでに参加している場合は何もしない
      if (event.participants.any((p) => p.userId == userId)) {
        return;
      }

      final participant = EventParticipant(
        userId: userId,
        status: event.isFull
            ? ParticipationStatus.waitlist
            : ParticipationStatus.confirmed,
        waitingNumber: event.isFull ? event.waitlistCount + 1 : null,
        registeredAt: DateTime.now(),
      );

      await _firestore.collection('events').doc(eventId).update({
        'participants': FieldValue.arrayUnion([participant.toMap()]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error joining event: $e');
      rethrow;
    }
  }

  // イベントをキャンセル
  Future<void> cancelEvent({
    required String eventId,
    required String userId,
  }) async {
    try {
      final event = await getEvent(eventId);
      if (event == null) return;

      final participant = event.participants.firstWhere(
        (p) => p.userId == userId,
      );

      // 参加確定者がキャンセルした場合、キャンセル待ちから繰り上げ
      if (participant.status == ParticipationStatus.confirmed) {
        await _promoteFromWaitlist(eventId, event);
      }

      // 参加者リストから削除
      final updatedParticipants = event.participants
          .where((p) => p.userId != userId)
          .map((p) => p.toMap())
          .toList();

      await _firestore.collection('events').doc(eventId).update({
        'participants': updatedParticipants,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error canceling event: $e');
      rethrow;
    }
  }

  // キャンセル待ちから繰り上げ
  Future<void> _promoteFromWaitlist(String eventId, EventModel event) async {
    final waitlistParticipants = event.participants
        .where((p) => p.status == ParticipationStatus.waitlist)
        .toList()
      ..sort((a, b) => a.waitingNumber!.compareTo(b.waitingNumber!));

    if (waitlistParticipants.isEmpty) return;

    // 最初のキャンセル待ち参加者を確定に変更
    final promotedParticipant = waitlistParticipants.first;
    final updatedParticipants = event.participants.map((p) {
      if (p.userId == promotedParticipant.userId) {
        return p.copyWith(
          status: ParticipationStatus.confirmed,
          waitingNumber: null,
        );
      }
      // 他のキャンセル待ち参加者の番号を繰り下げ
      if (p.status == ParticipationStatus.waitlist &&
          p.waitingNumber! > promotedParticipant.waitingNumber!) {
        return p.copyWith(waitingNumber: p.waitingNumber! - 1);
      }
      return p;
    }).map((p) => p.toMap()).toList();

    await _firestore.collection('events').doc(eventId).update({
      'participants': updatedParticipants,
      'updatedAt': Timestamp.now(),
    });

    // TODO: 繰り上げ通知を送信
  }

  // イベントを削除
  Future<void> deleteEvent(String eventId) async {
    try {
      // イベントに関連する支払い情報を削除
      final payments = await _firestore
          .collection('payments')
          .where('eventId', isEqualTo: eventId)
          .get();
      for (final payment in payments.docs) {
        await payment.reference.delete();
      }

      // イベントを削除
      await _firestore.collection('events').doc(eventId).delete();
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }

  // ユーザーが参加するイベント一覧を取得
  Stream<List<EventModel>> getUserEvents(String userId) {
    return _firestore
        .collection('events')
        .where('participants', arrayContains: {'userId': userId})
        .orderBy('datetime', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList());
  }
}
