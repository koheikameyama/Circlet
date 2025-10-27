import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cancellation_request_model.dart';
import '../services/cancellation_request_service.dart';

// CancellationRequestServiceのプロバイダ
final cancellationRequestServiceProvider =
    Provider<CancellationRequestService>((ref) {
  return CancellationRequestService();
});

// イベントの全キャンセル申請のストリーム
final eventCancellationRequestsProvider = StreamProvider.autoDispose
    .family<List<CancellationRequestModel>, String>((ref, eventId) {
  final service = ref.watch(cancellationRequestServiceProvider);
  return service.getRequestsForEventStream(eventId);
});

// 特定ユーザーの承認待ち申請のストリーム
final userPendingRequestProvider = StreamProvider.autoDispose
    .family<CancellationRequestModel?, ({String eventId, String userId})>(
        (ref, params) {
  final service = ref.watch(cancellationRequestServiceProvider);
  return service.getUserPendingRequestForEventStream(
    eventId: params.eventId,
    userId: params.userId,
  );
});

// キャンセル申請作成のプロバイダ
final createCancellationRequestProvider = Provider<
    Future<String> Function({
      required String eventId,
      required String userId,
      required String reason,
    })>((ref) {
  return ({
    required String eventId,
    required String userId,
    required String reason,
  }) async {
    final service = ref.read(cancellationRequestServiceProvider);
    return await service.createRequest(
      eventId: eventId,
      userId: userId,
      reason: reason,
    );
  };
});

// 申請承認のプロバイダ
final approveCancellationRequestProvider = Provider<
    Future<void> Function({
      required String eventId,
      required String requestId,
      required String adminId,
    })>((ref) {
  return ({
    required String eventId,
    required String requestId,
    required String adminId,
  }) async {
    final service = ref.read(cancellationRequestServiceProvider);
    await service.approveRequest(
      eventId: eventId,
      requestId: requestId,
      adminId: adminId,
    );
  };
});

// 申請却下のプロバイダ
final rejectCancellationRequestProvider = Provider<
    Future<void> Function({
      required String eventId,
      required String requestId,
      required String adminId,
    })>((ref) {
  return ({
    required String eventId,
    required String requestId,
    required String adminId,
  }) async {
    final service = ref.read(cancellationRequestServiceProvider);
    await service.rejectRequest(
      eventId: eventId,
      requestId: requestId,
      adminId: adminId,
    );
  };
});
