-- ============================================================
-- DEMO 3 · AI Functions  –  LLM calls from SQL
-- Doris 4.1 signatures:
--   AI_SENTIMENT(resource, text)
--   AI_CLASSIFY(resource, text, ['label1','label2',...])
--   AI_SUMMARIZE(resource, text)
--   AI_EXTRACT(resource, text, ['field1','field2',...])
--   AI_FILTER(resource, condition_text)
-- ============================================================
USE demo;

-- ── 3a  AI_SENTIMENT ─────────────────────────────────────────
SELECT '--- 3a: AI_SENTIMENT on all reviews ---' AS demo;
SELECT id,
       product,
       stars,
       AI_SENTIMENT('llm', review_text) AS sentiment
FROM   product_reviews
ORDER  BY id;

-- ── 3b  AI_CLASSIFY ──────────────────────────────────────────
SELECT '--- 3b: AI_CLASSIFY – tag each review topic ---' AS demo;
SELECT id,
       product,
       AI_CLASSIFY(
         'llm',
         review_text,
         ['sound quality','battery life','build quality','call quality','value for money','ease of use']
       ) AS main_topic
FROM   product_reviews
ORDER  BY id;

-- ── 3c  AI_SUMMARIZE ─────────────────────────────────────────
SELECT '--- 3c: AI_SUMMARIZE – one-line summary per review ---' AS demo;
SELECT id,
       product,
       AI_SUMMARIZE('llm', review_text) AS summary
FROM   product_reviews
ORDER  BY id;

-- ── 3d  AI_EXTRACT ───────────────────────────────────────────
SELECT '--- 3d: AI_EXTRACT – pull out pros and cons ---' AS demo;
SELECT id,
       product,
       AI_EXTRACT('llm', review_text, ['pros','cons']) AS extracted
FROM   product_reviews
WHERE  stars IN (2, 5)            -- only extreme reviews
ORDER  BY id;

-- ── 3e  AI_FILTER (screening) ────────────────────────────────
SELECT '--- 3e: AI_FILTER – reviews that mention a hardware defect ---' AS demo;
SELECT id, product, stars, LEFT(review_text, 80) AS snippet
FROM   product_reviews
WHERE  AI_FILTER(
         'llm',
         CONCAT('Does this review mention a hardware defect or physical fault? Review: ', review_text)
       );

-- ── 3f  SEARCH() + AI_SENTIMENT  (HSAP pattern) ──────────────
SELECT '--- 3f: HSAP – FTS filter THEN LLM sentiment analysis ---' AS demo;
SELECT id,
       product,
       ROUND(SCORE(), 3)              AS bm25,
       AI_SENTIMENT('llm', review_text) AS sentiment
FROM   product_reviews
WHERE  SEARCH('review_text:battery OR review_text:charging')
ORDER  BY SCORE() DESC
LIMIT  10;
