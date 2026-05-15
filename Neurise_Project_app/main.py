import base64
import logging
import os

from typing import Optional

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import numpy as np
import cv2
import auth_db
import draw_landmark

try:
    import pose_estimation
except ModuleNotFoundError:
    pose_estimation = None

logger = logging.getLogger(__name__)
app = FastAPI()
POSE_DEVICE = os.getenv("POSE_DEVICE", "cpu")

# CORS 허용
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class LoginRequest(BaseModel):
    username: str
    password: str


class SignupRequest(BaseModel):
    username: str
    displayName: str
    password: str


class CalibrationRequest(BaseModel):
    userId: str


class ThresholdUpdateRequest(BaseModel):
    userId: str
    thresholdPercent: float


@app.on_event("startup")
async def ensure_seed_data():
    try:
        auth_db.ensure_admin_user()
    except auth_db.DatabaseUnavailableError as error:
        logger.warning("Database is not available during startup: %s", error)


@app.get("/")
async def health_check():
    return {
        "message": "Neurise API is running",
        "client": "macOS Swift app",
        "endpoints": [
            "/api/login",
            "/api/signup",
            "/api/dashboard/{user_id}",
            "/api/pose-baseline/{user_id}",
            "/api/pose-baseline/start",
            "/api/pose-baseline/finish",
            "/api/pose-baseline/reset",
            "/api/pose-threshold/{user_id}",
            "/upload",
        ],
    }


@app.post("/api/signup")
async def signup(payload: SignupRequest):
    try:
        result = auth_db.create_user(
            payload.username.strip(),
            payload.displayName.strip(),
            payload.password,
        )
    except auth_db.DatabaseUnavailableError:
        raise HTTPException(status_code=503, detail="데이터베이스에 연결할 수 없습니다.")

    if not result["ok"]:
        raise HTTPException(
            status_code=result.get("status_code", 400),
            detail=result["error"],
        )

    return {
        "message": "Signup completed",
        "user": result["user"],
    }


@app.post("/api/login")
async def login(payload: LoginRequest):
    try:
        user = auth_db.authenticate_user(payload.username.strip(), payload.password)
    except auth_db.DatabaseUnavailableError:
        raise HTTPException(status_code=503, detail="데이터베이스에 연결할 수 없습니다.")

    if not user:
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다.")

    return {
        "message": "Login completed",
        "user": user,
    }


@app.get("/api/dashboard/{user_id}")
async def dashboard(user_id: str):
    try:
        snapshot = auth_db.get_dashboard(user_id)
    except auth_db.DatabaseUnavailableError:
        raise HTTPException(status_code=503, detail="데이터베이스에 연결할 수 없습니다.")

    if snapshot is None:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    return snapshot


@app.get("/api/pose-baseline/{user_id}")
async def pose_baseline_status(user_id: str):
    try:
        has_baseline = auth_db.has_pose_baseline(user_id)
    except auth_db.DatabaseUnavailableError:
        raise HTTPException(status_code=503, detail="데이터베이스에 연결할 수 없습니다.")

    return {"hasBaseline": has_baseline}


@app.get("/api/pose-threshold/{user_id}")
async def pose_threshold(user_id: str):
    try:
        threshold = auth_db.get_pose_threshold(user_id)
    except auth_db.DatabaseUnavailableError:
        raise HTTPException(status_code=503, detail="데이터베이스에 연결할 수 없습니다.")

    if threshold is None:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    return threshold


@app.post("/api/pose-threshold")
async def update_pose_threshold(payload: ThresholdUpdateRequest):
    try:
        threshold = auth_db.update_pose_threshold(payload.userId, payload.thresholdPercent)
    except auth_db.DatabaseUnavailableError:
        raise HTTPException(status_code=503, detail="데이터베이스에 연결할 수 없습니다.")

    if threshold is None:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    return threshold


@app.post("/api/pose-baseline/reset")
async def reset_pose_baseline(payload: CalibrationRequest):
    try:
        result = auth_db.reset_pose_baseline(payload.userId)
    except auth_db.DatabaseUnavailableError:
        raise HTTPException(status_code=503, detail="데이터베이스에 연결할 수 없습니다.")

    if result is None:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    return result


@app.post("/api/pose-baseline/start")
async def start_pose_baseline(payload: CalibrationRequest):
    try:
        result = auth_db.start_pose_calibration(payload.userId)
    except auth_db.DatabaseUnavailableError:
        raise HTTPException(status_code=503, detail="데이터베이스에 연결할 수 없습니다.")

    if result is None:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    return result


@app.post("/api/pose-baseline/finish")
async def finish_pose_baseline(payload: CalibrationRequest):
    try:
        result = auth_db.finish_pose_calibration(payload.userId)
    except auth_db.DatabaseUnavailableError:
        raise HTTPException(status_code=503, detail="데이터베이스에 연결할 수 없습니다.")

    if result is None:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

    if not result["ok"]:
        raise HTTPException(status_code=400, detail=result["message"])

    return result


@app.post("/upload")
async def upload_image(
    file: UploadFile = File(...),
    user_id: Optional[str] = Form(default=None),
    mode: str = Form(default="monitoring"),
):

    # 이미지 읽기
    contents = await file.read()

    # numpy array 변환
    np_array = np.frombuffer(contents, np.uint8)

    # OpenCV 이미지 디코딩
    image = cv2.imdecode(np_array, cv2.IMREAD_COLOR)

    if image is None:
        raise HTTPException(status_code=400, detail="Invalid image file")

    # 이미지 크기 출력
    height, width, _ = image.shape

    # print(f"Received image: {width}x{height}")

    try:
        if pose_estimation is None:
            keypoints = np.empty((0, 2))
            message = "Pose model module is not installed"
        else:
            keypoints = pose_estimation.predict(image, device=POSE_DEVICE)
            message = "Landmark image created"
    except IndexError:
        keypoints = np.empty((0, 2))
        message = "No pose detected"

    annotated_image = draw_landmark.draw_landmarks(image, keypoints)

    success, encoded_image = cv2.imencode(".jpg", annotated_image)

    if mode == "calibration":
        try:
            auth_db.record_calibration_sample(user_id, keypoints)
        except auth_db.DatabaseUnavailableError as error:
            logger.warning("Failed to record calibration sample: %s", error)
        result = "calibrating"
        is_bad_posture = False
    else:
        try:
            is_bad_posture, difference = auth_db.predict_bad_posture(user_id, keypoints)
        except auth_db.DatabaseUnavailableError as error:
            logger.warning("Failed to predict posture from baseline: %s", error)
            is_bad_posture = False
            difference = None
        result = "1" if is_bad_posture else "0"

    if is_bad_posture:
        print("result: 안 좋은 자세")
    else:
        print("result: 좋은 자세" if result != "calibrating" else "result: 기준 자세 수집 중")

    if mode != "calibration":
        try:
            auth_db.record_pose_sample(user_id, is_good=not is_bad_posture)
        except auth_db.DatabaseUnavailableError as error:
            logger.warning("Failed to record pose sample: %s", error)

    if not success:
        raise HTTPException(status_code=500, detail="Failed to encode landmark image")

    landmark_image = base64.b64encode(encoded_image).decode("utf-8")

    # print(keypoints)
    print("-------------------------")

    return {
        "message": message,
        "width": width,
        "height": height,
        "result": result,
        "landmarkImage": f"data:image/jpeg;base64,{landmark_image}",
    }
