#!/bin/bash
# === Claude Codeの認証情報をGitHub Secretsへアップロード ===

set -euo pipefail  # エラー時の自動終了、未定義変数使用時エラー、パイプラインエラー

# === 設定 ===
CREDENTIALS_FILE="$HOME/.claude-code/credentials.json"
REPO_OWNER="" # GitHubのユーザー名(入力必須)
REPO_NAME="" # リポジトリ名(入力必須)

TEMP_FILE=""  # 一時ファイルパスを保存する変数

# === 必要なツールを確認 ===
check_requirements() {
    echo "ツールを確認中..."
    local missing=()
    for tool in jq gh security; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo "エラー: 次のツールが見つかりません: ${missing[*]}"
        exit 1
    fi
}

# === GitHub CLIの認証確認 ===
check_gh_auth() {
    if ! gh auth status &> /dev/null; then
        echo "エラー: GitHub CLIが認証されていません。以下を実行してください:"
        echo "gh auth login"
        exit 1
    fi
}

# === 一時ファイルを削除する関数 ===
cleanup_temp_file() {
    if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
        echo "一時ファイルを削除しました: $TEMP_FILE"
    fi
}

# === GitHub情報を対話的に取得 ===
get_github_info() {
    echo ""
    echo "=== GitHub リポジトリ情報の入力 ==="
    echo ""
    
    # リポジトリオーナーの入力
    while [[ -z "$REPO_OWNER" ]]; do
        echo -n "GitHubのユーザー名または組織名を入力してください: "
        read -r REPO_OWNER
        if [[ -z "$REPO_OWNER" ]]; then
            echo "⚠️  ユーザー名または組織名は必須です。"
        fi
    done
    
    # リポジトリ名の入力
    while [[ -z "$REPO_NAME" ]]; do
        echo -n "リポジトリ名を入力してください: "
        read -r REPO_NAME
        if [[ -z "$REPO_NAME" ]]; then
            echo "⚠️  リポジトリ名は必須です。"
        fi
    done
    
    echo ""
    echo "入力された情報:"
    echo "  GitHub URL: https://github.com/$REPO_OWNER/$REPO_NAME"
    echo ""
}

# === キーチェーンから認証情報を取得 ===
get_credentials_from_keychain() {
    echo "キーチェーンから認証情報を取得しています..."
    
    # セキュリティ強化: umaskで一時ファイルの権限を制限してから作成
    local old_umask
    old_umask=$(umask)
    umask 077  # 600 権限で作成
    TEMP_FILE=$(mktemp)
    umask "$old_umask"

    if ! security find-generic-password -s "Claude Code-credentials" -w > "$TEMP_FILE" 2>/dev/null; then
        echo "❌ キーチェーンから認証情報を取得できませんでした。"
        echo "   Claude Codeにログインしていることを確認してください。"
        cleanup_temp_file
        exit 1
    fi

    CREDENTIALS_FILE="$TEMP_FILE"
}

# === 認証情報ファイルの存在確認と整合性チェック ===
validate_credentials_file() {
    if [ ! -f "$CREDENTIALS_FILE" ]; then
        echo "認証情報ファイルが見つかりません。"
        echo "キーチェーンから取得を試みます..."
        get_credentials_from_keychain
    fi

    if ! jq empty "$CREDENTIALS_FILE" 2> /dev/null; then
        echo "❌ 認証情報ファイルが破損しています。"
        echo "   Claude Codeに再度ログインしてください。"
        cleanup_temp_file
        exit 1
    fi
    
    # 必要なフィールドが存在するかチェック
    local access_token refresh_token
    access_token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDENTIALS_FILE")
    refresh_token=$(jq -r '.claudeAiOauth.refreshToken // empty' "$CREDENTIALS_FILE")
    
    if [[ -z "$access_token" && -z "$refresh_token" ]]; then
        echo "❌ 認証情報が見つかりません。"
        echo "   Claude Codeにログインしていることを確認してください。"
        cleanup_temp_file
        exit 1
    fi
    
    echo "✅ 認証情報を確認しました。"
}

# === GitHub Secrets を更新 ===
update_secret() {
    local name="$1"
    local value="$2"

    if [ -z "$value" ]; then
        echo "⚠️  $name をスキップします（値が空のため）"
        return
    fi

    echo "🔐 $name を設定中..."
    if echo "$value" | gh secret set "$name" --repo "$REPO_OWNER/$REPO_NAME" 2>/dev/null; then
        echo "✅ $name を設定しました"
    else
        echo "❌ $name の設定に失敗しました"
        echo "   リポジトリへの書き込み権限があることを確認してください。"
        return 1
    fi
}

# === リポジトリの存在確認 ===
verify_repo_exists() {
    echo "リポジトリの確認中..."
    if ! gh repo view "$REPO_OWNER/$REPO_NAME" &> /dev/null; then
        echo "❌ リポジトリにアクセスできません: $REPO_OWNER/$REPO_NAME"
        echo ""
        echo "以下を確認してください:"
        echo "  1. リポジトリ名とユーザー名が正しいか"
        echo "  2. GitHub CLI でログインしているか (gh auth login)"
        echo "  3. リポジトリへのアクセス権限があるか"
        cleanup_temp_file
        exit 1
    fi
    echo "✅ リポジトリを確認しました。"
}

# === メイン処理 ===
main() {
    echo "=== Claude Code認証情報 → GitHub Secrets ==="
    echo ""

    check_requirements
    check_gh_auth
    
    # GitHub情報を対話的に取得
    get_github_info
    
    verify_repo_exists
    validate_credentials_file

    # 認証情報をJSONから抽出
    local access_token refresh_token expires_at
    access_token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDENTIALS_FILE")
    refresh_token=$(jq -r '.claudeAiOauth.refreshToken // empty' "$CREDENTIALS_FILE")
    expires_at=$(jq -r '.claudeAiOauth.expiresAt // empty' "$CREDENTIALS_FILE")

    # 最終確認
    echo "GitHub Secretsに以下の情報を設定します:"
    echo "  • CLAUDE_ACCESS_TOKEN"
    echo "  • CLAUDE_REFRESH_TOKEN" 
    echo "  • CLAUDE_EXPIRES_AT"
    echo ""
    read -p "続行しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "キャンセルしました。"
        cleanup_temp_file
        exit 0
    fi

    echo ""
    echo "GitHub Secrets を設定中..."

    # Secrets をアップロード
    local update_failed=false
    if ! update_secret "CLAUDE_ACCESS_TOKEN" "$access_token"; then
        update_failed=true
    fi
    if ! update_secret "CLAUDE_REFRESH_TOKEN" "$refresh_token"; then
        update_failed=true
    fi
    if ! update_secret "CLAUDE_EXPIRES_AT" "$expires_at"; then
        update_failed=true
    fi

    echo ""
    if [[ "$update_failed" == "true" ]]; then
        echo "❌ 一部の設定に失敗しました。"
        cleanup_temp_file
        exit 1
    else
        echo "✅ すべての設定が完了しました！"
        echo ""
        echo "これで GitHub Actions で Claude Code を利用できます。"
    fi
    
    # 一時ファイルを削除
    cleanup_temp_file
}

# === シグナルハンドラを設定 ===
trap cleanup_temp_file EXIT

# === 実行 ===
main
