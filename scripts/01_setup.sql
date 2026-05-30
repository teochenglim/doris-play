-- ============================================================
-- 01_setup.sql  –  Run once after Doris starts
-- Creates the demo database, LLM resource, and all tables.
-- ============================================================

-- ── Database ─────────────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS demo;
USE demo;

-- ── AI Resource  (swap values from .env via envsubst) ────────
-- Drop first so re-runs are idempotent
DROP RESOURCE IF EXISTS llm;
CREATE RESOURCE "llm"
PROPERTIES (
  'type'             = 'ai',
  'ai.provider_type' = '${LLM_PROVIDER}',
  'ai.endpoint'      = '${LLM_ENDPOINT}',
  'ai.model_name'    = '${LLM_MODEL}',
  'ai.api_key'       = '${LLM_API_KEY}',
  'ai.temperature'   = '0.3',
  'ai.max_tokens'    = '512'
);

-- ────────────────────────────────────────────────────────────
-- TABLE 1 · product_reviews
--   Showcases: AI functions (CLASSIFY, SENTIMENT, SUMMARIZE)
--              Full-text search with SEARCH() + BM25 scoring
-- ────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS product_reviews;
CREATE TABLE product_reviews (
  id          INT          NOT NULL,
  product     VARCHAR(120) NOT NULL,
  category    VARCHAR(60),
  review_text VARCHAR(2000) NOT NULL,
  stars       TINYINT,
  created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_fts (review_text) USING INVERTED
    PROPERTIES ("parser" = "english", "support_phrase" = "true")
)
DUPLICATE KEY(id)
DISTRIBUTED BY HASH(id) BUCKETS 4
PROPERTIES ("replication_num" = "1");

INSERT INTO product_reviews VALUES
(1,  'Sony WH-1000XM5',      NULL, 'Absolutely love the noise cancelling – best headphones I have ever owned. Battery lasts forever and they fold flat for travel. The sound quality is exceptional for music and podcasts.', 5, '2024-01-10 09:00:00'),
(2,  'Sony WH-1000XM5',      NULL, 'Great headphones but the call quality is mediocre. Mic picks up too much background noise. ANC is top notch though.', 3, '2024-01-11 10:30:00'),
(3,  'Kindle Paperwhite',    NULL, 'Perfect for reading in bed. The warm light setting is easy on the eyes. Waterproof design saved it from a poolside accident. Highly recommend for avid readers.', 5, '2024-01-12 08:00:00'),
(4,  'Kindle Paperwhite',    NULL, 'Battery drains faster than expected and the sync with Audible is buggy. Still usable but disappointing for the price.', 2, '2024-01-13 14:00:00'),
(5,  'DJI Mini 4 Pro',       NULL, 'Incredible drone for the price. Video quality is stunning and the obstacle avoidance works great. Setup was easy even for a beginner.', 5, '2024-01-14 07:00:00'),
(6,  'DJI Mini 4 Pro',       NULL, 'Wind resistance is poor – loses connection in moderate breeze. Customer support was unhelpful when I reported the issue.', 2, '2024-01-15 18:00:00'),
(7,  'Instant Pot Duo',      NULL, 'Changed how I cook. Soups, stews, rice – all perfect. Saves so much time versus stovetop. The sauté function is surprisingly good too.', 5, '2024-01-16 12:00:00'),
(8,  'Instant Pot Duo',      NULL, 'Seal ring absorbs smells permanently. Had to buy a replacement. Otherwise a solid appliance for everyday cooking.', 3, '2024-01-17 09:00:00'),
(9,  'Apple AirPods Pro 2',  NULL, 'Transparency mode is magical – I can hear traffic without removing them. Fit is comfortable for hours. The case charges fast.', 5, '2024-01-18 11:00:00'),
(10, 'Apple AirPods Pro 2',  NULL, 'Expensive for what they are. One earbud developed a crackling sound after 3 months. Apple replaced it but the process was slow.', 2, '2024-01-19 15:00:00');

-- ────────────────────────────────────────────────────────────
-- TABLE 2 · articles
--   Showcases: Full-text search SEARCH() DSL
--              BM25 scoring  •  MATCH_PHRASE  •  Hybrid filter
-- ────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS articles;
CREATE TABLE articles (
  id      INT          NOT NULL,
  title   VARCHAR(200) NOT NULL,
  body    VARCHAR(4000) NOT NULL,
  author  VARCHAR(80),
  tags    VARCHAR(200),
  pub_dt  DATETIME,
  INDEX idx_title (title) USING INVERTED PROPERTIES ("parser" = "english"),
  INDEX idx_body  (body)  USING INVERTED
    PROPERTIES ("parser" = "english", "support_phrase" = "true")
)
DUPLICATE KEY(id)
DISTRIBUTED BY HASH(id) BUCKETS 4
PROPERTIES ("replication_num" = "1");

INSERT INTO articles VALUES
(1,  'Vector Databases Explained',
     'Vector databases store high-dimensional embeddings and support approximate nearest neighbour search. They are essential for semantic search, recommendation engines, and retrieval-augmented generation pipelines. Popular options include Pinecone, Weaviate, Milvus, and Qdrant.',
     'Alice Tan', 'vector,database,AI', '2024-02-01 09:00:00'),
