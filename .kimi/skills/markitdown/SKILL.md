---
name: markitdown
description: Use when a PDF, DOCX, PPTX, XLSX, HTML or similar document must be converted to Markdown for analysis, corpus building or graph extraction. Wraps the installed `markitdown` CLI.
---

# MarkItDown

`markitdown` is installed at `markitdown` (если не в PATH: `~/.local/bin/markitdown`).

## Use it for

- PDF → Markdown
- DOCX / PPTX / XLSX → Markdown
- HTML → Markdown
- building a text corpus that another tool (Graphify, grep, an LLM) will read

Do not use it for scanned PDFs without a text layer: there is no OCR in the
default install. Check the output for empty or garbled pages and report them.

## Commands

Single file:

```bash
markitdown input.pdf -o output.md
```

Stdout instead of a file:

```bash
markitdown input.pdf > output.md
```

Batch a directory (Bash):

```bash
mkdir -p corpus
for f in sources/*.pdf; do
  base="$(basename "$f" .pdf)"
  markitdown "$f" -o "corpus/${base}.md" || echo "FAILED: $f" >&2
done
```

## Quality checks

1. `wc -c corpus/*.md` — flag files under ~1 KB.
2. Search for the headings or article numbers you expect:
   `grep -n "Статья 1" corpus/01_bill_latest.md`
3. Compare the number of pages in the source PDF (`pdfinfo`) with the output's
   size; a large mismatch usually means a scanned PDF or a failed conversion.
4. Keep the source PDF next to the MD: page citations in the final document
   refer to the PDF, not to the Markdown line numbers.

## Notes

- markitdown preserves headings, lists and tables, but not the original page
  layout. For `[стр. N]` citations use `pdftotext -f N -l N` on the PDF.
- Optional extras such as `[pdf]` and `[docx]` are already installed in the
  current environment.
- Do not send confidential files to a remote converter; this CLI runs locally.
