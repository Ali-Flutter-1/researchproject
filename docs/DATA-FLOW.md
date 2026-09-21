# Data Flow

What moves through the system, in what shape, at each stage. Read alongside
[ARCHITECTURE.md](ARCHITECTURE.md) (structure) and [DECISIONS.md](DECISIONS.md)
(why).

There are two distinct flows. **Ingest** is per-paper, cached, and shared across
every run. **Query** is per-question and runs the six stages. Conflating them is
the most common way to build this wrong: if ingest is not separately cached, the
second run over the same paper pays the full parsing and embedding cost again.

---

## Flow A — Ingest (per paper, once, reusable forever)

```
arXiv PDF ──► GROBID ──► TEI XML ──► sections ──► chunks ──► vectors
   │                                    │            │          │
   └─ pdf_blob                      Postgres     Postgres    Qdrant
                                    sections      chunks     points
```

| Step | In | Out | Stored |
|---|---|---|---|
| 1. Fetch | `oa_url` | PDF bytes | blob store / disk, keyed by DOI |
| 2. Parse | PDF bytes | TEI XML | `papers.tei_xml`, `papers.parse_confidence` |
| 3. Sectionize | TEI | ordered sections with `type`, `title`, `page_start` | `sections` |
| 4. Chunk | section text | ~800-token chunks, 15% overlap, never crossing a section boundary | `chunks` |
| 5. Embed | chunk text | 1024-dim `voyage-3` vector | Qdrant point + `chunks.qdrant_point_id` |
| 6. References | TEI `<listBibl>` | resolved DOIs via OpenAlex | `paper_references(from_paper, to_paper)` |

**Idempotency.** Key everything by DOI. Re-ingesting an already-ingested paper is
a no-op unless `embedding_model` changed or `parse_version` was bumped. Every run
begins by partitioning its candidate papers into already-ingested and new — only
the new ones pay ingest cost.

**Chunk payload in Qdrant.** Keep it minimal; Postgres holds the text.

```json
{
  "chunk_id": "uuid",
  "paper_id": "uuid",
  "doi": "10.48550/arXiv.2301.00001",
  "section_type": "methods",
  "section_title": "3.2 Training Procedure",
  "page_number": 4,
  "year": 2023,
  "embedding_model": "voyage-3"
}
```

`section_type` and `year` are there to be filtered on, not read. Everything the
UI displays comes from Postgres by `chunk_id`.

---

## Flow B — Query (per research question)

### Stage-by-stage transformations

```
question: string
   │
   ▼ ── Search Agent ────────────────────────────────────────────
QueryPlan { subQuestions[], queries[], yearFrom, yearTo, concepts[] }
   │
   ▼ ── OpenAlex ─────────────────────────────────────────────────
Candidate[]  (~200, deduped by DOI)
   │
   ▼ ── rank: citations + recency + abstract similarity ──────────
SelectedPaper[]  (top 20 with a retrievable PDF)
   │
   ▼ ── Ingest (Flow A, only for papers not already ingested) ────
Chunk[]  in Qdrant + Postgres
   │
   ▼ ── RAG Agent, once per sub-question ─────────────────────────
EvidenceSet { subQuestion, chunks[12] with scores and provenance }
   │
   ▼ ── Analysis pass 1, once per paper, in parallel ─────────────
Extraction[]  (one structured record per paper)
   │
   ▼ ── Analysis pass 2, once ────────────────────────────────────
Analysis { comparisonMatrix, synthesis[], claims[] each with chunkId }
   │
   ▼ ── Citation Agent, once per claim, in parallel ──────────────
VerifiedClaim[]  (status + verifier note)
   │
   ▼ ── Gap Agent ────────────────────────────────────────────────
Gap[]  (enumerated in code, ranked and written up by Claude)
   │
   ▼
ResearchResult
```

### Key payload shapes

**QueryPlan** — Search Agent output, validated by structured outputs. The
sub-questions drive retrieval separately, which is why a vague question still
produces focused evidence sets.

```json
{
  "subQuestions": [
    "What architectures are used for X?",
    "What datasets and metrics evaluate X?",
    "What limitations are reported for X?"
  ],
  "queries": ["...", "..."],
  "yearFrom": 2019, "yearTo": 2026,
  "concepts": ["C41008148"],
  "openAccessOnly": true
}
```

**Extraction** — Analysis pass 1. The schema is the contract; anything not a
field here is invisible to every downstream stage (ADR-011).

```json
{
  "paperId": "uuid", "schemaVersion": 1,
  "problem": "...",
  "method": { "name": "...", "family": "...", "summary": "...", "novelty": "..." },
  "datasets": [{ "name": "...", "size": "...", "chunkId": "..." }],
  "metrics":  [{ "name": "...", "value": "...", "chunkId": "..." }],
  "baselines": ["..."],
  "limitations": [{ "text": "...", "statedByAuthors": true, "chunkId": "..." }],
  "claimedContribution": "..."
}
```

