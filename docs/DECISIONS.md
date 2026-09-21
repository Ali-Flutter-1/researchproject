# Decision Record

Each entry states the decision, the reasoning, what was rejected, and what would
make us revisit it. Decisions are numbered and append-only — supersede an entry
with a new one rather than editing history.

Status legend: **Accepted** · **Provisional** (decided, but weakly held) ·
**Superseded by ADR-NNN**

---

## ADR-001 — Flutter for the client
**Status:** Accepted · 2026-09-21

Flutter Web + mobile from a single codebase, pinned to 3.38.4 via FVM.

**Why.** Researchers read on a laptop and triage on a phone; one codebase covers
both. FVM pins the SDK so the Windows development machine builds identically to
the Mac regardless of its globally installed Flutter version.

**Rejected.** React + React Native — two codebases in practice once native
concerns appear. A web-only SPA — loses the mobile triage case, which is a real
part of how literature review happens.

**Revisit if.** The PDF reading experience on Flutter Web proves unacceptable.
Rendering a paginated, text-selectable, annotation-capable PDF in Flutter Web is
the one place this stack is genuinely weaker than the React alternative, and it
is central to the product. Prototype it in week 1.

---

## ADR-002 — ASP.NET Core for the API
**Status:** Accepted · 2026-09-21

**Why.** Given by the project brief. It holds up independently: strong typing
across a pipeline with many structured payloads, real threading for the
parallel per-paper extraction fan-out, and a first-party Anthropic C# SDK.

**Cost we accept.** The Python ML ecosystem (GROBID clients, chunking libraries,
eval harnesses, `rank_bm25`) is richer. We pay for this by running GROBID as an
HTTP service rather than in-process, and by writing some retrieval glue by hand.

**Revisit if.** We find ourselves reimplementing three or more substantial Python
libraries. The escape hatch is a small Python sidecar for ingest only, behind an
HTTP boundary — not a rewrite.

---

## ADR-003 — Claude Opus 5 as the reasoning model
**Status:** Accepted · 2026-09-21

`claude-opus-5` for every reasoning stage, with adaptive thinking on.

**Why.** The hard stages — cross-paper comparison, gap identification, citation
verification — are long-context synthesis over many documents at once. This is
the workload where model capability shows up most directly in output quality,
and a wrong answer delivered confidently to a researcher is worse than no answer.

**Rejected.** Azure OpenAI — no advantage here and a second vendor relationship.
Local Ollama models — cannot do reliable multi-document synthesis at this length,
and would be unusably slow on the Windows development machine.

**Revisit if.** The per-paper extraction pass (ADR-011) stabilizes. That stage is
mechanical and is the natural candidate to move down to `claude-haiku-4-5` — but
only after the eval harness can prove the swap costs nothing.

---

## ADR-004 — Voyage embeddings
**Status:** Accepted · 2026-09-21

`voyage-3` for chunk and query embeddings; `rerank-2` for reranking.

**Why.** Strong retrieval quality on technical and scientific text, and reranking
from the same vendor keeps one integration instead of two.

**Rejected.** Self-hosted BGE/E5 — cheaper per call but adds GPU infrastructure
and an inference service to operate, for a corpus size where embedding cost is
not the bottleneck. OpenAI embeddings — a second vendor for no gain.

**Consequence.** Embedding dimension (1024) is baked into the Qdrant collection.
Changing embedding models means re-embedding the entire corpus — a migration,
not a config change. Store the model name on every chunk row so we can tell
which vectors are stale.

---

## ADR-005 — Qdrant as the vector store
**Status:** Accepted · 2026-09-21

Self-hosted in Docker alongside Postgres.

**Why.** Runs locally with one Compose service, so the whole system works offline
on a laptop. Good payload filtering, which we need constantly — nearly every
query is scoped by `sectionType`, `paperId`, or run.

