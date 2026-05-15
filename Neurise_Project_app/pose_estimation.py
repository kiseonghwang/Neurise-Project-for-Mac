from ultralytics import YOLO

# 모델 로드
model = YOLO("yolo26n-pose.pt")

# 추론
def predict(source, device:str="mps"):
    result = model.predict(source=source, device=device)
    keypoints = result[0].keypoints.data.cpu().numpy()
    return keypoints[0, :10, :2]

if __name__ == "__main__":
    results_img = predict(source="test.png")
    print(type(results_img))
    print(results_img.shape)

# 결과 예시:
# [[     909.83      817.82]
#  [     1060.7      681.54]
#  [     761.75      666.72]
#  [     1237.3      786.74]
#  [     563.24      757.74]
#  [     1554.6      1484.3]
#  [     236.65      1556.2]
#  [     1770.2      1839.9]
#  [     113.71        1840]
#  [     1576.7        1533]]
# (10, 2)