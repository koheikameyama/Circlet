import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/payment_model.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // 支払いレコードを作成
  Future<String> createPayment({
    required String userId,
    required String eventId,
    required String circleId,
    required int amount,
    PaymentMethod method = PaymentMethod.paypay,
  }) async {
    try {
      final paymentId = _uuid.v4();
      final payment = PaymentModel(
        paymentId: paymentId,
        userId: userId,
        eventId: eventId,
        circleId: circleId,
        amount: amount,
        status: PaymentStatus.pending,
        method: method,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('payments')
          .doc(paymentId)
          .set(payment.toFirestore());

      return paymentId;
    } catch (e) {
      print('Error creating payment: $e');
      rethrow;
    }
  }

  // 支払い情報を取得
  Future<PaymentModel?> getPayment(String paymentId) async {
    try {
      final doc = await _firestore.collection('payments').doc(paymentId).get();
      if (doc.exists) {
        return PaymentModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting payment: $e');
      return null;
    }
  }

  // ユーザーの支払い情報のストリームを取得
  Stream<List<PaymentModel>> getUserPayments(String userId) {
    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList());
  }

  // イベントの支払い情報のストリームを取得
  Stream<List<PaymentModel>> getEventPayments(String eventId) {
    return _firestore
        .collection('payments')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList());
  }

  // サークルの支払い情報のストリームを取得
  Stream<List<PaymentModel>> getCirclePayments(String circleId) {
    return _firestore
        .collection('payments')
        .where('circleId', isEqualTo: circleId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList());
  }

  // PayPay決済を開始
  Future<String?> initiatePayPayPayment({
    required String paymentId,
    required int amount,
  }) async {
    try {
      // TODO: PayPay APIとの連携を実装
      // 1. PayPay APIを呼び出して決済URLを取得
      // 2. transactionIdを取得してFirestoreに保存

      // 仮実装: 決済URLを返す
      final paymentUrl = 'https://paypay.ne.jp/payment/$paymentId';

      await _firestore.collection('payments').doc(paymentId).update({
        'status': PaymentStatus.pending.name,
        'updatedAt': Timestamp.now(),
      });

      return paymentUrl;
    } catch (e) {
      print('Error initiating PayPay payment: $e');
      return null;
    }
  }

  // 支払いステータスを更新
  Future<void> updatePaymentStatus({
    required String paymentId,
    required PaymentStatus status,
    String? transactionId,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status.name,
        'updatedAt': Timestamp.now(),
      };

      if (status == PaymentStatus.completed) {
        updates['paidAt'] = Timestamp.now();
      }

      if (transactionId != null) {
        updates['transactionId'] = transactionId;
      }

      await _firestore.collection('payments').doc(paymentId).update(updates);
    } catch (e) {
      print('Error updating payment status: $e');
      rethrow;
    }
  }

  // PayPay Webhookからの通知を処理（Cloud Functionsで実装を想定）
  Future<void> handlePayPayWebhook({
    required String transactionId,
    required String status,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('payments')
          .where('transactionId', isEqualTo: transactionId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final paymentDoc = querySnapshot.docs.first;
        PaymentStatus paymentStatus;

        switch (status.toLowerCase()) {
          case 'completed':
          case 'success':
            paymentStatus = PaymentStatus.completed;
            break;
          case 'failed':
            paymentStatus = PaymentStatus.failed;
            break;
          default:
            paymentStatus = PaymentStatus.pending;
        }

        await updatePaymentStatus(
          paymentId: paymentDoc.id,
          status: paymentStatus,
        );
      }
    } catch (e) {
      print('Error handling PayPay webhook: $e');
      rethrow;
    }
  }

  // 特定のユーザーとイベントの支払い情報を取得
  Future<PaymentModel?> getUserEventPayment({
    required String userId,
    required String eventId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .where('eventId', isEqualTo: eventId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return PaymentModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error getting user event payment: $e');
      return null;
    }
  }

  // 未払いの支払い一覧を取得
  Stream<List<PaymentModel>> getPendingPayments(String userId) {
    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: PaymentStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList());
  }
}
