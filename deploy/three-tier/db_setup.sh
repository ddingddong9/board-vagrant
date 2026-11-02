#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
source /home/vagrant/provision/secrets.env
[[ "$BOARD_DB_PASSWORD" =~ ^[a-f0-9]{48}$ ]]
echo '[1/4] MariaDB 설치'
apt-get update -y
apt-get install -y mariadb-server mariadb-client tzdata
systemctl enable --now mariadb
echo '[2/4] 서울 타임존 및 내부 IP 바인딩'
mariadb-tzinfo-to-sql /usr/share/zoneinfo | mariadb mysql
cat > /etc/mysql/mariadb.conf.d/zzz-board.cnf <<'CONF'
[mysqld]
bind-address = 192.168.157.132
default-time-zone = Asia/Seoul
CONF
echo '[3/4] board DB·테이블 및 WAS 전용 계정 생성'
mariadb <<SQL
CREATE DATABASE IF NOT EXISTS board CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'board_app'@'192.168.157.131' IDENTIFIED BY '$BOARD_DB_PASSWORD';
ALTER USER 'board_app'@'192.168.157.131' IDENTIFIED BY '$BOARD_DB_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE ON board.* TO 'board_app'@'192.168.157.131';
CREATE TABLE IF NOT EXISTS board.posts (
 id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
 title TEXT NOT NULL,
 content TEXT NOT NULL,
 regdate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 moddate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
SQL
echo '[4/4] 설정 적용 및 확인'
systemctl restart mariadb
mariadb -e 'SELECT VERSION(), @@global.time_zone, NOW();'
rm -f /home/vagrant/provision/secrets.env
echo 'DB 배포 완료'
