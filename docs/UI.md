# UI Specification

7 screens. Listed in build order — the first four are the product, the last three
make it usable day to day.

---

## 1. Ask (home)

The entry point. Deliberately close to empty.

- One large question field. Placeholder shows a real example question so users
  learn what "good" looks like without being told.
- Optional filters, collapsed by default: year range, open-access only,
  number of papers (default 20).
- Below: recent runs as cards (question, date, paper count, status).

**Design note.** Resist adding options. Researchers do not know what to set
before their first run, and a wall of controls makes the tool feel like work.

---

## 2. Run progress

Shown from submit until the result is ready. Lives for 2–4 minutes, so it has to
be worth looking at.

- Vertical stage list with live status: Planning → Searching → Reading papers →
  Retrieving → Analysing → Verifying → Finding gaps.
- A counter on the slow stage ("Reading papers — 7 of 20").
- **Papers appear as cards as they are found**, before analysis finishes. This is
  the whole point of streaming: the user has something real to read within ~20
  seconds instead of watching a spinner.
- Warnings appear inline and calmly: "2 papers could not be read (scanned PDFs)."

**Design note.** Never show an indeterminate spinner for a multi-minute job. A
user with no progress signal assumes it has crashed.

---

## 3. Result

The main screen. Four tabs over one run.

### Tab 1 — Answer
The written synthesis. Every factual sentence carries a small superscript
reference; tapping it slides up the exact source passage with the paper title and
page number. A coloured dot marks verification status:

- green — supported by the cited passage
- amber — partially supported
- red — contradicted, or the source could not be found

The amber and red marks are the feature, not an embarrassment. Show a summary
line at the top: "34 claims · 31 verified · 3 need checking."

### Tab 2 — Papers
The 20 papers as cards: title, authors, year, venue, citation count, relevance,
and a one-line "why this was included". Tap opens screen 4.

### Tab 3 — Compare
The comparison matrix. Papers as rows, extracted fields as columns (method,
datasets, metrics, baselines). Horizontally scrollable on mobile; pin the title
column. Empty cells stay visibly empty — they are what the gaps are made of.

### Tab 4 — Gaps
Ranked list. Each gap is one clear sentence, then the evidence beneath it:
"No paper evaluates transformer methods on Dataset X — 6 papers use
transformers, 4 use Dataset X, none do both."

**Design note.** A gap without its supporting evidence is just an opinion. Always
show the counting that produced it.

---

## 4. Paper detail

One paper, in depth.

- Header: title, authors, year, venue, DOI, links out.
- The extracted summary (problem / method / datasets / metrics / limitations) as
  a clean form, each field tappable to its source passage.
- The full PDF, readable inline, with cited passages highlighted.
- "Cited by / cites" within this run's paper set.

**Risk.** Inline PDF rendering is the hardest part of the client on Flutter Web.
Prototype it in week 1 — everything else here is ordinary widgets.

---

## 5. Library

The user's own papers.

- Upload PDFs; they go through the same ingest pipeline.
- List of uploaded papers with parse status.
- A toggle on screen 1: "search my library too".

Matters more than it looks. Researchers already have a folder of PDFs, and being
able to ask questions across it is often the first thing they actually want.

---

## 6. Run history

All past runs, searchable. Runs are immutable records, so an old one opens
exactly as it was. Allows comparing how an answer changed as the field moved.

---

## 7. Settings

Short. Theme, default paper count, default year range, export format
(BibTeX / Markdown), API usage if we show cost.

---

## Mobile vs web

| Screen | Web | Mobile |
|---|---|---|
| Ask | centred, wide | full width |
| Progress | side panel + paper grid | single column |
| Answer | text + source panel side by side | source opens as bottom sheet |
| Compare | full matrix | horizontal scroll, pinned first column |
| Paper detail | PDF + summary side by side | tabs |

Phones are for reading results and triage. Starting a run and studying the matrix
are laptop activities. Do not fight this — optimise each for what it is for.

---

## Build order

Week 2 → screens 1, 2, and the Papers tab of 3.
Week 3 → Answer and Compare tabs.
Week 4 → Gaps tab, verification marks.
Week 5 → screens 4, 5, 6, 7.
