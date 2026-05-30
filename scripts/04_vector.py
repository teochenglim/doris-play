#!/usr/bin/env python3
"""
DEMO 4 · Vector Search
  - Calls OpenAI (or compatible) to generate real embeddings
  - Updates the products table with 384-d vectors
  - Runs ANN similarity search + hybrid filter queries
  - Requires: pip install pymysql openai python-dotenv
"""
import os, json, textwrap
from pathlib import Path
import pymysql
from openai import OpenAI
from dotenv import load_dotenv

# ── Config ────────────────────────────────────────────────────
load_dotenv(Path(__file__).parent.parent / ".env")

HOST      = os.getenv("DORIS_HOST", "127.0.0.1")
PORT      = int(os.getenv("DORIS_PORT", "9030"))
API_KEY   = os.getenv("LLM_API_KEY", "ollama")
ENDPOINT  = os.getenv("EMBED_ENDPOINT", os.getenv("LLM_ENDPOINT", "http://localhost:11434/v1"))
EMBED_M   = os.getenv("EMBED_MODEL", "bge-m3")
DIM       = int(os.getenv("EMBED_DIM", "1024"))

client = OpenAI(api_key=API_KEY, base_url=ENDPOINT)

def embed(texts: list[str]) -> list[list[float]]:
    resp = client.embeddings.create(
        model=EMBED_M,
        input=texts,
    )
    return [r.embedding for r in resp.data]

def section(title: str):
    print(f"\n{'─'*60}")
    print(f"  {title}")
    print('─'*60)

def run():
    conn = pymysql.connect(host=HOST, port=PORT, user="root",
                           database="demo", charset="utf8mb4")
    cur  = conn.cursor()

    # ── Step 1: fetch products ────────────────────────────────
    cur.execute("SELECT id, name, description FROM products ORDER BY id")
    rows = cur.fetchall()
    ids, texts = zip(*[(r[0], f"{r[1]}. {r[2]}") for r in rows])

    # ── Step 2: generate real embeddings ─────────────────────
    section(f"Generating embeddings via {ENDPOINT} …")
    vectors = embed(list(texts))
    print(f"  ✅  {len(vectors)} embeddings  (dim={len(vectors[0])})")

    # ── Step 3: recreate table with correct dim ───────────────
    #   (toy data used dim=8; real data uses dim=EMBED_DIM)
    section("Recreating products table with real vectors …")
    cur.execute(f"""
        DROP TABLE IF EXISTS products
    """)
    cur.execute(f"""
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
              "dim"         = "{DIM}",
              "max_degree"      = "16",
              "ef_construction" = "200"
            ),
          INDEX idx_desc (description) USING INVERTED
            PROPERTIES ("parser" = "english")
        )
        DUPLICATE KEY(id)
        DISTRIBUTED BY HASH(id) BUCKETS 4
        PROPERTIES ("replication_num" = "1")
    """)

    # Fetch original rows for price/category
    orig = {r[0]: r for r in rows}
    cur.execute("SELECT id, price, category FROM products") # empty after drop – need original

    # Re-insert from original list with real embeddings
    product_meta = {
        1: (349.99, 'Electronics'),
        2: (249.99, 'Electronics'),
        3: (139.99, 'Books & Readers'),
        4: (759.99, 'Electronics'),
        5: ( 99.99, 'Kitchen'),
        6: ( 89.99, 'Toys'),
        7: (749.99, 'Home'),
        8: (279.99, 'Electronics'),
    }
    for (pid, name, desc), vec in zip(rows, vectors):
        price, cat = product_meta[pid]
        vec_str = "[" + ",".join(f"{v:.6f}" for v in vec) + "]"
        cur.execute(
            "INSERT INTO products VALUES (%s,%s,%s,%s,%s," + vec_str + ")",
            (pid, name, desc, price, cat)
        )
    conn.commit()
    print(f"  ✅  Inserted {len(rows)} products with {DIM}-d vectors")

    # ── Step 4: ANN search ────────────────────────────────────
    queries = [
        ("wireless noise cancelling headphones",  None),
        ("beginner-friendly flying camera drone", None),
        ("kitchen appliance for fast cooking",    None),
    ]

    for q_text, category_filter in queries:
        section(f"ANN query: \"{q_text}\"")
        q_vec = embed([q_text])[0]
        vec_str = "[" + ",".join(f"{v:.6f}" for v in q_vec) + "]"

        where = f"l2_distance_approximate(embedding, {vec_str}) IS NOT NULL"
        if category_filter:
            where += f" AND category = '{category_filter}'"

        sql = f"""
            SELECT id, name, category, price,
                   ROUND(l2_distance_approximate(embedding, {vec_str}), 4) AS dist
            FROM   products
            ORDER  BY dist ASC
            LIMIT  3
        """
        cur.execute(sql)
        print(f"  {'ID':<4} {'Name':<40} {'Category':<16} {'Price':>8}  dist")
        print(f"  {'──':<4} {'──────────────────────────────────────':<40} {'────────':<16} {'─────':>8}  ────")
        for row in cur.fetchall():
            print(f"  {row[0]:<4} {row[1]:<40} {row[2]:<16} ${row[3]:>7.2f}  {row[4]}")

    # ── Step 5: Hybrid – vector + price filter + full-text ────
    section("Hybrid search: \"premium audio\" · Electronics · price < 300")
    q_vec = embed(["premium audio wireless headphones"])[0]
    vec_str = "[" + ",".join(f"{v:.6f}" for v in q_vec) + "]"
    sql = f"""
        SELECT id, name, price,
               ROUND(l2_distance_approximate(embedding, {vec_str}), 4) AS dist
        FROM   products
        WHERE  category = 'Electronics'
          AND  price < 300
          AND  SEARCH('description:wireless OR description:audio')
        ORDER  BY dist ASC
        LIMIT  3
    """
    cur.execute(sql)
    print(f"  {'ID':<4} {'Name':<40} {'Price':>8}  dist")
    for row in cur.fetchall():
        print(f"  {row[0]:<4} {row[1]:<40} ${row[2]:>7.2f}  {row[3]}")

    cur.close()
    conn.close()
    print("\n✅  Vector demo complete\n")

if __name__ == "__main__":
    run()
