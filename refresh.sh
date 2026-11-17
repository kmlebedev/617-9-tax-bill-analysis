#!/usr/bin/env bash
# Rebuild the 617-9 source corpus from the current SOZD card.
# Graph extraction and the Qwen review are agent steps; see README.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SOURCES="$ROOT/sources"
CORPUS="$ROOT/corpus"
PAGES="$SOURCES/pages"
GRAPH_INPUT="$ROOT/graph_input"
CARD="$SOURCES/sozd_card.html"

mkdir -p "$SOURCES" "$CORPUS" "$PAGES" "$GRAPH_INPUT"

echo "[1/7] SOZD card"
curl -sL -m 60 -A "Mozilla/5.0" "https://sozd.duma.gov.ru/bill/617-9" -o "$CARD"

echo "[2/7] latest bill document"
LATEST_PATH="$(python3 - "$CARD" <<'PY'
import re, sys, html
s = open(sys.argv[1], encoding='utf-8', errors='ignore').read()
cands = []
for m in re.finditer(r'<a[^>]*href="(/download/[^"]+)"[^>]*>(.*?)</a>', s, flags=re.S):
    title = re.sub(r'<[^>]+>', ' ', m.group(2))
    title = ' '.join(html.unescape(title).split())
    if 'Текст законопроекта' in title:
        cands.append((m.start(), m.group(1), title))
if not cands:
    raise SystemExit('no bill text link found')
# The card lists events chronologically; the last text link is the newest stage.
print(cands[-1][1])
PY
)"
echo "  $LATEST_PATH"
DOC="$SOURCES/617-9_text_latest.doc"
curl -sL -m 180 -A "Mozilla/5.0" "https://sozd.duma.gov.ru$LATEST_PATH" -o "$DOC"

echo "[3/7] DOC -> PDF (Apple Pages)"
PDF="$SOURCES/617-9_text_latest.pdf"
osascript <<APPLESCRIPT
set inFile to POSIX file "$DOC"
set outFile to POSIX file "$PDF"
tell application id "com.apple.Pages"
    activate
    set d to open inFile
    export d to outFile as PDF
    close d saving no
end tell
APPLESCRIPT
pdfinfo "$PDF" | grep -E '^Pages:'

echo "[4/7] PDF/DOCX -> Markdown (markitdown)"
markitdown "$PDF" -o "$CORPUS/01_bill_latest.md"
curl -sL -m 120 -A "Mozilla/5.0" "https://sozd.duma.gov.ru/download/1f1bd69a-c32f-66ec-ae3a-f95f5e05b08a" -o "$SOURCES/617-9_explanatory_note.docx"
markitdown "$SOURCES/617-9_explanatory_note.docx" -o "$CORPUS/02_explanatory_note.md"
curl -sL -m 120 -A "Mozilla/5.0" "https://sozd.duma.gov.ru/download/1f1bd69a-bc96-6592-805d-f95f5e05b08a" -o "$SOURCES/617-9_text_introduced.docx"
markitdown "$SOURCES/617-9_text_introduced.docx" -o "$CORPUS/03_bill_introduced.md"

echo "[5/7] page index"
pdftotext -layout "$PDF" "$SOURCES/bill_pages.txt"
python3 - "$SOURCES" "$PAGES" <<'PY'
import re, sys, pathlib
sources = pathlib.Path(sys.argv[1]); pages_dir = pathlib.Path(sys.argv[2])
text = (sources / 'bill_pages.txt').read_text(encoding='utf-8', errors='ignore')
pages = text.split('\f')
if pages and not pages[-1].strip():
    pages = pages[:-1]
for old in pages_dir.glob('page-*.txt'):
    old.unlink()
