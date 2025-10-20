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

      // LINE IDで既存ユーザーを検索
      final existingUser = await _findUserByLineId(lineUserId);

      if (existingUser != null) {
        // 既存ユーザーが見つかった場合
        final credential = await _auth.signInAnonymously();

        // 既存のユーザーデータを新しいFirebase UIDに移行
        await _migrateUserData(
          oldUserId: existingUser.userId,
          newUserId: credential.user!.uid,
          lineUserId: lineUserId,
          name: name,
          profileImageUrl: profileImageUrl,
          circleIds: existingUser.circleIds,
        );

        return credential;
      } else {
        // 新規ユーザーの場合
        final credential = await _auth.signInAnonymously();

        // ユーザー情報をFirestoreに保存
        await _saveUserToFirestore(
          userId: credential.user!.uid,
          lineUserId: lineUserId,
          name: name,
          profileImageUrl: profileImageUrl,
        );

        return credential;
      }
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

      // 古いユーザーデータを削除
      await _firestore.collection('users').doc(oldUserId).delete();
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
}
