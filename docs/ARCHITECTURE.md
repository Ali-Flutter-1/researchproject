# PractSearch — Research Assistant Architecture

Question → search papers → retrieve sections → understand → compare methods →
evidence-backed analysis → research gaps.

## Stack (decided)

| Layer | Choice |
|---|---|
| Client | Flutter (web + mobile), pinned to 3.38.4 via FVM |
| API | ASP.NET Core 8 Web API (C#) |
| LLM | Claude Opus 5 (`claude-opus-5`) via the `Anthropic` NuGet SDK |
| Embeddings | Voyage `voyage-3` (1024-dim) |
| Vector DB | Qdrant (Docker, `Qdrant.Client` NuGet) |
| Relational | PostgreSQL (papers, runs, citations, users) |
| Corpus | OpenAlex (metadata/discovery) + arXiv (open-access PDFs) |
| PDF parsing | GROBID (Docker) for structured TEI; PdfPig as fallback |

## Request flow

```
Flutter  ──POST /api/research──►  ASP.NET Core
                                      │
                                      ▼
                            Orchestrator (durable job)
                                      │
   ┌──────────┬──────────┬────────────┼────────────┬───────────┐
   ▼          ▼          ▼            ▼            ▼           ▼
 Search    Ingest      RAG        Analysis     Citation    Gap
 Agent     (PDF)      Agent        Agent        Agent     Agent
   │          │          │            │            │           │
 OpenAlex  GROBID    Qdrant +     Claude       Claude      Claude
 + arXiv   → chunks  Voyage       Opus 5       Opus 5      Opus 5
```

The run is **async**: `POST /api/research` returns a `runId` immediately; Flutter
subscribes to `GET /api/research/{runId}/stream` (SSE) for per-stage progress.
A full run takes minutes — do not model it as one blocking HTTP call.

## Agents

Each agent is a C# class behind an interface, invoked by the orchestrator in a
fixed pipeline. This is a **workflow**, not an autonomous agent loop: the stage
order is known in advance, so code controls it. Only the Analysis agent gets
tool-use freedom (it may call back into retrieval for follow-up evidence).

### 1. Search Agent
- Claude expands the research question into 4–8 OpenAlex query strings + filters
  (year range, open-access only, concept IDs). Use **structured outputs**
  (`output_config.format`) so the query plan comes back as validated JSON.
- Query OpenAlex `/works`, dedupe by DOI, rank by citation count + recency +
  semantic similarity of the abstract to the question.
- Keep the top N (default 20) that have a retrievable open-access PDF.

### 2. Ingest / PDF Agent
- Download PDF → GROBID `/api/processFulltextDocument` → TEI XML.
- TEI gives you real section boundaries (Abstract, Methods, Results...),
  figure/table captions, and a parsed reference list. That reference list is
  what makes the Citation Agent possible — don't skip GROBID for raw text.
- Chunk **within section boundaries**, ~800 tokens with 15% overlap. Every chunk
  carries `{paperId, doi, sectionType, sectionTitle, pageNumber, charRange}`.
- Embed with `voyage-3`, upsert into Qdrant with that metadata as payload.

### 3. RAG Agent
- Hybrid retrieval: dense (Qdrant) + BM25 (Postgres full-text), fused with
  Reciprocal Rank Fusion. Pure vector search underperforms on the exact
  method names and metric names researchers actually ask about.
- Filter by `sectionType` per sub-question — a "what methods" question should
  weight Methods sections, a "how well" question should weight Results.
- Rerank top 50 → top 12 with `rerank-2`, then hand chunks to the LLM.

### 4. Analysis Agent
- Two passes. Pass 1: per-paper structured extraction into a fixed schema
  (`problem`, `method`, `datasets[]`, `metrics[]`, `baselines[]`, `limitations[]`,
  `claimedContribution`) — one call per paper, parallelizable, cacheable.
- Pass 2: cross-paper comparison over those structured records plus retrieved
  chunks. Produces the comparison matrix and the narrative synthesis.
- Every factual sentence must carry a `chunkId`. Enforce it in the output
  schema, not in the prompt alone.

### 5. Citation Agent
- Verification, not formatting. For each claim: re-embed the claim, check it
  against its cited chunk, and have Claude return
  `supported | partially_supported | contradicted | not_found`.
- Anything below `supported` gets flagged in the UI rather than silently shipped.
  This is the feature that separates this from "ChatGPT with papers".
- Also resolves the GROBID reference list against OpenAlex to build the local
  citation graph.

### 6. Gap Agent
- Operates on the structured records, not free text. Gaps fall out of the matrix:
  method × dataset cells with no coverage, metrics only one paper reports,
  limitations named by ≥2 papers that no paper addresses, and citation-graph
  leaves (recent work nothing has built on).
- Claude ranks and writes up the candidates; the enumeration is code.

## Prompt caching

The per-paper extraction prompt is identical across papers except for the
document. Put the system prompt + schema + few-shot examples before the last
`cache_control` breakpoint and the paper after it. On a 20-paper run that is
the single biggest cost lever. Verify with `usage.cache_read_input_tokens`.

## Evaluation

Build this from day one, not at the end:

- **Retrieval**: Recall@20, nDCG@10 on a hand-labelled set of ~30
  question→relevant-chunk pairs.
- **Faithfulness**: % of claims the Citation Agent marks `supported`.
- **Extraction**: field-level accuracy against 10 papers you annotate by hand.
- **End-to-end**: a rubric-graded LLM judge (Claude Opus 5) over ~20 golden
  questions, scored on coverage, correctness, and gap plausibility.

## Data model (Postgres)

`papers`(id, doi, title, authors, year, venue, oa_url, openalex_id)
`sections`(id, paper_id, type, title, page_start, text)
`chunks`(id, section_id, char_start, char_end, qdrant_point_id)
`runs`(id, question, status, created_at)
`run_papers`(run_id, paper_id, relevance_score)
`extractions`(run_id, paper_id, jsonb)
`claims`(id, run_id, text, chunk_id, verification_status)

## API surface

```
POST   /api/research            { question } -> { runId }
GET    /api/research/{id}       -> full result
GET    /api/research/{id}/stream-> SSE stage events
GET    /api/papers/{id}         -> metadata + sections
GET    /api/papers/{id}/pdf     -> proxied PDF for the in-app viewer
POST   /api/library/upload      -> user's own PDF into the same pipeline
```

## Build order

1. **Week 1** — Postgres + Qdrant + GROBID in docker-compose. ASP.NET skeleton.
   Ingest 20 arXiv PDFs by hand. Prove chunk quality before writing any agent.
2. **Week 2** — Search Agent + RAG Agent. Flutter screen: question in, ranked
   papers + cited snippets out. This is the first end-to-end slice.
3. **Week 3** — Analysis Agent (both passes) + the comparison matrix UI.
4. **Week 4** — Citation Agent + Gap Agent + the eval harness.
5. **Week 5** — user PDF upload, export (BibTeX + Markdown report), polish.

Ship stage 2 fully working before starting stage 3. A shaky retrieval layer
makes every downstream agent look broken for reasons you cannot debug.

## Risks

- **arXiv is not all of science.** OA coverage in your target domain may be thin.
  Check it in week 1 with real questions before committing to the corpus.
- **GROBID quality varies** with PDF origin. Scanned and two-column non-LaTeX
  papers degrade badly. Have a fallback path and surface parse confidence.
- **Cost.** 20 papers × 2 passes × Opus 5 is real money per run. Caching, and a
  cheaper model (`claude-haiku-4-5`) for the mechanical extraction pass once the
  schema is stable, are the two levers. Measure before optimizing.
- **Rate limits.** OpenAlex wants a mailto in the UA; arXiv wants ~1 req/3s.
  Queue the ingest, don't fan out.
