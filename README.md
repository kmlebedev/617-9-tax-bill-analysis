# 617-9: корпус, граф и ревью

Папка с воспроизводимым разбором законопроекта № 617-9 (налоговый пакет
2027–2029). Основной результат — `617-9_risks.md`; граф — `617-9_graph.md`
и `graphify-out/graph.html`; ревью — `617-9_review_qwen.md`.

## Статус законопроекта

- Внесён 30.09.2026.
- Первое чтение — 29.10.2026.
- Поправки — до 12.11.2026.
- Текст ко второму чтению — 16.11.2026.
- Второе чтение — 19.11.2026.
- Это ещё не закон; после второго чтения текст может измениться.

## Что лежит в папке

| Файл / папка | Что это |
|---|---|
| `617-9_risks.md` | основной документ: риски для предпринимателя, ссылки `[стр. N]` |
| `617-9_review_qwen.md` | ревью Qwen 3.8 Flash: 18 замечаний + журнал правок |
| `617-9_graph.md` | описание графа, god nodes, Mermaid-схема |
| `617-9_graph.json` | граф в JSON (копия `graphify-out/graph.json`) |
| `617-9_corpus.md` | единый MD-корпус законов и актов |
| `corpus/` | отдельные MD: законопроект, записка, статьи НК, ФЗ, подзаконные акты |
| `graph_input/` | вход для Graphify: записка + ключевые статьи + реестры |
| `graphify-out/` | `graph.json`, `GRAPH_REPORT.md`, `graph.html` |
| `sources/` | исходные `.doc`/`.docx`, PDF, постраничный текст, индекс |
| `refresh.sh` | пересборка корпуса из актуальной карточки СОЗД |
| `review_prompt.md` | готовый промпт для повторного ревью Qwen |
| `.kimi/skills/markitdown/` | скилл markitdown (в репозитории) |

## Быстрый старт

```bash
git clone https://github.com/kmlebedev/617-9-tax-bill-analysis.git
cd 617-9-tax-bill-analysis
./refresh.sh
```

`refresh.sh` пересоберёт источники, PDF, Markdown и постраничный индекс.
Граф и ревью — агентские шаги, см. ниже.

## Требования

- macOS с Apple Pages (для `.doc` → PDF) или LibreOffice с правкой
  `refresh.sh` (заменить AppleScript на `soffice --headless --convert-to pdf`).
- Python 3.10+.
- `markitdown` (`pip install 'markitdown[all]'`).
- `graphify` (`uv tool install 'graphifyy[pdf]'`, затем
  `graphify install --platform kimi --project`).
- `poppler` (`pdftotext`, `pdfinfo`).
- `gh` — только для публикации репозитория.

## Пайплайн

### 1. Обновить источники

```bash
./refresh.sh
```

Скрипт:

1. скачивает карточку https://sozd.duma.gov.ru/bill/617-9;
2. находит последний «Текст законопроекта» и скачивает его;
3. рендерит `.doc` в PDF через Apple Pages (`com.apple.Pages`);
4. конвертирует PDF/DOCX в Markdown через `markitdown`;
5. строит `sources/pages/page-XXX.txt` и `sources/page_index.tsv`;
6. пересобирает `617-9_corpus.md` и `graph_input/`.

После обновления нужно вручную (или агентом) обновить ссылки `[стр. N]`
в `617-9_risks.md` по новому `page_index.tsv`.

### 2. Пересобрать граф

Граф строится из `graph_input/` через скилл Graphify. В агенте:

```bash
graphify install --platform kimi --project   # обновить скилл
graphify query "штрафы 2027" --graph graphify-out/graph.json
```

Для полной пересборки: взять `graph_input/`, прогнать семантическую
экстракцию по `references/extraction-spec.md` (скилл
`.kimi/skills/graphify/SKILL.md`), затем собрать граф:

```bash
graphify export html --graph graphify-out/graph.json
```

Текущий граф: **100 узлов, 147 связей, 9 сообществ** (91% EXTRACTED,
9% INFERRED). God nodes — законопроект 617-9, записка, глава 16 НК,
реестр актов, структура по страницам.

### 3. Повторить ревью

Промпт — в `review_prompt.md`. Ревьюер должен:

- читать `617-9_risks.md` и `617-9_graph.md`;
- проверять каждую цифру/дату/ставку по PDF и постраничным файлам;
- использовать `graphify query` для навигации;
- каждое замечание оформлять с `[стр. N]` и дословной цитатой.

## Скиллы

- **markitdown**: `markitdown` (если не в PATH: `~/.local/bin/markitdown`); проектный скилл
  `.kimi/skills/markitdown/SKILL.md`. Используется для PDF → MD.
- **graphify**: 0.9.112; проектный скилл `.kimi/skills/graphify/SKILL.md`
  (`graphify install --platform kimi --project`). Используется для графа.

## Ограничения

- PDF-рендер Pages — **279 страниц**; в свойствах `.doc` указано **293**.
  Ссылки `[стр. N]` — по PDF, на каждой странице есть колонцифра. В Word
  пагинация может отличаться; цитату ищите поиском.
- Полный текст НК РФ не дублируется: в корпусе — изменяемые статьи и сводка.
- Подзаконные акты на 18.11.2026 не приняты; их перечень — прогнозный.
- Граф построен по аналитическому корпусу (~5 000 слов), а не по полному
  600-КБ тексту; полный текст — источник страниц.
- Это аналитическая записка, не юридическая консультация.

## Лицензия

Анализ, код и граф — MIT (см. `LICENSE`). Официальные тексты законопроекта
и связанных актов — публичные документы СОЗД; см. `NOTICE`.
