import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

// AuthServiceのProvider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// 認証状態のProvider
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// 現在のユーザーIDのProvider
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.uid;
});

// 現在のユーザー情報のProvider
final currentUserProvider = StreamProvider.autoDispose<UserModel?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(null);
  }

  final authService = ref.watch(authServiceProvider);
  return authService.getUserDataStream(userId);
});

// ログイン処理のProvider
final signInProvider = FutureProvider.autoDispose<UserCredential?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.signInWithLine();
});

// ログアウト処理のProvider
final signOutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
  };
});

// 特定のユーザー情報を取得するProvider
final userDataProvider = StreamProvider.autoDispose.family<UserModel?, String>((ref, userId) {
  final authService = ref.watch(authServiceProvider);
  return authService.getUserDataStream(userId);
});
