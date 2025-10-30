// 共通ヘッダーを挿入
function loadHeader(isIndex = true) {
    const header = document.createElement('header');
    header.className = 'header';

    const nav = isIndex ? `
        <nav class="nav">
            <a href="#features">機能</a>
            <a href="#download">ダウンロード</a>
            <a href="privacy.html">プライバシーポリシー</a>
        </nav>
    ` : `
        <nav class="nav">
            <a href="index.html">ホーム</a>
            <a href="index.html#features">機能</a>
            <a href="index.html#download">ダウンロード</a>
        </nav>
    `;

    header.innerHTML = `
        <div class="container">
            <div class="logo">
                <img src="assets/images/logo.jpeg" alt="Circlet" class="logo-image">
                <h1>Circlet</h1>
            </div>
            ${nav}
        </div>
    `;

    document.body.insertBefore(header, document.body.firstChild);
}

// 共通フッターを挿入
function loadFooter() {
    const footer = document.createElement('footer');
    footer.className = 'footer';

    footer.innerHTML = `
        <div class="container">
            <div class="footer-content">
                <div class="footer-section">
                    <h3>Circlet</h3>
                    <p>サークル運営を、もっとスマートに</p>
                </div>
                <div class="footer-section">
                    <h4>リンク</h4>
                    <ul>
                        <li><a href="index.html#features">機能</a></li>
                        <li><a href="index.html#download">ダウンロード</a></li>
                        <li><a href="privacy.html">プライバシーポリシー</a></li>
                    </ul>
                </div>
                <div class="footer-section">
                    <h4>サポート</h4>
                    <ul>
                        <li><a href="mailto:support@circlet.jp">お問い合わせ</a></li>
                    </ul>
                </div>
            </div>
            <div class="footer-bottom">
                <p>&copy; 2025 Circlet. All rights reserved.</p>
            </div>
        </div>
    `;

    document.body.appendChild(footer);
}
