# Vagrant Flask board source

기존 Flask 게시판과 추가 분류 게시판의 소스입니다. Vagrant 웹 설치 스크립트가 이 저장소를 git clone하여 VM에 배포합니다.

- apps/board: Flask 게시판과 AI 필터링 모델 학습 코드
- apps/spam: 추가 카테고리 분류 앱과 모델 학습 코드
- requirements.txt: Python 패키지

DB 연결은 VM에서 생성하는 .env의 DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_DATABASE를 사용합니다. DB 비밀번호, Cloudflare 토큰, SSH 키, 실제 게시글 데이터는 포함하지 않습니다. 모델은 설치 시 학습 코드로 생성합니다.
