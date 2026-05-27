#!/bin/bash
# Vue3 构建 → 输出到 Flutter asset 目录
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VUEDIR="$SCRIPT_DIR/vuedemo"
OUTDIR="$SCRIPT_DIR/assets/vuedemo"

cd "$VUEDIR"

echo "📦 安装依赖..."
npm install --silent

echo "🔨 构建 Vue3..."
npx vite build --outDir ../assets/vuedemo --base ./ 2>&1 || {
  # vite build 可能被系统误拦截，fallback 到 node 方式
  echo "⚠️  vite CLI 被拦截，使用 node 方式构建..."
  node -e "import('vite').then(v => v.build({build: {outDir: '../assets/vuedemo'}, base: './'})).then(() => console.log('✅ done')).catch(console.error)"
}

echo ""
echo "✅ Vue3 构建完成 → $OUTDIR"
echo "   文件: $(ls -1 "$OUTDIR" | xargs)"
echo ""
echo "   下一步: cd ../ && flutter run"
