#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
source /home/vagrant/provision/secrets.env
[[ "$BOARD_DB_PASSWORD" =~ ^[a-f0-9]{48}$ ]]
echo '[1/5] Python 3.12, Git 설치'
apt-get update -y
apt-get install -y python3.12-venv python3-pip git ca-certificates curl libffi-dev build-essential
WORKSPACE_DIR=/home/vagrant/workspace
VENV_DIR="$WORKSPACE_DIR/venv312"
BOARD_DIR="$WORKSPACE_DIR/board"
RELEASE_DIR="$WORKSPACE_DIR/releases/$(date +%s%N)"
REPO_URL='https://github.com/ddingddong9/board-vagrant.git'
REPO_REF="${1:-main}"
TMP_CLONE_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_CLONE_DIR"' EXIT
echo '[2/5] GitHub 소스 다운로드 및 작업 폴더 구성'
GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$TMP_CLONE_DIR/source"
install -d "$RELEASE_DIR"
cp -a "$TMP_CLONE_DIR/source/apps/board/." "$RELEASE_DIR/"
cp "$TMP_CLONE_DIR/source/requirements.txt" "$RELEASE_DIR/requirements.txt"
printf '\ngunicorn>=23,<24\ngevent>=24,<26\n' >> "$RELEASE_DIR/requirements.txt"
git -C "$TMP_CLONE_DIR/source" rev-parse HEAD > "$RELEASE_DIR/source-commit.txt"
echo '[3/5] venv312 생성 및 의존성 설치'
python3.12 -m venv "$VENV_DIR"
"$VENV_DIR/bin/pip" install -r "$RELEASE_DIR/requirements.txt"
chown -R vagrant:vagrant "$WORKSPACE_DIR"
runuser -u vagrant -- "$VENV_DIR/bin/python" "$RELEASE_DIR/train_model.py"
echo '[4/5] DB 환경변수 및 현재 소스 연결'
install -m 600 /dev/null /etc/board.env
cat > /etc/board.env <<EOF
DB_HOST=192.168.157.132
DB_PORT=3306
DB_USER=board_app
DB_PASSWORD=$BOARD_DB_PASSWORD
DB_DATABASE=board
EOF
# 릴리스 디렉터리를 보존하여 기존 소스를 덮어쓰거나 삭제하지 않습니다.
ln -sfn "$RELEASE_DIR" "$BOARD_DIR"
echo '[5/5] Gunicorn + Gevent systemd 등록'
cat > /etc/systemd/system/boardapp.service <<'UNIT'
[Unit]
Description=Three-tier Flask board (Gunicorn + Gevent)
Wants=network-online.target
After=network-online.target
[Service]
User=vagrant
Group=vagrant
WorkingDirectory=/home/vagrant/workspace/board
EnvironmentFile=/etc/board.env
Environment=PYTHONUNBUFFERED=1
Environment=OMP_NUM_THREADS=1
Environment=OPENBLAS_NUM_THREADS=1
ExecStart=/home/vagrant/workspace/venv312/bin/gunicorn --workers 3 --worker-class gevent --bind 192.168.157.131:5000 --access-logfile - --error-logfile - app:app
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable boardapp
systemctl restart boardapp
for attempt in {1..30}; do
  if curl -fsS --max-time 3 http://192.168.157.131:5000/api/posts >/dev/null; then
    rm -f /home/vagrant/provision/secrets.env
    echo 'WAS 배포 완료: Gunicorn 3 workers + Gevent → MariaDB'
    exit 0
  fi
  sleep 2
done
journalctl -u boardapp -n 40 --no-pager
exit 1
