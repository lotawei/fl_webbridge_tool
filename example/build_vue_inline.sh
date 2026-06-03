#!/bin/bash
# 构建 Vue3 → 内联 JS/CSS 为单文件 → Flutter asset
set -e
cd "$(dirname "$0")/vuedemo"
npm run build 2>/dev/null

cd dist
HTML="index.html"

# 找到 CSS 和 JS 文件
CSS=$(grep -o 'href="[^"]*\.css"' "$HTML" | head -1 | sed 's/href="//;s/"//')
JS=$(grep -o 'src="[^"]*\.js"' "$HTML" | head -1 | sed 's/src="//;s/"//')

if [ -n "$CSS" ] && [ -f "$CSS" ]; then
  echo "📦 Inlining CSS: $CSS ($(wc -c < "$CSS") bytes)"
  python3 -c "
html = open('$HTML').read()
css = open('$CSS').read()
html = html.replace('<link rel=\"stylesheet\" crossorigin href=\"$CSS\">', '<style>' + css + '</style>')
open('$HTML', 'w').write(html)
"
fi

if [ -n "$JS" ] && [ -f "$JS" ]; then
  echo "📦 Inlining JS: $JS ($(wc -c < "$JS") bytes)"
  python3 -c "
html = open('$HTML').read()
js = open('$JS').read()
html = html.replace('<script type=\"module\" crossorigin src=\"$JS\">', '<script type=\"module\">' + js)
open('$HTML', 'w').write(html)
"
fi

# 删除多余的 asset 文件，只留 index.html
find . -not -name 'index.html' -delete
rm -rf assets

echo "✅ Single-file: $(wc -c < $HTML) bytes"

# 拷贝到 Flutter asset 目录
cp "$HTML" ../../assets/vuedemo/index.html
echo "✅ Copied to assets/vuedemo/index.html"
