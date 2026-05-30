# Running Doris on MBP M4 (arm64) with Colima

## Stack
- Container runtime: **Colima** (containerd, no Docker daemon)
- CLI: `nerdctl compose` (not `docker compose`)
- Image: `dyrnq/doris:4.1.1` (arm64 native)

## One-time Colima fix — vm.max_map_count

Doris BE requires `vm.max_map_count=2000000`. On macOS the sysctl lives inside Colima's Linux VM.
Add to `~/.colima/default/colima.yaml`:

```yaml
provision:
  - mode: system
    script: sysctl -w vm.max_map_count=2000000
```

Verify after restart: `colima ssh -- sysctl vm.max_map_count` → should show `2000000`.

## FE_SERVERS format

The `dyrnq/doris` image expects **3 colon-separated fields**: `name:host:edit_log_port`

```yaml
FE_SERVERS: "fe1:doris-fe:9010"   # NOT "doris-fe:9010" (2 fields = broken)
BE_ADDR: "doris-be:9050"          # tell FE the BE's hostname for registration
```

## MySQL client

macOS Homebrew installs MySQL 9.x by default, which dropped `mysql_native_password`.
Use the 8.x client instead:

```bash
/opt/homebrew/opt/mysql@8.0/bin/mysql -uroot -P9030 -h127.0.0.1
```

Or add to PATH: `export PATH="/opt/homebrew/opt/mysql@8.0/bin:$PATH"`

## Start / stop

```bash
nerdctl compose up -d       # start
nerdctl compose down -v     # stop + wipe volumes (full reset)
```

## Check backend

```bash
/opt/homebrew/opt/mysql@8.0/bin/mysql -uroot -P9030 -h127.0.0.1 -e "SHOW BACKENDS\G"
```

`Alive: true` = ready to run demos.
