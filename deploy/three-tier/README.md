# WEB / WAS / DB 3티어 실습

제공된 강사님 WEB·WAS·DB setup.sh를 현재 Mac M4와 Vagrant에 맞춘 구성입니다.

| VM | 사설 IP | 역할 | Mac SSH 포트 |
| --- | --- | --- | --- |
| web | 192.168.157.130 | Nginx 정적 HTML 및 /api/ 프록시 | 4321 |
| was | 192.168.157.131 | Flask + Gunicorn 3 workers + Gevent, :5000 | 4322 |
| db | 192.168.157.132 | MariaDB board DB, :3306 | 4323 |

흐름: 브라우저 → WEB Nginx → /api/ → WAS Gunicorn/Flask → DB MariaDB.
WAS는 1대이며 Nginx upstream에 서버를 추가하면 확장할 수 있습니다. 3티어는 계층 구분이며 WAS 3대를 뜻하지 않습니다.

## 실행

VMware Fusion, Vagrant VMware Utility, vagrant-vmware-desktop 설치 후:

```bash
./start.sh
```

VirtualBox 사용 시 `VAGRANT_DEFAULT_PROVIDER=virtualbox ./start.sh`.
같은 프로젝트의 VM을 만든 뒤 provider를 바꾸려면 별도 복사본에서 실행합니다.
웹 접속: http://127.0.0.1:35000/
SSH: `vagrant ssh web`, `vagrant ssh was`, `vagrant ssh db`.
종료: `vagrant halt`. 재시작: `./start.sh`.

## GitHub 자동 소스 적용

WEB과 WAS는 https://github.com/ddingddong9/board-vagrant 의 main 브랜치를 각각 clone합니다.
WEB은 기존 apps/board/templates/index.html을 정적 index.html로 배포합니다. 이 HTML에는 Jinja 변수가 없고 API는 상대 경로를 사용합니다.
WAS는 apps/board와 requirements.txt를 받고 AI 모델을 학습한 뒤 app:app을 Gunicorn으로 실행합니다.
소스 갱신: DB를 먼저 켜고 `vagrant provision was web`.

## 강사님 코드에서 맞춘 부분

- /home/ubuntu → /home/vagrant 또는 /var/www/board
- flask==3.13 대신 기존 저장소의 Flask 버전 범위 사용
- 고정 예시 IP 대신 위 사설 IP 사용
- WEB에는 Nginx, WAS에는 Python/Gunicorn, DB에는 MariaDB만 설치
- 전역 root@% 대신 WAS IP의 board_app 전용 계정, 암호는 prepare.sh로 로컬 생성
- MariaDB 설정 전용 파일로 재실행 시 타임존 중복 추가 방지
- 원본 디렉터리/백업을 삭제하는 대신 이전 WAS 릴리스와 WEB HTML 보관
- Vagrant가 네트워크를 설정하므로 netplan 파일을 수동 덮어쓰지 않음

## 기존 환경 및 외부 도메인

기존 2티어 VirtualBox·VMware VM과 다른 IP/포트/VM 이름을 사용합니다.
새 DB는 빈 게시판으로 시작합니다. 기존 게시글은 별도 SQL 백업을 복원해야 합니다.
기존 Cloudflare 도메인은 그대로 기존 서버에 연결되어 있습니다. 3티어 외부 연결 시 cloudflared를 WEB에 설치하고 터널 서비스를 http://localhost:80으로 지정합니다.
기존 터널과 동시에 같은 토큰의 커넥터를 켜면 요청이 양쪽에 분산될 수 있으므로 실제 이전 시 기존 커넥터 종료와 함께 전환해야 합니다.
암호·터널 토큰·SSH 키는 GitHub에 업로드하지 않습니다.

## 검증 결과 (2026-11-02)

VMware에서 세 VM을 새로 생성하여 설치 완료. WEB 정적 HTML 제공, WEB → WAS → DB 조회 및 글 등록·조회·삭제, AI 차단 검사 통과. 시험 데이터는 삭제했습니다. `python3 verify_crud.py`로 같은 검증을 실행할 수 있습니다.
