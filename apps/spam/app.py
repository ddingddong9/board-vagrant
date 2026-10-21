import os
import joblib
import pymysql
from dotenv import load_dotenv
from flask import Flask, render_template, request, jsonify

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

app = Flask(__name__)
app.json.ensure_ascii = False

MODEL_PATH = os.path.join(
    os.path.dirname(__file__), "assignment_ai_model.pkl"
)

# 기존 board 앱과 동일한 MariaDB 연결 설정
DB_CONFIG = {
   "host": os.environ.get("DB_HOST"),       # MariaDB 서버 IP (우분투 IP)
   "port": int(os.environ.get("DB_PORT",3306)),              # MariaDB 포트
   "user": os.environ.get("DB_USER"),            # 접속 계정
   "password": os.environ.get("DB_PASSWORD"),         # 설정하신 비밀번호
   "database": os.environ.get("DB_DATABASE"),       # 사용할 데이터베이스 명
   "charset": "utf8mb4",
   "cursorclass": pymysql.cursors.DictCursor  # 결과를 딕셔너리 형태로 받아오기 설정
}


def get_db_connection():
    return pymysql.connect(**DB_CONFIG)


def init_db():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS assignment_posts (
                    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
                    title TEXT NOT NULL,
                    content TEXT NOT NULL,
                    category VARCHAR(20) NOT NULL
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
            """)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# AI 모델 로드
if os.path.exists(MODEL_PATH):
    ai_model = joblib.load(MODEL_PATH)
else:
    ai_model = None


@app.route("/")
def index():
    return render_template("index.html")


# [READ] 게시글 목록 조회
@app.route("/api/posts", methods=["GET"])
def get_posts():
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT id, title, content, category
                FROM assignment_posts
                ORDER BY id DESC
            """)
            posts = cursor.fetchall()

        return jsonify(posts)
    except pymysql.MySQLError:
        app.logger.exception("게시글 조회 실패")
        return jsonify({
            "success": False,
            "message": "DB 조회 중 오류가 발생했습니다."
        }), 500
    finally:
        if conn is not None:
            conn.close()


# [CREATE] 게시글 등록 및 AI 검증
@app.route("/api/posts", methods=["POST"])
def create_post():
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify({
            "success": False,
            "message": "올바른 JSON 데이터를 보내 주세요."
        }), 400

    title = data.get("title", "")
    content = data.get("content", "")

    if not isinstance(title, str) or not isinstance(content, str):
        return jsonify({
            "success": False,
            "message": "제목과 내용은 문자열이어야 합니다."
        }), 400

    title = title.strip()
    content = content.strip()

    if not title or not content:
        return jsonify({
            "success": False,
            "message": "제목과 내용을 입력해 주세요."
        }), 400

    if ai_model is None:
        return jsonify({
            "success": False,
            "message": "AI 모델이 학습되지 않았습니다."
        }), 503

    try:
        # 0: Q&A, 1: Review, 2: Spam
        prediction = int(ai_model.predict([content])[0])
    except Exception:
        app.logger.exception("AI 추론 실패")
        return jsonify({
            "success": False,
            "message": "AI 분석 중 오류가 발생했습니다."
        }), 500

    if prediction == 2:
        return jsonify({
            "success": False,
            "message": "🚨 스팸 광고 글로 감지되었습니다. 게시글을 등록할 수 없습니다!"
        }), 200

    categories = {0: "Q&A", 1: "Review"}
    computed_category = categories.get(prediction)

    if computed_category is None:
        return jsonify({
            "success": False,
            "message": "AI가 알 수 없는 분류 결과를 반환했습니다."
        }), 500

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO assignment_posts (title, content, category)
                VALUES (%s, %s, %s)
                """,
                (title, content, computed_category)
            )
        conn.commit()

        return jsonify({
            "success": True,
            "message": (
                f"🎉 [{computed_category}] 카테고리로 "
                "게시글이 성공적으로 등록되었습니다."
            )
        })
    except pymysql.MySQLError:
        if conn is not None:
            conn.rollback()
        app.logger.exception("게시글 저장 실패")
        return jsonify({
            "success": False,
            "message": "DB 저장 중 오류가 발생했습니다."
        }), 500
    finally:
        if conn is not None:
            conn.close()


# [DELETE] 게시글 삭제
@app.route("/api/posts/<int:post_id>", methods=["DELETE"])
def delete_post(post_id):
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute(
                "DELETE FROM assignment_posts WHERE id = %s",
                (post_id,)
            )
            deleted_count = cursor.rowcount
        conn.commit()

        if deleted_count == 0:
            return jsonify({
                "success": False,
                "message": "게시글을 찾을 수 없습니다."
            }), 404

        return jsonify({
            "success": True,
            "message": "게시글이 삭제되었습니다."
        })
    except pymysql.MySQLError:
        if conn is not None:
            conn.rollback()
        app.logger.exception("게시글 삭제 실패")
        return jsonify({
            "success": False,
            "message": "DB 삭제 중 오류가 발생했습니다."
        }), 500
    finally:
        if conn is not None:
            conn.close()


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5001, debug=False)