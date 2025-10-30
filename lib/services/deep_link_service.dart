import 'dart:async';
import 'logger_service.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'circle_service.dart';
import 'auth_service.dart';

// DeepLinkServiceのProvider
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return DeepLinkService(
    circleService: CircleService(),
    authService: AuthService(),
  );
});

class DeepLinkService {
  final CircleService circleService;
  final AuthService authService;
  StreamSubscription? _linkSubscription;

  DeepLinkService({
    required this.circleService,
    required this.authService,
  });

  // ディープリンクのリスニングを開始
  Future<void> initDeepLinks({
    required Function(String inviteId) onInviteLink,
    required Function(String error) onError,
  }) async {
    try {
      // アプリ起動時のリンクを取得
      final initialLink = await getInitialUri();
      if (initialLink != null) {
        _handleDeepLink(initialLink, onInviteLink, onError);
      }

      // アプリ実行中のリンクを監視
      _linkSubscription = uriLinkStream.listen(
        (Uri? uri) {
          if (uri != null) {
            _handleDeepLink(uri, onInviteLink, onError);
          }
        },
        onError: (err) {
          onError('ディープリンクの処理中にエラーが発生しました: $err');
        },
      );
    } catch (e) {
      AppLogger.error('Error initializing deep links: $e');
      onError('ディープリンクの初期化に失敗しました');
    }
  }

  // ディープリンクを処理
  void _handleDeepLink(
    Uri uri,
    Function(String inviteId) onInviteLink,
    Function(String error) onError,
  ) {
    AppLogger.info('Deep link received: $uri');

    // circlet://invite/{inviteId} の形式をチェック
    if (uri.scheme == 'circlet' && uri.host == 'invite') {
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final inviteId = pathSegments[0];
        onInviteLink(inviteId);
      } else {
        onError('招待リンクの形式が正しくありません');
      }
    }
    // 将来的にUniversal Links/App Linksに対応する場合
    // https://grumane-3d818.web.app/invite/{inviteId} も処理
    else if (uri.scheme == 'https' &&
             uri.host == 'grumane-3d818.web.app' &&
             uri.pathSegments.length >= 2 &&
             uri.pathSegments[0] == 'invite') {
      final inviteId = uri.pathSegments[1];
      onInviteLink(inviteId);
    }
    else {
      AppLogger.info('Unknown deep link format: $uri');
    }
  }

  // 招待リンクからサークルに参加
  Future<bool> handleInviteLink(String inviteId) async {
    try {
      final userId = authService.currentUser?.uid;
      if (userId == null) {
        AppLogger.info('User not logged in');
        return false;
      }

      final success = await circleService.joinCircleWithInvite(
        inviteId: inviteId,
        userId: userId,
      );

      return success;
    } catch (e) {
      AppLogger.error('Error handling invite link: $e');
      return false;
    }
  }

  // リスニングを停止
  void dispose() {
    _linkSubscription?.cancel();
  }
}
