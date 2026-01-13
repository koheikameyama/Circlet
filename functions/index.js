const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

// Firestoreトリガー: 通知作成時にFCMメッセージを送信
exports.sendNotificationOnCreate = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();

    console.log('Notification created:', notification);

    try {
      // 受信者のFCMトークンを取得
      const recipientIds = notification.recipientUserIds || [];
      if (recipientIds.length === 0) {
        console.log('No recipients found');
        return null;
      }

      // 各受信者のFCMトークンを取得
      const tokens = [];
      for (const userId of recipientIds) {
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData.fcmToken) {
            tokens.push(userData.fcmToken);
          }
        }
      }

      if (tokens.length === 0) {
        console.log('No FCM tokens found');
        return null;
      }

      // FCMメッセージを作成
      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: {
          notificationId: context.params.notificationId,
          circleId: notification.circleId || '',
          eventId: notification.eventId || '',
          type: notification.type || 'general',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
        tokens: tokens,
      };

      // FCMメッセージを送信
      const response = await admin.messaging().sendEachForMulticast(message);

      console.log(`Successfully sent ${response.successCount} messages`);
      if (response.failureCount > 0) {
        console.log(`Failed to send ${response.failureCount} messages`);
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Error sending to ${tokens[idx]}:`, resp.error);
          }
        });
      }

      return response;
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });

// Cloud Scheduler: 毎日朝9時にイベント前日リマインドを送信
exports.sendEventReminders = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('Asia/Tokyo')
  .onRun(async (context) => {
    console.log('Running event reminder job');

    try {
      const now = admin.firestore.Timestamp.now();
      const tomorrow = new Date(now.toDate());
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(0, 0, 0, 0);

      const dayAfterTomorrow = new Date(tomorrow);
      dayAfterTomorrow.setDate(dayAfterTomorrow.getDate() + 1);

      // 明日開催されるイベントを取得
      const eventsSnapshot = await admin.firestore()
        .collection('events')
        .where('datetime', '>=', admin.firestore.Timestamp.fromDate(tomorrow))
        .where('datetime', '<', admin.firestore.Timestamp.fromDate(dayAfterTomorrow))
        .get();

      console.log(`Found ${eventsSnapshot.size} events for tomorrow`);

      const promises = [];
      eventsSnapshot.forEach((doc) => {
        const event = doc.data();
        const eventId = doc.id;

        // 参加者（確定のみ）に通知
        const participantIds = event.participants
          .filter(p => p.status === 'confirmed')
          .map(p => p.userId);

        if (participantIds.length === 0) {
          return;
        }

        // 通知レコードを作成
        const notificationRef = admin.firestore().collection('notifications').doc();
        const notificationData = {
          notificationId: notificationRef.id,
          circleId: event.circleId,
          eventId: eventId,
          title: 'イベントリマインダー',
          body: `${event.name} が明日開催されます`,
          type: 'eventReminder',
          recipientUserIds: participantIds,
          sentAt: now,
          createdAt: now,
        };

        promises.push(notificationRef.set(notificationData));
      });

      await Promise.all(promises);
      console.log(`Created ${promises.length} reminder notifications`);

      return null;
    } catch (error) {
      console.error('Error sending event reminders:', error);
      return null;
    }
  });

// Cloud Scheduler: 毎時間、イベント終了1時間後の未払通知を送信
exports.sendPaymentReminders = functions.pubsub
  .schedule('0 * * * *')
  .timeZone('Asia/Tokyo')
  .onRun(async (context) => {
    console.log('Running payment reminder job');

    try {
      const now = admin.firestore.Timestamp.now();
      const oneHourAgo = new Date(now.toDate());
      oneHourAgo.setHours(oneHourAgo.getHours() - 1);

      const twoHoursAgo = new Date(oneHourAgo);
      twoHoursAgo.setHours(twoHoursAgo.getHours() - 1);

      // 1時間前に終了したイベントを取得
      const eventsSnapshot = await admin.firestore()
        .collection('events')
        .where('endDatetime', '>=', admin.firestore.Timestamp.fromDate(twoHoursAgo))
        .where('endDatetime', '<', admin.firestore.Timestamp.fromDate(oneHourAgo))
        .get();

      console.log(`Found ${eventsSnapshot.size} events that ended 1 hour ago`);

      const promises = [];

      for (const doc of eventsSnapshot.docs) {
        const event = doc.data();
        const eventId = doc.id;

        // 参加費が設定されていない場合はスキップ
        if (!event.fee || parseInt(event.fee) === 0) {
          continue;
        }

        // 参加者（確定のみ）の支払い状況をチェック
        const confirmedParticipants = event.participants.filter(p => p.status === 'confirmed');
        const unpaidUserIds = [];

        for (const participant of confirmedParticipants) {
          // 支払いレコードを確認
          const paymentSnapshot = await admin.firestore()
            .collection('payments')
            .where('eventId', '==', eventId)
            .where('userId', '==', participant.userId)
            .where('status', '==', 'completed')
            .limit(1)
            .get();

          if (paymentSnapshot.empty) {
            unpaidUserIds.push(participant.userId);
          }
        }

        if (unpaidUserIds.length === 0) {
          continue;
        }

        console.log(`Event ${event.name}: ${unpaidUserIds.length} unpaid participants`);

        // 未払い参加者に通知
        for (const userId of unpaidUserIds) {
          const notificationRef = admin.firestore().collection('notifications').doc();
          const notificationData = {
            notificationId: notificationRef.id,
            circleId: event.circleId,
            eventId: eventId,
            title: '参加費のお支払いをお願いします',
            body: `${event.name} の参加費 ¥${event.fee} のお支払いが未完了です`,
            type: 'paymentReminder',
            recipientUserIds: [userId],
            sentAt: now,
            createdAt: now,
          };
          promises.push(notificationRef.set(notificationData));
        }

        // 管理者にも通知
        const circleDoc = await admin.firestore().collection('circles').doc(event.circleId).get();
        if (circleDoc.exists) {
          const circle = circleDoc.data();
          const adminIds = circle.members.filter(m => m.role === 'admin').map(m => m.userId);

          if (adminIds.length > 0) {
            const adminNotificationRef = admin.firestore().collection('notifications').doc();
            const adminNotificationData = {
              notificationId: adminNotificationRef.id,
              circleId: event.circleId,
              eventId: eventId,
              title: '未払いの参加者がいます',
              body: `${event.name} に${unpaidUserIds.length}名の未払い参加者がいます`,
              type: 'paymentReminder',
              recipientUserIds: adminIds,
              sentAt: now,
              createdAt: now,
            };
            promises.push(adminNotificationRef.set(adminNotificationData));
          }
        }
      }

      await Promise.all(promises);
      console.log(`Created ${promises.length} payment reminder notifications`);

      return null;
    } catch (error) {
      console.error('Error sending payment reminders:', error);
      return null;
    }
  });

// LINE Login: Web版でLINEログインを処理
exports.lineLogin = functions.https.onCall(async (data, context) => {
  const { code, redirectUri } = data;

  console.log('LINE Login request received', { redirectUri });

  if (!code) {
    throw new functions.https.HttpsError('invalid-argument', 'Code is required');
  }

  try {
    // LINEの設定を取得（Firebase Functions Configから）
    const lineConfig = functions.config().line;
    if (!lineConfig || !lineConfig.channel_id || !lineConfig.channel_secret) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'LINE configuration not found. Please set line.channel_id and line.channel_secret'
      );
    }

    const channelId = lineConfig.channel_id;
    const channelSecret = lineConfig.channel_secret;

    console.log('Using LINE Channel ID:', channelId);

    // アクセストークンを取得
    const tokenParams = new URLSearchParams({
      grant_type: 'authorization_code',
      code: code,
      redirect_uri: redirectUri,
      client_id: channelId,
      client_secret: channelSecret,
    });

    const tokenResponse = await axios.post(
      'https://api.line.me/oauth2/v2.1/token',
      tokenParams.toString(),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      }
    );

    const { access_token } = tokenResponse.data;
    console.log('Got LINE access token');

    // ユーザープロフィールを取得
    const profileResponse = await axios.get('https://api.line.me/v2/profile', {
      headers: {
        Authorization: `Bearer ${access_token}`,
      },
    });

    const profile = profileResponse.data;
    console.log('Got LINE profile:', profile.userId);

    const lineUserId = profile.userId;
    const displayName = profile.displayName;
    const pictureUrl = profile.pictureUrl || null;

    // FirebaseでユーザーIDを生成（LINE User IDベース）
    const email = `${lineUserId}@line.user`;
    const password = lineUserId; // LINE User IDをパスワードとして使用

    let firebaseUser;
    try {
      // 既存ユーザーを取得
      firebaseUser = await admin.auth().getUserByEmail(email);
      console.log('Found existing Firebase user:', firebaseUser.uid);
    } catch (error) {
      // ユーザーが存在しない場合は新規作成
      console.log('Creating new Firebase user');
      firebaseUser = await admin.auth().createUser({
        email: email,
        password: password,
        displayName: displayName,
        photoURL: pictureUrl,
      });
      console.log('Created Firebase user:', firebaseUser.uid);
    }

    // Firestoreにユーザー情報を保存/更新
    await admin.firestore().collection('users').doc(firebaseUser.uid).set({
      uid: firebaseUser.uid,
      lineUserId: lineUserId,
      name: displayName,
      profileImageUrl: pictureUrl,
      email: email,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log('Updated Firestore user document');

    // カスタムトークンを生成
    const customToken = await admin.auth().createCustomToken(firebaseUser.uid, {
      lineUserId: lineUserId,
      displayName: displayName,
    });

    console.log('Generated custom token');

    return {
      customToken: customToken,
      profile: {
        userId: lineUserId,
        displayName: displayName,
        pictureUrl: pictureUrl,
      },
      firebaseUid: firebaseUser.uid,
    };
  } catch (error) {
    console.error('LINE login error:', error);

    if (error.response) {
      console.error('Response error:', error.response.data);
      throw new functions.https.HttpsError(
        'internal',
        `LINE API error: ${error.response.data.error_description || error.response.data.error}`
      );
    }

    throw new functions.https.HttpsError('internal', `LINE login failed: ${error.message}`);
  }
});