**Rejected.** pgvector — appealing for keeping one database, but filtered ANN
search at our query shape is weaker. Pinecone — managed, but network latency in
the retrieval hot path and a hard dependency on connectivity during development.

**Revisit if.** Operating two datastores proves more painful than the retrieval
quality difference justifies. pgvector remains a legitimate fallback; keep the
vector-store access behind an interface so the swap stays a day of work.

---

## ADR-006 — Postgres alongside Qdrant
**Status:** Accepted · 2026-09-21

Qdrant stores vectors and a minimal payload. Postgres is the source of truth for
papers, sections, chunk text, runs, extractions, and claims.

**Why.** Vector stores are bad relational databases. We need joins, transactions,
full-text search for the BM25 half of hybrid retrieval, and the ability to
rebuild the entire vector index from Postgres without re-downloading a single PDF.

**Consequence.** Two writes per chunk, which can diverge. Rule: **Postgres first,
Qdrant second, and Qdrant is always rebuildable.** Never store anything in Qdrant
that exists nowhere else. A reindex command that drops and rebuilds the
collection from Postgres is a week-1 deliverable, not a later nicety.

---

## ADR-007 — OpenAlex for discovery, arXiv for full text
**Status:** Provisional · 2026-09-21

**Why.** OpenAlex is free, needs no API key, covers ~250M works, and exposes the
citation graph the Gap Agent depends on. arXiv provides full-text PDFs we can
legally download and parse at volume.

**Rejected.** Semantic Scholar — a better citation graph and useful TLDRs, but
rate-limited without a key. Keep it as a future supplement, not a replacement.
Publisher APIs — licensing complexity we cannot absorb at this stage.

**Why provisional.** arXiv is CS, physics, and maths. If the target domain is
biomedical or social science, open-access coverage through this path is thin and
the corpus decision is wrong. **Validate in week 1** with three real research
questions: if fewer than half the top-20 results have a retrievable PDF, add
Europe PMC or pivot to user-uploaded libraries.

---

## ADR-008 — GROBID for PDF parsing
**Status:** Accepted · 2026-09-21

PDFs go through GROBID to TEI XML. PdfPig is a degraded fallback only.

**Why.** This is the highest-leverage decision in the ingest path. A plain text
extractor gives an undifferentiated wall of text. GROBID gives labelled section
boundaries, figure and table captions, and — critically — a **parsed reference
list**. Section labels make section-aware retrieval possible (ADR-010). The
reference list is what the Citation Agent verifies against and what the Gap Agent
builds the local citation graph from. Without GROBID, two of six agents lose
their foundation.

**Cost we accept.** A JVM service in the stack, ~4GB of RAM, and roughly 3–10
seconds per paper.

**Consequence.** Parse quality varies with PDF origin. Scanned documents and
two-column non-LaTeX layouts degrade badly. Store a parse-confidence score per
paper and surface it in the UI rather than presenting bad extractions as fact.

---

## ADR-009 — A workflow, not an autonomous agent loop
**Status:** Accepted · 2026-09-21

The orchestrator is ordinary C# calling six agents in a fixed sequence. Only the
Analysis Agent gets tool-use freedom, and only to fetch additional evidence.

**Why.** The stage order is fully known in advance: you cannot analyse papers you
have not retrieved, or verify citations that do not exist yet. When control flow
is knowable at design time, code should own it. A model-driven loop here would
cost more, take longer, fail nondeterministically, and be far harder to debug —
in exchange for flexibility the problem does not need.

**Rejected.** A planner agent deciding stage order per question. Reconsider only
if we find question types whose correct pipeline genuinely differs.

**Consequence.** Adding a stage is a code change, not a prompt change. That is
the intended tradeoff.

---

## ADR-010 — Hybrid, section-aware retrieval
**Status:** Accepted · 2026-09-21

Dense (Qdrant) + BM25 (Postgres) fused by Reciprocal Rank Fusion, filtered and
weighted by section type, then reranked.

