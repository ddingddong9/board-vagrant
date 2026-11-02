#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
curl -fsS --max-time 15 http://127.0.0.1:35000/ -o /dev/null
curl -fsS --max-time 15 http://127.0.0.1:35000/api/posts | python3 -c 'import json,sys; rows=json.load(sys.stdin); assert isinstance(rows,list); print("WEB → WAS → DB OK: posts =",len(rows))'