Every extracted fact carries the `chunkId` it came from. This is what makes
verification possible later — a fact without provenance cannot be checked, and
an unverifiable fact should never reach the user.

**VerifiedClaim** — the output researchers actually judge us on.

```json
{
  "claimId": "uuid",
  "text": "Method A outperforms Method B on dataset D by 3.2 F1.",
  "chunkId": "uuid",
  "status": "supported",
  "note": "Table 3 reports 84.1 vs 80.9 F1."
}
```

### Fan-out and concurrency

| Stage | Shape | Concurrency | Bounded by |
|---|---|---|---|
| OpenAlex search | 4–8 queries | parallel | polite pool, mailto in UA |
| PDF download | ≤20 | **serial-ish** | arXiv ~1 req/3s — queue, don't fan out |
| GROBID | ≤20 | 4 at a time | GROBID pool size |
| Embedding | ~1500 chunks | batched 128/call | Voyage rate limit |
| Retrieval | 3–5 sub-questions | parallel | cheap |
| Extraction | ≤20 | 5 at a time | Anthropic rate limit; cache-friendly |
| Verification | 20–60 claims | 8 at a time | Anthropic rate limit |

Ingest is the long pole — roughly 2–4 minutes for 20 fresh papers, near zero when
they are already ingested. Report it honestly in the progress stream rather than
letting the UI look stalled.

---

## Run state machine

```
queued ─► planning ─► searching ─► ingesting ─► retrieving
                                                    │
                                                    ▼
        completed ◄─ gap_analysis ◄─ verifying ◄─ analyzing
            │
            └─► failed        (terminal)
            └─► partial       (terminal, some papers failed to ingest)
```

`partial` is a first-class outcome, not an error. If 3 of 20 papers fail to parse,
the run continues with 17 and says so. Refusing to produce anything because one
PDF was a scan would be the wrong behaviour.

Persist state transitions to `runs` on every change (ADR-014). A client
reconnecting mid-run replays from the database, not from memory.

### SSE event stream

```
event: stage    data: {"stage":"ingesting","status":"started"}
event: progress data: {"stage":"ingesting","done":7,"total":20}
event: partial  data: {"type":"paper","paperId":"...","title":"..."}
event: warning  data: {"code":"parse_failed","paperId":"...","detail":"..."}
event: stage    data: {"stage":"ingesting","status":"completed","durationMs":142000}
event: done     data: {"runId":"...","status":"partial","papersUsed":17}
```

Emit `partial` events as papers land so the UI fills in progressively. Waiting
for the whole run before showing anything wastes the most valuable property of
the async design.

---

## Failure handling per stage

| Failure | Response |
|---|---|
| OpenAlex unreachable | Retry with backoff ×3, then fail the run — nothing downstream works |
| PDF 404 / paywalled | Drop that paper, record `oa_unavailable`, continue |
| GROBID parse failure | Fall back to PdfPig, mark `parse_confidence: low`, continue |
| Embedding rate limit | Backoff and retry; batches are idempotent by chunk id |
| Extraction returns invalid JSON | Retry once with the validation error appended; then skip the paper and warn |
| Claude `stop_reason: refusal` | Check `stop_reason` before reading content; log the category, mark the stage degraded |
| Zero papers survive ingest | Terminal `failed` with an actionable message — likely the corpus problem in ADR-007, not a bug |

Rule: **a single paper never fails a run.** Papers are independent, and the
degraded result of 17 papers is useful. Only the stages with no fallback —
search, and having at least one usable paper — are fatal.

---

## Caching layers

| Layer | Key | Invalidated by |
|---|---|---|
| PDF blob | DOI | never |
| TEI parse | DOI + `parse_version` | GROBID upgrade |
| Chunks + vectors | `chunk_id` + `embedding_model` | re-chunking or embedding model change (ADR-004) |
| Extraction | `paperId` + `schemaVersion` | schema change (ADR-011) |
| Prompt prefix | byte-identical prefix | any change before the breakpoint (ADR-015) |
| Run result | `runId` | never — runs are immutable records |

The extraction cache is what makes the system get cheaper as it is used. The
hundredth run in a research area re-extracts almost nothing.

---

## What crosses the network boundary

Flutter never talks to OpenAlex, arXiv, Anthropic, Voyage, or Qdrant directly.
All of it goes through ASP.NET Core. API keys stay server-side; PDFs are proxied
through `/api/papers/{id}/pdf` so the client needs no external credentials and
CORS is never a factor.

The client receives: run status, papers with metadata, the comparison matrix,
synthesis text with inline claim references, verification statuses, and gaps.
It does not receive raw TEI, embeddings, or prompts.