idx = []
for i, page in enumerate(pages, 1):
    (pages_dir / f'page-{i:03d}.txt').write_text(page, encoding='utf-8')
    lines = [l.strip() for l in page.splitlines() if l.strip()]
    arts = re.findall(r'Статья\s+\d+(?:\.\d+)?', page)
    uniq = []
    for a in arts:
        if a not in uniq:
            uniq.append(a)
    idx.append(f"{i}\t{lines[0][:90] if lines else ''}\t{'; '.join(uniq[:8])}")
(sources / 'page_index.tsv').write_text('\n'.join(idx), encoding='utf-8')
with open(sources / 'bill_pages.md', 'w', encoding='utf-8') as f:
    f.write(f'# 617-9 — постраничный текст PDF ({len(pages)} стр.)\n\n')
    for i, page in enumerate(pages, 1):
        f.write(f'\n## стр. {i}\n\n```\n{page.strip()}\n```\n')
print(f'  pages: {len(pages)}')
PY

python3 - "$SOURCES" "$CORPUS" <<'PY'
import pathlib, sys
sources = pathlib.Path(sys.argv[1]); corpus = pathlib.Path(sys.argv[2])
rows = []
for line in (sources / 'page_index.tsv').read_text(encoding='utf-8').splitlines():
    parts = line.split('\t')
    if len(parts) < 3:
        continue
    page, first, arts = parts[0], parts[1], parts[2]
    if arts:
        rows.append(f'| {page} | {arts} | {first[:80]} |')
out = ['# 08. Структура законопроекта 617-9 по страницам\n',
       'Источник: PDF-рендер актуального текста.\n',
       '| Стр. | Статьи/разделы на странице | Первая строка |',
       '|---:|---|---|']
out.extend(rows)
(corpus / '08_bill_structure.md').write_text('\n'.join(out) + '\n', encoding='utf-8')
print(f'  08_bill_structure.md: {len(rows)} rows')
PY

echo "[6/7] combined corpus"
python3 - "$ROOT" <<'PY'
import sys, pathlib
root = pathlib.Path(sys.argv[1]); corpus = root / 'corpus'
files = [
 ('01_bill_latest.md', 'Законопроект 617-9, актуальный текст'),
 ('02_explanatory_note.md', 'Пояснительная записка'),
 ('03_bill_introduced.md', 'Текст, внесённый в Госдуму'),
 ('04_nk_key_articles.md', 'Ключевые статьи НК РФ'),
 ('05_federal_laws.md', 'Федеральные законы'),
 ('06_subordinate_acts.md', 'Подзаконные акты'),
 ('07_acts_index.md', 'Реестр актов'),
]
out = ['# 617-9 — единый корпус для анализа\n',
       'Версия: автоматическая сборка refresh.sh.\n',
       '> Аналитический корпус, не официальная публикация.\n\n## Оглавление\n']
for i, (fn, title) in enumerate(files, 1):
    out.append(f'{i}. {title}\n')
out.append('\n---\n')
for i, (fn, title) in enumerate(files, 1):
    p = corpus / fn
    if not p.exists():
        continue
    out.append(f'\n# {i}. {title}\n\n')
    out.append(p.read_text(encoding='utf-8'))
    out.append('\n\n---\n')
(root / '617-9_corpus.md').write_text(''.join(out), encoding='utf-8')
print('  617-9_corpus.md rebuilt')
PY

echo "[7/7] graph input"
cp "$ROOT/617-9_risks.md" "$GRAPH_INPUT/617-9_risks.md" 2>/dev/null || true
for f in 04_nk_key_articles.md 05_federal_laws.md 06_subordinate_acts.md 07_acts_index.md 08_bill_structure.md; do
    [ -f "$CORPUS/$f" ] && cp "$CORPUS/$f" "$GRAPH_INPUT/$f"
done

echo
echo "Готово. Дальше — агентские шаги:"
echo "  1) обновить ссылки [стр. N] в 617-9_risks.md по sources/page_index.tsv;"
echo "  2) пересобрать граф: см. README.md, раздел «Граф»;"
echo "  3) прогнать ревью: review_prompt.md."