(2,  'Apache Doris 4.0 Breakthrough',
     'Apache Doris 4.0 unifies OLAP analytics, full-text search, and vector search into a single SQL engine. The release introduces HNSW vector indexes, the SEARCH() DSL with BM25 scoring, and AI functions that call LLMs directly from SQL queries.',
     'Bob Lee',   'doris,database,AI,search', '2024-02-05 10:00:00'),
(3,  'Real-Time Analytics with Apache Doris',
     'Apache Doris delivers sub-second OLAP queries on petabytes of data. Its vectorised execution engine and column-oriented storage make it ideal for dashboards, user behaviour analytics, and log analysis at scale.',
     'Carol Wong', 'doris,analytics,realtime', '2024-02-10 08:00:00'),
(4,  'RAG Architecture Best Practices',
     'Retrieval-augmented generation combines a vector store with a large language model to answer questions grounded in private data. Key considerations include chunking strategy, embedding model choice, and hybrid retrieval that blends BM25 keyword search with dense vector similarity.',
     'David Kim',  'RAG,LLM,vector,search', '2024-02-15 11:00:00'),
(5,  'Elasticsearch vs Apache Doris for Search',
     'Elasticsearch has long dominated full-text search but carries high operational complexity. Apache Doris 4.0 now offers an Elasticsearch-compatible SEARCH() function with BM25 scoring, making migration straightforward for teams already using SQL analytics.',
     'Eva Lim',    'elasticsearch,doris,search,migration', '2024-02-20 14:00:00'),
(6,  'LLM Observability and Log Analytics',
     'As LLM applications grow, observability becomes critical. Storing inference logs, latency metrics, and error traces in Apache Doris enables SQL-based root cause analysis alongside full-text search on error messages and AI-powered anomaly classification.',
     'Frank Ho',   'LLM,observability,logs,doris', '2024-02-25 09:30:00');

-- ────────────────────────────────────────────────────────────
-- TABLE 3 · products (vector search)
--   Showcases: HNSW vector index  •  ANN similarity search
--              Hybrid: vector + structured filter + full-text
-- Note: embeddings are pre-computed 8-d toy vectors.
--       In the live demo script we generate real embeddings
--       via the Python helper and UPDATE them here.
-- ────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS products;
CREATE TABLE products (
  id          INT           NOT NULL,
  name        VARCHAR(120)  NOT NULL,
  description VARCHAR(1000) NOT NULL,
  price       DECIMAL(10,2),
  category    VARCHAR(60),
  embedding   ARRAY<FLOAT>  NOT NULL,
  INDEX idx_vec (embedding) USING ANN
    PROPERTIES (
      "index_type"  = "hnsw",
      "metric_type" = "l2_distance",
      "dim"         = "8",
      "max_degree"      = "16",
      "ef_construction" = "200"
    ),
  INDEX idx_desc (description) USING INVERTED
    PROPERTIES ("parser" = "english")
)
DUPLICATE KEY(id)
DISTRIBUTED BY HASH(id) BUCKETS 4
PROPERTIES ("replication_num" = "1");

-- Toy 8-d embeddings (replaced by real ones in demo_vector.py)
INSERT INTO products VALUES
(1,  'Sony WH-1000XM5 Headphones',
     'Premium wireless noise-cancelling headphones with 30-hour battery and multipoint connection.',
     349.99, 'Electronics', [0.9,0.1,0.8,0.2,0.7,0.3,0.6,0.4]),
(2,  'Apple AirPods Pro 2',
     'Active noise cancellation earbuds with adaptive transparency and MagSafe charging case.',
     249.99, 'Electronics', [0.85,0.15,0.75,0.25,0.65,0.35,0.55,0.45]),
(3,  'Kindle Paperwhite 11th Gen',
     'Waterproof 6.8-inch e-reader with adjustable warm light and 3-month battery life.',
     139.99, 'Books & Readers', [0.2,0.8,0.3,0.7,0.1,0.9,0.4,0.6]),
(4,  'DJI Mini 4 Pro Drone',
     'Lightweight foldable drone with 4K/60fps video, omnidirectional obstacle sensing, and 34-minute flight time.',
     759.99, 'Electronics', [0.6,0.4,0.5,0.5,0.7,0.3,0.8,0.2]),
(5,  'Instant Pot Duo 7-in-1',
     'Pressure cooker, slow cooker, rice cooker, steamer, sauté pan, yogurt maker, and warmer.',
      99.99, 'Kitchen',     [0.1,0.9,0.2,0.8,0.3,0.7,0.15,0.85]),
(6,  'LEGO Technic Ferrari',
     'Complex 1,677-piece set with working gearbox, V8 engine, and suspension. For ages 10+.',
      89.99, 'Toys',        [0.3,0.7,0.4,0.6,0.2,0.8,0.35,0.65]),
(7,  'Dyson V15 Detect Vacuum',
     'Cordless vacuum with laser dust detection, HEPA filtration, and 60-minute runtime.',
     749.99, 'Home',        [0.4,0.6,0.3,0.7,0.5,0.5,0.45,0.55]),
(8,  'Bose QuietComfort 45',
     'Comfortable over-ear headphones with world-class noise cancellation and 24-hour battery.',
     279.99, 'Electronics', [0.88,0.12,0.78,0.22,0.68,0.32,0.58,0.42]);
