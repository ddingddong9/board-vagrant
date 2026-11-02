#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
echo '[1/4] Nginx, Git 설치'
apt-get update -y
apt-get install -y nginx git ca-certificates
REPO_URL='https://github.com/ddingddong9/board-vagrant.git'
REPO_REF="${1:-main}"
TARGET_DIR=/var/www/board
TMP_CLONE_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_CLONE_DIR"' EXIT
echo '[2/4] GitHub 정적 페이지 다운로드'
GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$TMP_CLONE_DIR/source"
# 기존 board 화면은 Jinja 변수가 없는 HTML/JS이므로 Nginx에서 그대로 제공.
# API 주소가 /api/posts인 상대 경로이므로 별도 CORS 설정이 필요하지 않음.
install -d -m 755 "$TARGET_DIR"
if [[ -f "$TARGET_DIR/index.html" ]]; then
  cp -a "$TARGET_DIR/index.html" "$TARGET_DIR/index.html.backup.$(date +%s%N)"
fi
install -m 644 "$TMP_CLONE_DIR/source/apps/board/templates/index.html" "$TARGET_DIR/index.html"
git -C "$TMP_CLONE_DIR/source" rev-parse HEAD > "$TARGET_DIR/source-commit.txt"
chown -R www-data:www-data "$TARGET_DIR"
echo '[3/4] Nginx 정적 파일 및 WAS 프록시 설정'
cat > /etc/nginx/sites-available/default <<'NGINX'
# WAS를 증설하면 아래 upstream에 해당 IP:5000을 추가합니다.
upstream my_was_servers {
    server 192.168.157.131:5000;
}
server {
    listen 80 default_server;
    server_name _;
    root /var/www/board;
    index index.html;
    add_header X-Served-By "three-tier-web" always;
    location / { try_files $uri $uri/ =404; }
    location = /source-commit.txt { deny all; }
    location ~ \.backup\. { deny all; }
    location /api/ {
        proxy_pass http://my_was_servers;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX
echo '[4/4] Nginx 자동 시작'
nginx -t
systemctl enable nginx
systemctl restart nginx
echo 'WEB 배포 완료: 정적 페이지 → Nginx, /api/ → WAS'
