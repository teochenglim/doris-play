#!/usr/bin/env bash
# Wait until Doris FE is up AND at least one BE is alive.
set -euo pipefail

HOST=${DORIS_HOST:-127.0.0.1}
PORT=${DORIS_PORT:-9030}
MAX=80
MYSQL8=/opt/homebrew/opt/mysql@8.0/bin/mysql
MYSQL="${MYSQL8:-mysql} -uroot -P$PORT -h$HOST --connect-timeout=2"

echo "⏳  Waiting for Doris FE at $HOST:$PORT ..."
for i in $(seq 1 $MAX); do
  if $MYSQL -e "SELECT 1" &>/dev/null; then
    echo "✅  FE is ready  (attempt $i)"
    break
  fi
  printf "   attempt %d/%d\r" "$i" "$MAX"
  sleep 3
  if [[ $i -eq $MAX ]]; then
    echo "❌  FE did not become ready after $((MAX*3))s"
    exit 1
  fi
done

echo "⏳  Waiting for at least one BE to be alive ..."
for i in $(seq 1 $MAX); do
  alive=$($MYSQL -sNe "SHOW BACKENDS" 2>/dev/null | awk -F'\t' '{print $10}' | grep -c "true" || true)
  if [[ "$alive" -ge 1 ]]; then
    echo "✅  Backend is alive  (attempt $i)"
    exit 0
  fi
  printf "   waiting for BE: attempt %d/%d\r" "$i" "$MAX"
  sleep 3
done

echo "❌  No backend became alive after $((MAX*3))s"
exit 1
