#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p config
if [[ ! -f config/secrets.env ]]; then
  umask 077
  printf 'BOARD_DB_PASSWORD=%s\n' "$(openssl rand -hex 24)" > config/secrets.env
fi
