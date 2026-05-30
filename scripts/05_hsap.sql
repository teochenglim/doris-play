-- ============================================================
-- DEMO 5 · HSAP  –  Structured + Full-Text + Vector in one SQL
-- Note: SEARCH() must be in a WHERE clause on a single table.
-- ============================================================
USE demo;

-- ── 5a  FTS + UNION analytics ────────────────────────────────
SELECT '--- 5a: How many articles exist per topic? ---' AS demo;
SELECT 'Vector / Embedding' AS topic, COUNT(*) AS articles FROM articles WHERE SEARCH('body:vector OR body:embedding')
UNION ALL
SELECT 'Doris Analytics',             COUNT(*)            FROM articles WHERE SEARCH('body:doris AND body:analytics')
UNION ALL
SELECT 'LLM / RAG',                   COUNT(*)            FROM articles WHERE SEARCH('body:LLM OR body:RAG OR body:observability')
ORDER BY articles DESC;

-- ── 5b  FTS ranking with date filter ─────────────────────────
SELECT '--- 5b: Recent articles about "search" after 2024-02-10, ranked by BM25 ---' AS demo;
SELECT id, title, author,
       DATE(pub_dt)           AS published,
       ROUND(SCORE(), 4)      AS bm25
FROM   articles
WHERE  SEARCH('body:search OR title:search')
  AND  pub_dt >= '2024-02-10 00:00:00'
ORDER  BY SCORE() DESC
LIMIT  10;

-- ── 5c  Product search: FTS + price band ─────────────────────
SELECT '--- 5c: Electronics under $300 mentioning "noise" ---' AS demo;
SELECT id, name, category, price
FROM   products
WHERE  SEARCH('description:noise')
  AND  category = 'Electronics'
  AND  price < 300
ORDER  BY price DESC;

-- ── 5d  Reviews dashboard: sentiment histogram ────────────────
SELECT '--- 5d: Star distribution for reviews mentioning "battery" ---' AS demo;
SELECT stars,
       COUNT(*) AS reviews,
       REPEAT('★', stars) AS bar
FROM   product_reviews
WHERE  SEARCH('review_text:battery OR review_text:charging')
GROUP  BY stars
ORDER  BY stars DESC;

-- ── 5e  Articles that mention audio / headphones ──────────────
SELECT '--- 5e: Articles referencing audio products ---' AS demo;
SELECT id, title, author
FROM   articles
WHERE  SEARCH('body:headphones OR body:earbuds OR body:audio OR body:AirPods')
  AND  pub_dt >= '2024-01-01'
ORDER  BY id;
