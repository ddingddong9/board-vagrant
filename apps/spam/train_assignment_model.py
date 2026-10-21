import joblib
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import make_pipeline
import os

# [학생 과제 1] 아래 학습 데이터셋(X, y)에 데이터셋을 최소 5개 이상 더 추가해 보세요.
# 레이블 정의 -> 0: 일반 문의(Q&A), 1: 칭찬/리뷰(Review), 2: 광고/스팸(Spam)
train_data = [
    # 0: 일반 문의
    ("배송은 언제쯤 오나요?", 0),
    ("사이즈 변경하고 싶은데 가능한가요?", 0),
    ("환불 절차가 어떻게 되나요?", 0),
    
    # 1: 칭찬 / 리뷰
    ("제품 너무 마음에 들어요 강력 추천합니다", 1),
    ("배송도 빠르고 품질도 아주 좋습니다", 1),
    ("생각했던 것보다 훨씬 예쁘네요 최고", 1),
    
    # 2: 광고 / 스팸
    ("지금 바로 가입하고 대박 지원금 받아가세요", 2),
    ("클릭 한 번으로 고수익 보장 재테크 정보", 2),
    ("성인 전용 고화질 영상 무료 시청 링크", 2)
    
    # TODO:여기에 자신만의 테스트 데이터를 추가하여 AI를 고도화하세요.
]

X_train = [text for text, label in train_data]
y_train = [label for text, label in train_data]

# 파이프라인 구축 (TF-IDF 벡터라이저 + 나이브 베이즈)
model = make_pipeline(
    TfidfVectorizer(),
    MultinomialNB()
)

print("=== 학생 과제용 AI 모델 학습을 시작합니다 ===")
model.fit(X_train, y_train)

# 모델 파일 저장
model_name = os.path.join(os.path.dirname(__file__), "assignment_ai_model.pkl")
joblib.dump(model, model_name)
print(f"모델 저장 완료! 파일명: {model_name}")
