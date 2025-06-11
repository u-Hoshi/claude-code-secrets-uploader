# Claude Code の認証情報を GitHub Secrets に設定するツール

> **⚠️ macOS 専用ツール**  
> このスクリプトは macOS でのみ動作確認済みです。Windows や Linux では未確認です。

このツールは、[Claude Code](https://claude.ai/) の認証情報を GitHub リポジトリの Secrets に簡単に設定できるスクリプトです。

## 📋 このツールでできること

- Claude Code の認証情報を自動取得
- GitHub Secrets への自動設定
- GitHub Actions で Claude Code を利用可能に

---

## 🚀 クイックスタート

### 1. 事前準備

以下のツールがインストールされている必要があります：

**必須ツール:**
- `gh`（GitHub CLI）→ [インストール方法](https://cli.github.com/)
- `jq` → macOS: `brew install jq`
- `security`（macOS に標準搭載）

**GitHub CLI にログイン:**
```bash
gh auth login
```

### 2. スクリプトをダウンロード

ダウンロード方法は、このリポジトリをフォークしたかどうかで異なります：

#### 🍴 このリポジトリをフォークした場合
```bash
# あなたのフォークしたリポジトリからダウンロード
curl -O https://github.com/あなたのユーザー名/claude-code-secrets-uploader/raw/main/update_claude_code_secrets.sh

# 実行権限を付与
chmod +x update_claude_code_secrets.sh
```

#### 📥 フォークしていない場合（元のリポジトリから直接使用）
```bash
# 元のリポジトリからダウンロード
curl -O https://github.com/u-Hoshi/claude-code-secrets-uploader/raw/main/update_claude_code_secrets.sh

# 実行権限を付与
chmod +x update_claude_code_secrets.sh
```

> 💡 **フォークを推奨**  
> スクリプトをカスタマイズしたい場合はまずこのリポジトリをフォークすることをお勧めします。

### 3. 実行

```bash
./update_claude_code_secrets.sh
```

スクリプトを実行すると、以下の手順で進みます：

1. **GitHub情報の入力**
   - GitHubユーザー名（または組織名）を入力
   - リポジトリ名を入力

2. **自動チェック**
   - 必要なツールの確認
   - GitHub CLI の認証確認
   - Claude Code の認証情報確認
   - リポジトリの存在・権限確認

3. **設定の実行**
   - 確認後、GitHub Secrets に以下を設定：
     - `CLAUDE_ACCESS_TOKEN`
     - `CLAUDE_REFRESH_TOKEN`
     - `CLAUDE_EXPIRES_AT`

---

## 🔧 Claude Code の認証情報について

### 自動取得方法

スクリプトは以下の順序で認証情報を取得します：

1. `~/.claude-code/credentials.json` ファイル
2. macOS キーチェーンの `Claude Code-credentials` 項目



---

## ❓ よくある質問

### Q: 「ツールが見つかりません」エラーが出る
**A:** 必要なツールをインストールしてください：
- GitHub CLI: https://cli.github.com/
- jq: `brew install jq` (macOS)

### Q: 「GitHub CLI が認証されていません」エラーが出る
**A:** 以下のコマンドでログインしてください：
```bash
gh auth login
```

### Q: 「認証情報が見つかりません」エラーが出る
**A:** Claude Code にログインしていることを確認してください：
```bash
# Claude Code の状態確認
ls ~/.claude-code/
```

### Q: 「リポジトリにアクセスできません」エラーが出る
**A:** 以下を確認してください：
1. リポジトリ名とユーザー名が正しいか
2. リポジトリが存在するか
3. リポジトリへの書き込み権限があるか

---

## 🔒 セキュリティについて

- 認証情報は一時的にファイルに保存されますが、スクリプト実行後に自動削除されます
- 一時ファイルの権限は 600（オーナーのみ読み書き可能）に設定されます
- GitHub Secrets は暗号化されて安全に保存されます

---

## 🤝 対象ユーザー

- **エンジニア**: コマンドライン操作に慣れている方
- **デザイナー・企画**: 基本的なターミナル操作ができる方
- **チームメンバー**: GitHub Actions で Claude Code を利用したい方

---

## 📄 ライセンス

[MIT License](LICENSE)

---

## 🐛 問題報告・改善提案

バグ報告や機能改善の提案は、GitHub Issues でお気軽にご連絡ください！
