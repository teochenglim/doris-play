-- ============================================================
-- DEMO 2 · Full-Text Search  –  SEARCH() DSL + BM25 scoring
-- ============================================================
USE demo;

-- ── 2a  Simple TERM query ─────────────────────────────────────
SELECT '--- 2a: TERM query: articles about "vector" ---' AS demo;
SELECT id, title, author
FROM   articles
WHERE  SEARCH('body:vector')
ORDER  BY id;

-- ── 2b  BM25 relevance scoring ────────────────────────────────
SELECT '--- 2b: BM25 scoring for "vector database search" ---' AS demo;
SELECT id, title, ROUND(SCORE(), 4) AS bm25
FROM   articles
WHERE  SEARCH('body:"vector database" OR body:search OR body:BM25')
ORDER  BY SCORE() DESC
LIMIT  10;

-- ── 2c  Boolean AND/OR/NOT ────────────────────────────────────
SELECT '--- 2c: Boolean – doris AND (search OR analytics) NOT elasticsearch ---' AS demo;
SELECT id, title
FROM   articles
WHERE  SEARCH('body:doris AND (body:search OR body:analytics) AND NOT body:elasticsearch');

-- ── 2d  PHRASE search ─────────────────────────────────────────
SELECT '--- 2d: Phrase – "noise cancelling" in reviews ---' AS demo;
SELECT id, product, stars, LEFT(review_text, 80) AS snippet
FROM   product_reviews
WHERE  SEARCH('review_text:"noise cancelling"')
ORDER  BY stars DESC;

-- ── 2e  Hybrid: full-text + structured filter ─────────────────
SELECT '--- 2e: Hybrid – "noise" in reviews AND stars >= 4 ---' AS demo;
SELECT id, product, stars, LEFT(review_text, 80) AS snippet
FROM   product_reviews
WHERE  SEARCH('review_text:noise') AND stars >= 4
ORDER  BY stars DESC;

-- ── 2f  SEARCH() + aggregation ───────────────────────────────
SELECT '--- 2f: Aggregate – avg stars for reviews mentioning "battery" ---' AS demo;
SELECT product,
       COUNT(*)        AS total_reviews,
       ROUND(AVG(stars),1) AS avg_stars
FROM   product_reviews
WHERE  SEARCH('review_text:battery')
GROUP  BY product
ORDER  BY avg_stars DESC;
