"""새 3티어 실습 환경에서 HTTP 등록/조회/삭제 및 AI 차단을 검증합니다."""
import json
import time
import urllib.request

BASE = 'http://127.0.0.1:35000'

def api(path, method='GET', payload=None):
    body = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(BASE + path, data=body, method=method,
                                     headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.load(response)

with urllib.request.urlopen(BASE + '/', timeout=15) as response:
    assert response.headers['X-Served-By'] == 'three-tier-web'
    assert b'/api/posts' in response.read()
rows = api('/api/posts')
assert isinstance(rows, list)
title = 'three-tier-check-' + str(time.time_ns())
created_id = None
try:
    result = api('/api/posts', 'POST', {'title': title, 'content': '오늘 날씨가 정말 좋네요'})
    assert result['success'], result
    match = [row for row in api('/api/posts') if row['title'] == title]
    assert len(match) == 1
    created_id = match[0]['id']
    blocked = api('/api/posts', 'POST', {'title': title + '-blocked', 'content': '진짜 최악이다 쓰레기 같아'})
    assert blocked['success'] is False
    assert not any(row['title'] == title + '-blocked' for row in api('/api/posts'))
finally:
    if created_id is not None:
        assert api('/api/posts/' + str(created_id), 'DELETE')['success']
assert not any(row['title'] == title for row in api('/api/posts'))
print('PASS: WEB static HTML → WAS API → MariaDB create/read/delete; AI block; test row cleaned')
