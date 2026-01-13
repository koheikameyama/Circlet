// LINE Login for Web

class LineLoginWeb {
  constructor(channelId, redirectUri) {
    this.channelId = channelId;
    this.redirectUri = redirectUri;
    this.authUrl = 'https://access.line.me/oauth2/v2.1/authorize';
    this.tokenUrl = 'https://api.line.me/oauth2/v2.1/token';
    this.profileUrl = 'https://api.line.me/v2/profile';
  }

  // LINE Login URLを生成
  generateLoginUrl() {
    const state = this.generateRandomString(32);
    const nonce = this.generateRandomString(32);

    // セッションストレージに保存
    sessionStorage.setItem('line_login_state', state);
    sessionStorage.setItem('line_login_nonce', nonce);

    const params = new URLSearchParams({
      response_type: 'code',
      client_id: this.channelId,
      redirect_uri: this.redirectUri,
      state: state,
      scope: 'profile openid email',
      nonce: nonce,
    });

    return `${this.authUrl}?${params.toString()}`;
  }

  // LINE Loginを開始
  login() {
    const loginUrl = this.generateLoginUrl();
    window.location.href = loginUrl;
  }

  // コールバック処理
  async handleCallback() {
    const urlParams = new URLSearchParams(window.location.search);
    const code = urlParams.get('code');
    const state = urlParams.get('state');

    // stateを検証
    const savedState = sessionStorage.getItem('line_login_state');
    if (!state || state !== savedState) {
      throw new Error('Invalid state parameter');
    }

    if (!code) {
      throw new Error('Authorization code not found');
    }

    return code;
  }

  // ランダム文字列生成
  generateRandomString(length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }
}

// グローバルに公開
window.LineLoginWeb = LineLoginWeb;
