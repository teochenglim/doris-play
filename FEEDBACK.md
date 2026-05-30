# Feedback to Apache Doris Team — Developer Experience Report

**Context:** Solo developer, MBP M4 (arm64), running the full Doris 4.1.1 feature demo locally with Colima + Ollama. No cloud. No API keys. Total setup time: ~3 hours of debugging what should have been a 15-minute quickstart.

---

## 1. Breaking Changes Between 4.0 and 4.1 Are Undocumented

This is the single biggest issue. The quickstart examples use 4.0 syntax that silently breaks on 4.1.

### AI Function Signatures Changed

| Function | 4.0 syntax | 4.1 syntax |
|---|---|---|
| `AI_SENTIMENT` | `AI_SENTIMENT(text, 'resource')` | `AI_SENTIMENT('resource', text)` |
| `AI_CLASSIFY` | `AI_CLASSIFY(text, 'cat1,cat2', 'resource')` | `AI_CLASSIFY('resource', text, ['cat1','cat2'])` |
| `AI_SUMMARIZE` | `AI_SUMMARIZE(text, 'lang', max_words, 'resource')` | `AI_SUMMARIZE('resource', text)` |
| `AI_EXTRACT` | `AI_EXTRACT(text, '{"field":"type"}', 'resource')` | `AI_EXTRACT('resource', text, ['field1','field2'])` |
| `AI_FILTER` | `AI_FILTER(text, 'resource')` | `AI_FILTER('resource', text)` |

**The error message is misleading.** "AI Function must accept literal for the resource name" doesn't tell you that the argument ORDER changed — a developer will waste time checking whether the resource was created correctly.

### HNSW Index Property Names Changed

```sql
-- 4.0 (broken in 4.1)
"M" = "16", "efConstruction" = "200"

-- 4.1 correct
"max_degree" = "16", "ef_construction" = "200"
```

Error message: `unknown ann index property: efConstruction`. At least this one is clear.

### `SCORE()` Now Requires `LIMIT`

Queries using `SCORE()` for BM25 ranking without a `LIMIT` clause silently fail in 4.1:

```
score() function requires WHERE clause with MATCH function, ORDER BY and LIMIT for optimization
```

Also: `ORDER BY <alias>` doesn't work when the alias wraps `SCORE()`. Must use `ORDER BY SCORE() DESC`.

### `DEFAULT NOW()` Rejected

```sql
-- fails in 4.1
created_at DATETIME DEFAULT NOW()

-- fix
created_at DATETIME DEFAULT CURRENT_TIMESTAMP
```

---

## 2. `SEARCH()` Scope Restrictions Not Documented

`SEARCH()` only works in `WHERE` filters on single-table scans. This is a hard constraint with no mention in the docs.

**What fails:**
- `CASE WHEN SEARCH(...) THEN ...` — "search() predicates are only supported inside WHERE filters"
- `JOIN ... ON SEARCH(...)` — same error
- `ORDER BY bm25 DESC` where `bm25` is an alias for `ROUND(SCORE(), 4)` — silently wrong result until you hit the LIMIT error

**Suggestion:** Add a "Limitations" section to the SEARCH() and SCORE() docs. The error message is accurate but the docs imply broader usage.

---

## 3. AI Resource Endpoint Format Undocumented for Local/OpenAI-Compatible LLMs

The docs show `ai.endpoint = 'https://api.openai.com/v1'` for OpenAI. This suggests the endpoint is a base URL, consistent with the OpenAI SDK convention.

**But Doris 4.1 requires the full path:**

```sql
-- fails (404 on health check to /v1)
'ai.endpoint' = 'http://localhost:11434/v1'

-- works
'ai.endpoint' = 'http://localhost:11434/v1/chat/completions'
```

This is the **opposite** of how the OpenAI Python SDK works (`base_url` without the path). A developer swapping from the Python SDK will get this wrong every time. The docs should clarify that Doris uses the final endpoint URL, not the base URL.

This also means the OpenAI examples in the docs are likely wrong: `https://api.openai.com/v1` should be `https://api.openai.com/v1/chat/completions`.

---

## 4. Docker/Local Setup Gaps

### `dyrnq/doris` FE_SERVERS Format Is Wrong in All Examples

The format required by the image entrypoint is `name:host:port` (3 fields):

```yaml
FE_SERVERS: "fe1:doris-fe:9010"   # correct
FE_SERVERS: "doris-fe:9010"       # broken — "9010" becomes the hostname
```

None of the community Docker Compose examples document this. The BE silently loops trying to connect to a host named `9010`.

### `BE_ADDR` Required for BE Registration

When running FE and BE as separate containers, the BE must explicitly tell FE its hostname:

```yaml
BE_ADDR: "doris-be:9050"
```

Without this, FE registers the BE's internal IP (which may be correct in some setups) but with hostname-based Docker networking it can cause heartbeat failures.

### `vm.max_map_count` on macOS Has No Fix Documented

Doris BE requires `vm.max_map_count=2000000`. On macOS with Colima or Docker Desktop this lives inside a Linux VM. The BE logs warn about it but give no macOS-specific fix. BE then enters a restart loop.

**Fix for Colima:**
```yaml
# ~/.colima/default/colima.yaml
provision:
  - mode: system
    script: sysctl -w vm.max_map_count=2000000
```

The docs mention Linux `sysctl -w` commands but have no macOS section at all.

### MySQL 9.x Client Incompatible with Doris

macOS Homebrew ships MySQL 9.x by default. MySQL 9.x dropped `mysql_native_password`, which Doris requires. The quickstart says `brew install mysql-client` — this installs 9.x and breaks immediately with an auth plugin error.

**Fix:** Specify `mysql-client@8.0` in the quickstart guide.

---

## 5. What Worked Well

- The `dyrnq/doris` multi-arch image is excellent for local dev. Arm64 native on M-series Macs is a great DX win.
- `SHOW BACKENDS\G` gives clear health status for debugging cluster issues.
- The AI function integration concept is compelling — `AI_SENTIMENT` in SQL is genuinely impressive in a demo.
- Vector search with real embeddings (bge-m3 via Ollama, 1024-d HNSW) worked first try once the property names were corrected.
- The `default_ai_resource` session variable is a clean ergonomic design.

---

## Summary: Prioritized Asks

1. **Publish a 4.0 → 4.1 migration guide** with the AI function signature changes table. This is the highest-impact gap.
2. **Fix the AI endpoint docs** — clarify that Doris needs the full URL, not the base URL. Update the OpenAI example.
3. **Add a macOS local dev guide** covering Colima vm.max_map_count, mysql@8.0, and the FE_SERVERS format.
4. **Add a SEARCH() Limitations section** — single-table WHERE only, SCORE() needs LIMIT.
5. **Improve AI function error messages** — "must accept literal for resource name" should hint that the resource should be the first argument.
