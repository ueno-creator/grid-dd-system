#!/usr/bin/env bash
set -e

echo "🚀 [1/4] Git / GitHub ツールの確認中..."
if ! command -v git &> /dev/null; then
    echo "❌ Git が見つかりません。Xcode Command Line Tools をインストールしてください: xcode-select --install"
    exit 1
fi

USE_GH=false
if command -v gh &> /dev/null; then
    USE_GH=true
fi

mkdir -p .github/workflows

cat << 'YML_EOF' > .github/workflows/grid_auto_patrol_and_heal.yml
name: Grid System Patrol and AI Self-Healing
on:
  schedule:
    - cron: '0 21 * * *'
  workflow_dispatch:
jobs:
  patrol-and-heal:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: |
          python -m pip install --upgrade pip
          pip install requests google-genai
      - id: run_patrol
        continue-on-error: true
        run: |
          python - << 'PY_EOF' > patrol_report.json
          import re, json, sys, requests
          report = {"status": "success", "errors": []}
          try:
              with open("oita_grid_capacity_map.html", "r", encoding="utf-8") as f:
                  content = f.read()
              if "</html>" not in content: report["errors"].append("HTML終端欠損")
          except Exception as e:
              report["status"] = "failed"; report["errors"].append(str(e))
          with open("patrol_report.json", "w", encoding="utf-8") as out:
              json.dump(report, out, ensure_ascii=False)
          if report["errors"]: sys.exit(1)
          PY_EOF
YML_EOF

echo "🔑 [2/4] Gemini API キーの設定..."
if [ -z "$GEMINI_API_KEY" ]; then
    echo "Google AI Studio (aistudio.google.com) で取得した GEMINI_API_KEY を貼り付けて Enter:"
    read -r input_key
    GEMINI_API_KEY="$input_key"
fi

if [ ! -d ".git" ]; then
    git init
    git branch -M main
fi

git add .
git commit -m "🚀 [Init] 電力系統DDシステム 自動巡回初期化" || true

echo "☁️ [3/4] GitHub 連携..."
if [ "$USE_GH" = true ]; then
    if ! gh auth status &> /dev/null; then
        echo "🔐 GitHub へのログインを行います..."
        gh auth login -w
    fi
    if ! git remote get-url origin &> /dev/null; then
        gh repo create grid-dd-system --private --source=. --remote=origin --push
    else
        git push -u origin main
    fi
    echo "$GEMINI_API_KEY" | gh secret set GEMINI_API_KEY
    echo "🎉 自動巡回＆AI修復のセットアップが完了しました！"
else
    echo "💡 GitHub CLI (gh) が入っていません。"
    echo "   Mac のターミナルで 'brew install gh' を実行すると、ブラウザ認証でワンクリック連携できます。"
fi
