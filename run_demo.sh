#!/usr/bin/env bash
# ============================================================
#  Apache Doris 4.0  ·  Feature Demo
#  Usage:  ./run_demo.sh [1|2|3|4|5|all]
#
#  1 = setup       (run first, always)
#  2 = full-text   search  SEARCH() + BM25
#  3 = ai          AI_SENTIMENT / CLASSIFY / SUMMARIZE / EXTRACT
#  4 = vector      HNSW ANN + hybrid (needs Python + API key)
#  5 = hsap        Hybrid Search Analytics Processing
#  all             1 → 2 → 3 → 4 → 5
# ============================================================
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$DIR/scripts"

# ── Load .env ─────────────────────────────────────────────────
if [[ -f "$DIR/.env" ]]; then
  set -a; source "$DIR/.env"; set +a
fi

HOST=${DORIS_HOST:-127.0.0.1}
PORT=${DORIS_PORT:-9030}
# mysql 9.x dropped mysql_native_password; use 8.x client for Doris compatibility
MYSQL8=/opt/homebrew/opt/mysql@8.0/bin/mysql
MYSQL="${MYSQL8:-mysql} -uroot -P$PORT -h$HOST --default-character-set=utf8mb4"

# ── Colour helpers ────────────────────────────────────────────
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'
BLU='\033[0;34m'; CYN='\033[0;36m'; RST='\033[0m'

banner() {
  echo -e "\n${BLU}╔══════════════════════════════════════════════╗${RST}"
  echo -e "${BLU}║  $1${RST}"
  echo -e "${BLU}╚══════════════════════════════════════════════╝${RST}\n"
}
ok()   { echo -e "${GRN}✅  $*${RST}"; }
info() { echo -e "${CYN}ℹ️   $*${RST}"; }
warn() { echo -e "${YLW}⚠️   $*${RST}"; }
die()  { echo -e "${RED}❌  $*${RST}"; exit 1; }

# ── Dependency checks ─────────────────────────────────────────
check_deps() {
  command -v mysql  >/dev/null || die "mysql client not found – brew install mysql-client"
  command -v docker >/dev/null || die "docker not found"
}

# ── Wait for Doris ────────────────────────────────────────────
wait_doris() {
  banner "Waiting for Doris …"
  bash "$SCRIPTS/00_wait.sh"
}

# ── Run a SQL file via envsubst then mysql ────────────────────
run_sql() {
  local file="$1"
  info "Running $(basename "$file") …"
  # envsubst replaces ${LLM_PROVIDER} etc. in 01_setup.sql
  envsubst < "$file" | $MYSQL
  ok "Done"
}

# ── Python vector demo ────────────────────────────────────────
run_vector() {
  banner "DEMO 4 · Vector Search (HNSW + ANN)"
  if [[ -z "${LLM_API_KEY:-}" ]] || [[ "$LLM_API_KEY" == *"YOUR-KEY"* ]]; then
    warn "LLM_API_KEY not set – skipping vector demo (needs embedding API)"
    warn "Edit .env, set LLM_API_KEY, then rerun:  ./run_demo.sh 4"
    return
  fi
  command -v python3 >/dev/null || die "python3 not found"
  # Install deps quietly
  python3 -m pip install -q pymysql openai python-dotenv
  python3 "$SCRIPTS/04_vector.py"
  ok "Vector demo complete"
}

# ── Demo runners ──────────────────────────────────────────────
demo1() {
  banner "DEMO 1 · Setup – DB, tables, LLM resource"
  if [[ -z "${LLM_API_KEY:-}" ]] || [[ "$LLM_API_KEY" == *"YOUR-KEY"* ]]; then
    warn "LLM_API_KEY not set in .env – AI demos (3) will fail until you add it"
  fi
  run_sql "$SCRIPTS/01_setup.sql"
}

demo2() {
  banner "DEMO 2 · Full-Text Search (SEARCH() DSL + BM25)"
  run_sql "$SCRIPTS/02_fulltext.sql"
}

demo3() {
  banner "DEMO 3 · AI Functions (LLM calls from SQL)"
  if [[ -z "${LLM_API_KEY:-}" ]] || [[ "$LLM_API_KEY" == *"YOUR-KEY"* ]]; then
    warn "LLM_API_KEY not set – skipping AI demo"
    warn "Edit .env, set LLM_API_KEY, then rerun:  ./run_demo.sh 3"
    return
  fi
  run_sql "$SCRIPTS/03_ai_functions.sql"
}

demo4() { run_vector; }

demo5() {
  banner "DEMO 5 · HSAP – Hybrid Search Analytics"
  run_sql "$SCRIPTS/05_hsap.sql"
}

# ── Entrypoint ────────────────────────────────────────────────
check_deps

TARGET="${1:-all}"

case "$TARGET" in
  1) wait_doris; demo1 ;;
  2) demo2 ;;
  3) demo3 ;;
  4) demo4 ;;
  5) demo5 ;;
  all)
    wait_doris
    demo1
    demo2
    demo3
    demo4
    demo5
    echo -e "\n${GRN}🎉  All demos complete!${RST}"
    echo -e "${CYN}    Web UI → http://localhost:8030  (user: root, no password)${RST}\n"
    ;;
  *)
    echo "Usage: $0 [1|2|3|4|5|all]"
    echo "  1  setup     – create DB, tables, register LLM resource"
    echo "  2  fulltext  – SEARCH() DSL + BM25 scoring"
    echo "  3  ai        – AI_SENTIMENT / CLASSIFY / SUMMARIZE / EXTRACT"
    echo "  4  vector    – HNSW ANN search + hybrid filter  (needs API key)"
    echo "  5  hsap      – Structured + FTS + aggregation in one SQL"
    echo "  all          – run 1 → 2 → 3 → 4 → 5"
    exit 1
    ;;
esac
