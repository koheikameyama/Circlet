import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 現在のユーザーを取得
  User? get currentUser => _auth.currentUser;

  // 認証状態の変更を監視
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // LINEログイン
  Future<UserCredential?> signInWithLine() async {
    try {
      // LINE SDKでログイン
      final result = await LineSDK.instance.login();

      if (result.accessToken.value.isEmpty) {
        throw Exception('LINE login failed: No access token');
      }

      final lineUserId = result.userProfile?.userId ?? '';
      final name = result.userProfile?.displayName ?? 'Unknown User';
      final profileImageUrl = result.userProfile?.pictureUrl;

      // LINE User IDを使ってメールアドレスとパスワードを生成
      final email = '$lineUserId@line.user';
      final password = lineUserId; // シンプルにLINE User IDをパスワードとして使用

      print('Attempting LINE login with email: $email');

      // 既存の匿名認証ユーザーをチェック（移行用）
      final existingAnonymousUser = await _findUserByLineId(lineUserId);

      UserCredential credential;

      try {
        // 既存のEmail/Passwordアカウントでサインイン
        credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('Signed in with existing email/password account');

        // ユーザー情報を最新に更新
        await _saveUserToFirestore(
          userId: credential.user!.uid,
          lineUserId: lineUserId,
          name: name,
          profileImageUrl: profileImageUrl,
        );
      } catch (e) {
        print('No existing email/password account, creating new one: $e');

        // アカウントが存在しない場合、新規作成
        credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('Created new email/password account: ${credential.user!.uid}');

        // 既存の匿名認証ユーザーがいる場合、データを移行
        if (existingAnonymousUser != null) {
          print('Migrating data from anonymous user: ${existingAnonymousUser.userId}');
          await _migrateUserData(
            oldUserId: existingAnonymousUser.userId,
            newUserId: credential.user!.uid,
            lineUserId: lineUserId,
            name: name,
            profileImageUrl: profileImageUrl,
            circleIds: existingAnonymousUser.circleIds,
          );
        } else {
          // 新規ユーザーの場合、ユーザー情報を保存
          await _saveUserToFirestore(
            userId: credential.user!.uid,
            lineUserId: lineUserId,
            name: name,
            profileImageUrl: profileImageUrl,
          );
        }
      }

      return credential;
    } catch (e) {
      print('LINE login error: $e');
      return null;
    }
  }

  // LINE IDで既存ユーザーを検索
  Future<UserModel?> _findUserByLineId(String lineUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('lineUserId', isEqualTo: lineUserId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error finding user by LINE ID: $e');
      return null;
    }
  }

  // ユーザーデータを新しいFirebase UIDに移行
  Future<void> _migrateUserData({
    required String oldUserId,
    required String newUserId,
    required String lineUserId,
    required String name,
    String? profileImageUrl,
    required List<String> circleIds,
  }) async {
    try {
      print('Migrating user data from $oldUserId to $newUserId');

      // 新しいFirebase UIDでユーザーデータを作成
      final user = UserModel(
        userId: newUserId,
        name: name,
        lineUserId: lineUserId,
        profileImageUrl: profileImageUrl,
        circleIds: circleIds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(newUserId).set(user.toFirestore());

      // サークルのメンバー情報を更新
      for (final circleId in circleIds) {
        await _updateCircleMemberUserId(circleId, oldUserId, newUserId);
      }

      // イベントの参加者情報を更新
      await _updateEventParticipantUserId(oldUserId, newUserId);

      // 支払い情報を更新
      await _updatePaymentUserId(oldUserId, newUserId);

      // 古いユーザーデータを削除
      await _firestore.collection('users').doc(oldUserId).delete();

      print('User data migration completed');
    } catch (e) {
      print('Error migrating user data: $e');
      rethrow;
    }
  }

  // サークルのメンバー情報でユーザーIDを更新
  Future<void> _updateCircleMemberUserId(
    String circleId,
    String oldUserId,
    String newUserId,
  ) async {
    try {
      final circleDoc = await _firestore.collection('circles').doc(circleId).get();

      if (!circleDoc.exists) return;

      final data = circleDoc.data();
      if (data == null) return;

      final members = (data['members'] as List<dynamic>?) ?? [];

      // メンバーリストでユーザーIDを更新
      final updatedMembers = members.map((member) {
        if (member['userId'] == oldUserId) {
          return {
            ...member as Map<String, dynamic>,
            'userId': newUserId,
          };
        }
        return member;
      }).toList();

      await _firestore.collection('circles').doc(circleId).update({
        'members': updatedMembers,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error updating circle member: $e');
    }
  }

  // イベントの参加者情報でユーザーIDを更新
  Future<void> _updateEventParticipantUserId(
    String oldUserId,
    String newUserId,
  ) async {
    try {
      // ユーザーが参加しているすべてのイベントを検索
      final eventsQuery = await _firestore
          .collection('events')
          .where('participants', arrayContains: {'userId': oldUserId})
          .get();

      // 見つからない場合は、より広範囲に検索
      if (eventsQuery.docs.isEmpty) {
        final allEventsQuery = await _firestore.collection('events').get();

        for (final eventDoc in allEventsQuery.docs) {
          final data = eventDoc.data();
          final participants = (data['participants'] as List<dynamic>?) ?? [];

          bool needsUpdate = false;
          final updatedParticipants = participants.map((participant) {
            if (participant['userId'] == oldUserId) {
              needsUpdate = true;
              return {
                ...participant as Map<String, dynamic>,
                'userId': newUserId,
              };
            }
            return participant;
          }).toList();

          if (needsUpdate) {
            await eventDoc.reference.update({
              'participants': updatedParticipants,
              'updatedAt': Timestamp.now(),
            });
            print('Updated event ${eventDoc.id} participants');
          }
        }
      } else {
        // 各イベントの参加者リストを更新
        for (final eventDoc in eventsQuery.docs) {
          final data = eventDoc.data();
          final participants = (data['participants'] as List<dynamic>?) ?? [];

          final updatedParticipants = participants.map((participant) {
            if (participant['userId'] == oldUserId) {
              return {
                ...participant as Map<String, dynamic>,
                'userId': newUserId,
              };
            }
            return participant;
          }).toList();

          await eventDoc.reference.update({
            'participants': updatedParticipants,
            'updatedAt': Timestamp.now(),
          });
        }
      }
    } catch (e) {
      print('Error updating event participants: $e');
    }
  }

  // 支払い情報でユーザーIDを更新
  Future<void> _updatePaymentUserId(
    String oldUserId,
    String newUserId,
  ) async {
    try {
      // ユーザーのすべての支払い情報を検索
      final paymentsQuery = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: oldUserId)
          .get();

      // 各支払い情報を更新
      for (final paymentDoc in paymentsQuery.docs) {
        await paymentDoc.reference.update({
          'userId': newUserId,
          'updatedAt': Timestamp.now(),
        });
      }

      print('Updated ${paymentsQuery.docs.length} payment records');
    } catch (e) {
      print('Error updating payments: $e');
    }
  }

  // ユーザー情報をFirestoreに保存
  Future<void> _saveUserToFirestore({
    required String userId,
    required String lineUserId,
    required String name,
    String? profileImageUrl,
  }) async {
    final userDoc = _firestore.collection('users').doc(userId);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      // 新規ユーザーの場合
      final user = UserModel(
        userId: userId,
        name: name,
        lineUserId: lineUserId,
        profileImageUrl: profileImageUrl,
        circleIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await userDoc.set(user.toFirestore());
    } else {
      // 既存ユーザーの場合は更新日時のみ更新
      await userDoc.update({
        'updatedAt': Timestamp.now(),
        'profileImageUrl': profileImageUrl,
        'name': name,
      });
    }
  }

  // Firestoreからユーザー情報を取得
  Future<UserModel?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // ユーザー情報のストリームを取得
  Stream<UserModel?> getUserDataStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // ログアウト
  Future<void> signOut() async {
    try {
      await LineSDK.instance.logout();
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // ユーザーアカウントを削除
  Future<void> deleteAccount() async {
    try {
      final userId = currentUser?.uid;
      if (userId != null) {
        // Firestoreからユーザーデータを削除
        await _firestore.collection('users').doc(userId).delete();

        // Firebase Authenticationからユーザーを削除
        await currentUser?.delete();
      }
    } catch (e) {
      print('Delete account error: $e');
      rethrow;
    }
  }

  // デバッグ用：ダミーユーザーを作成
  Future<void> createDummyUser({
    required String userId,
    required String name,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'userId': userId,
        'name': name,
        'lineUserId': 'dummy_line_$userId',
        'circleIds': [],
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      print('Created dummy user: $name ($userId)');
    } catch (e) {
      print('Error creating dummy user: $e');
      rethrow;
    }
  }
}
