import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';

// PaymentServiceのProvider
final paymentServiceProvider = Provider<PaymentService>((ref) => PaymentService());

// イベントの支払い一覧のProvider
final eventPaymentsProvider = StreamProvider.autoDispose.family<List<PaymentModel>, String>((ref, eventId) {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getEventPayments(eventId);
});

// ユーザーの支払い一覧のProvider
final userPaymentsProvider = StreamProvider.autoDispose.family<List<PaymentModel>, String>((ref, userId) {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getUserPayments(userId);
});

// サークルの支払い一覧のProvider
final circlePaymentsProvider = StreamProvider.autoDispose.family<List<PaymentModel>, String>((ref, circleId) {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getCirclePayments(circleId);
});

// 支払い作成のProvider
final createPaymentProvider = Provider<Future<String> Function({
  required String userId,
  required String eventId,
  required String circleId,
  required int amount,
  PaymentMethod method,
})>((ref) {
  return ({
    required String userId,
    required String eventId,
    required String circleId,
    required int amount,
    PaymentMethod method = PaymentMethod.paypay,
  }) async {
    final paymentService = ref.read(paymentServiceProvider);
    return await paymentService.createPayment(
      userId: userId,
      eventId: eventId,
      circleId: circleId,
      amount: amount,
      method: method,
    );
  };
});

// 支払いステータス更新のProvider
final updatePaymentStatusProvider = Provider<Future<void> Function({
  required String paymentId,
  required PaymentStatus status,
  String? transactionId,
})>((ref) {
  return ({
    required String paymentId,
    required PaymentStatus status,
    String? transactionId,
  }) async {
    final paymentService = ref.read(paymentServiceProvider);
    await paymentService.updatePaymentStatus(
      paymentId: paymentId,
      status: status,
      transactionId: transactionId,
    );
  };
});
