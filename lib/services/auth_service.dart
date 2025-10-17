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

      // LINEのアクセストークンを使ってFirebase認証
      final credential = await _auth.signInAnonymously();

      // ユーザー情報をFirestoreに保存
      await _saveUserToFirestore(
        userId: credential.user!.uid,
        lineUserId: result.userProfile?.userId ?? '',
        name: result.userProfile?.displayName ?? 'Unknown User',
        profileImageUrl: result.userProfile?.pictureUrl,
      );

      return credential;
    } catch (e) {
      print('LINE login error: $e');
      return null;
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
