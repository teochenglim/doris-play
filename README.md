# Apache Doris 4.0 · Feature Demo

Single-container demo that showcases every new 4.0 feature in ~5 minutes.
Runs on **Apple Silicon MBP** (arm64) out of the box.

```
doris-demo/
├── docker-compose.yml   ← single Doris 4.0 container
├── .env                 ← LLM + embedding config (Ollama by default)
├── run_demo.sh          ← one script to run them all
└── scripts/
    ├── 00_wait.sh       ← health-check helper
    ├── 01_setup.sql     ← DB + tables + LLM resource
    ├── 02_fulltext.sql  ← SEARCH() DSL + BM25
    ├── 03_ai_functions.sql  ← AI_SENTIMENT / CLASSIFY / SUMMARIZE
    ├── 04_vector.py     ← HNSW ANN + real embeddings
    └── 05_hsap.sql      ← Hybrid analytics
```

---

## Prerequisites

| Tool | Install |
|------|---------|
| Docker Desktop | https://www.docker.com/products/docker-desktop/ |
| MySQL client   | `brew install mysql-client` |
| Python 3.10+   | `brew install python` (vector demo only) |
| Ollama         | https://ollama.com — with `llama3.1:8b` and `bge-m3` pulled |

> **Docker Desktop → Settings → General → "Use Rosetta for x86/amd64"**
> should be ON (it is by default on macOS 14+). The `dyrnq/doris:4.0.4`
> image has a native `linux/arm64` layer so no emulation is actually needed.

---

## Quickstart

### 1 · Start Doris

```bash
docker compose up -d
```

Takes about 90 s to fully start. Watch logs:
```bash
docker compose logs -f
```

### 2 · Start Ollama and pull models

```bash
ollama pull llama3.1:8b      # LLM for AI functions (demos 3 & 5)
ollama pull bge-m3           # embeddings for vector search (demo 4)
```

The `.env` is pre-configured to use these models via Ollama — no API key needed.
Doris (running in Docker) reaches Ollama via `host.docker.internal:11434`;
the Python embedding script talks to `localhost:11434` directly.

### 3 · Run all demos

```bash
chmod +x run_demo.sh
./run_demo.sh all
```

Or run individually:

```bash
./run_demo.sh 1   # setup  (always run first)
./run_demo.sh 2   # full-text search
./run_demo.sh 3   # AI functions
./run_demo.sh 4   # vector search
./run_demo.sh 5   # HSAP analytics
```

### 4 · Web UI

Open http://localhost:8030  
User: `root` · Password: *(empty)*

---

## What each demo shows

### Demo 1 · Setup
- Creates `demo` database
- Registers LLM resource with your API key
- Creates `product_reviews`, `articles`, `products` tables with sample data
- `products` gets an **HNSW vector index** (dim=8 toy vectors, replaced in demo 4)

### Demo 2 · Full-Text Search
Slide reference: **"SEARCH() Function"** (slide 10–11)

```sql
-- BM25 relevance scoring
SELECT id, title, ROUND(SCORE(), 4) AS bm25
FROM   articles
WHERE  SEARCH('body:"vector database" OR body:search')
ORDER  BY bm25 DESC;

-- Hybrid: FTS + structured filter
SELECT id, product, stars
FROM   product_reviews
WHERE  SEARCH('review_text:noise') AND stars >= 4;
```

### Demo 3 · AI Functions
Slide reference: **"Call LLMs Without Leaving SQL"** (slide 11)

```sql
-- Sentiment in one line
SELECT product, AI_SENTIMENT(review_text, 'llm') AS mood
FROM   product_reviews;

-- Classify review topic
SELECT AI_CLASSIFY(review_text,
  'sound quality,battery life,build quality,value for money', 'llm')
FROM product_reviews;
```

### Demo 4 · Vector Search
Slide reference: **"HNSW vector index"** (slides 9, 15–16)

- Calls Ollama (`bge-m3`) to generate 1024-d real vectors
- Rebuilds `products` table with correct dimension
- Runs ANN TopN queries: *"wireless noise cancelling headphones"*
- Runs **hybrid** query: vector + `category` filter + `SEARCH()` full-text

### Demo 5 · HSAP
Slide reference: **"One Query to Rule Them All"** (slide 13)

- FTS + GROUP BY in a single SQL
- Cross-table JOIN with inline SEARCH()
- Star-distribution histogram with FTS filter

---

## Stop & clean up

```bash
docker compose down          # stop, keep data
docker compose down -v       # stop + delete volumes
```
