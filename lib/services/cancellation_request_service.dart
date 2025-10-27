import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cancellation_request_model.dart';
import 'event_service.dart';

class CancellationRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EventService _eventService = EventService();

  /// キャンセル申請を作成
  Future<String> createRequest({
    required String eventId,
    required String userId,
    required String reason,
  }) async {
    final now = DateTime.now();
    final requestRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('cancellationRequests')
        .doc();

    final request = CancellationRequestModel(
      requestId: requestRef.id,
      eventId: eventId,
      userId: userId,
      reason: reason,
      status: CancellationRequestStatus.pending,
      createdAt: now,
    );

    await requestRef.set(request.toFirestore());
    return requestRef.id;
  }

  /// イベントの全キャンセル申請を取得
  Future<List<CancellationRequestModel>> getRequestsForEvent(
      String eventId) async {
    final snapshot = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('cancellationRequests')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => CancellationRequestModel.fromFirestore(doc))
        .toList();
  }

  /// イベントの全キャンセル申請のストリーム
  Stream<List<CancellationRequestModel>> getRequestsForEventStream(
      String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('cancellationRequests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CancellationRequestModel.fromFirestore(doc))
            .toList());
  }

  /// 特定ユーザーの特定イベントの承認待ち申請を取得
  Future<CancellationRequestModel?> getUserPendingRequestForEvent({
    required String eventId,
    required String userId,
  }) async {
    final snapshot = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('cancellationRequests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: CancellationRequestStatus.pending.name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    return CancellationRequestModel.fromFirestore(snapshot.docs.first);
  }

  /// 特定ユーザーの特定イベントの承認待ち申請のストリーム
  Stream<CancellationRequestModel?> getUserPendingRequestForEventStream({
    required String eventId,
    required String userId,
  }) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('cancellationRequests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: CancellationRequestStatus.pending.name)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return CancellationRequestModel.fromFirestore(snapshot.docs.first);
    });
  }

  /// 申請を承認（参加者から削除）
  Future<void> approveRequest({
    required String eventId,
    required String requestId,
    required String adminId,
  }) async {
    final requestRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('cancellationRequests')
        .doc(requestId);

    // 申請を取得
    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      throw Exception('申請が見つかりません');
    }

    final request = CancellationRequestModel.fromFirestore(requestDoc);

    // 申請を承認済みに更新
    await requestRef.update({
      'status': CancellationRequestStatus.approved.name,
      'processedAt': Timestamp.fromDate(DateTime.now()),
      'processedBy': adminId,
    });

    // 参加者から削除
    await _eventService.cancelEvent(
      eventId: eventId,
      userId: request.userId,
    );
  }

  /// 申請を却下
  Future<void> rejectRequest({
    required String eventId,
    required String requestId,
    required String adminId,
  }) async {
    final requestRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('cancellationRequests')
        .doc(requestId);

    await requestRef.update({
      'status': CancellationRequestStatus.rejected.name,
      'processedAt': Timestamp.fromDate(DateTime.now()),
      'processedBy': adminId,
    });
  }
}