**Why.** Researchers ask about *named things* — "FlashAttention", "BLEU", "MIMIC-III",
"ε = 0.1". Dense retrieval blurs exact tokens; BM25 nails them and fails at
paraphrase. Neither alone is adequate, and RRF needs no score calibration.

Section weighting matters because the same question means different things in
different sections: "what methods are used" belongs in Methods, "how well does it
work" in Results. Retrieving from an undifferentiated pool wastes context on the
wrong parts of the paper.

**Consequence.** Retrieval has tunable parameters (RRF k, section weights,
candidate depth), which means it needs an eval set to tune against — see ADR-013.

---

## ADR-011 — Two-pass analysis via structured extraction
**Status:** Accepted · 2026-09-21

Pass 1 extracts each paper independently into a fixed schema. Pass 2 compares the
resulting structured records.

**Why.** Comparison over free text does not scale — 20 full papers will not fit
usefully in one call, and the model loses track of which claim came from which
paper. Extracting to a common schema first makes the comparison a structured
operation over small records. It also makes pass 1 parallelizable, cacheable,
independently testable, and reusable across runs: a paper extracted once can be
compared in any future run at zero additional cost.

**Consequence.** The schema is the contract, and a field missing from it is
invisible downstream forever. Design it deliberately in week 3 and version it;
schema changes mean re-extraction.

---

## ADR-012 — Citation verification as a separate stage
**Status:** Accepted · 2026-09-21

Every factual claim carries a `chunkId`, enforced by the output schema. A
dedicated stage then checks each claim against its cited chunk and labels it
`supported | partially_supported | contradicted | not_found`. Anything below
`supported` is flagged in the UI.

**Why.** This is the difference between a research tool and a plausible-sounding
summarizer. A researcher cannot use output they have to re-verify by hand; the
system must do that work and show what it could not confirm. Separating
verification from generation matters — the model that wrote a claim is the wrong
one to grade it in the same breath.

**Consequence.** Extra cost and latency per run, and the UI must be designed
around uncertainty from the start. Surfacing "3 claims could not be verified" is
a feature, not a defect to hide.

---

## ADR-013 — Evaluation from week 1
**Status:** Accepted · 2026-09-21

Retrieval metrics, faithfulness rate, extraction accuracy, and a rubric-graded
end-to-end judge — built alongside the features, not after.

**Why.** Every stage has knobs, and without measurement, tuning them is guessing.
Retrieval quality in particular is invisible from the outside: bad retrieval
makes the Analysis Agent look broken, which sends you debugging the wrong stage.
The hand-labelled sets are small (~30 question→chunk pairs, ~10 annotated
papers) and cost roughly a day — far less than one week lost to blind tuning.

---

## ADR-014 — Async runs with SSE progress
**Status:** Accepted · 2026-09-21

`POST /api/research` returns a `runId` immediately; progress streams over SSE.

**Why.** A full run is minutes of work — search, downloads, GROBID, embedding,
several LLM passes. No HTTP request should be held open that long, and a user
staring at a spinner for four minutes with no signal will assume it has hung.
Per-stage events let the UI show real progress and partial results as they land.

**Rejected.** WebSockets — bidirectional, which we do not need. Polling — simpler,
but wasteful and gives coarse progress.

**Consequence.** Run state must be durable, not in-process memory: a client that
reconnects has to resume, and a server restart must not lose a run.

---

## ADR-015 — Prompt caching on the extraction prompt
**Status:** Accepted · 2026-09-21

System prompt, schema, and few-shot examples sit before the last `cache_control`
breakpoint; the paper text goes after it.

**Why.** Pass 1 sends an identical prefix once per paper — 20 times per run. This
is the single largest cost lever available, and it costs nothing but correct
ordering.

**Consequence.** The prefix must stay byte-stable. No timestamps, no run IDs, no
unsorted JSON before the breakpoint. Monitor `usage.cache_read_input_tokens`; if
it reads zero across a run, something in the prefix is varying.
