import base64
import logging
import os

import cv2
import numpy as np

import auth_db
import draw_landmark

try:
    import pose_estimation
except ModuleNotFoundError:
    pose_estimation = None


logger = logging.getLogger(__name__)
POSE_DEVICE = os.getenv("POSE_DEVICE", "cpu")


class PoseServiceError(Exception):
    pass


class InvalidImageError(PoseServiceError):
    pass


class LandmarkEncodingError(PoseServiceError):
    pass


def process_uploaded_frame(contents: bytes, user_id: str | None, mode: str):
    image = decode_image(contents)
    height, width, _ = image.shape

    keypoints, message = extract_keypoints(image)
    annotated_image = draw_landmark.draw_landmarks(image, keypoints)
    landmark_image = encode_landmark_image(annotated_image)
    result = handle_posture_result(user_id, keypoints, mode)

    return {
        "message": message,
        "width": width,
        "height": height,
        "result": result,
        "landmarkImage": f"data:image/jpeg;base64,{landmark_image}",
    }


def decode_image(contents: bytes):
    np_array = np.frombuffer(contents, np.uint8)
    image = cv2.imdecode(np_array, cv2.IMREAD_COLOR)

    if image is None:
        raise InvalidImageError("Invalid image file")

    return image


def extract_keypoints(image):
    try:
        if pose_estimation is None:
            return np.empty((0, 2)), "Pose model module is not installed"

        return pose_estimation.predict(image, device=POSE_DEVICE), "Landmark image created"
    except IndexError:
        return np.empty((0, 2)), "No pose detected"


def encode_landmark_image(image):
    success, encoded_image = cv2.imencode(".jpg", image)
    if not success:
        raise LandmarkEncodingError("Failed to encode landmark image")

    return base64.b64encode(encoded_image).decode("utf-8")


def handle_posture_result(user_id: str | None, keypoints, mode: str):
    if mode == "calibration":
        record_calibration_sample(user_id, keypoints)
        logger.info("result: 기준 자세 수집 중")
        return "calibrating"

    is_bad_posture = predict_bad_posture(user_id, keypoints)
    logger.info("result: %s", "안 좋은 자세" if is_bad_posture else "좋은 자세")
    record_pose_sample(user_id, is_good=not is_bad_posture)
    return "1" if is_bad_posture else "0"


def record_calibration_sample(user_id: str | None, keypoints) -> None:
    try:
        auth_db.record_calibration_sample(user_id, keypoints)
    except auth_db.DatabaseUnavailableError as error:
        logger.warning("Failed to record calibration sample: %s", error)


def predict_bad_posture(user_id: str | None, keypoints) -> bool:
    try:
        is_bad_posture, _difference = auth_db.predict_bad_posture(user_id, keypoints)
        return is_bad_posture
    except auth_db.DatabaseUnavailableError as error:
        logger.warning("Failed to predict posture from baseline: %s", error)
        return False


def record_pose_sample(user_id: str | None, is_good: bool) -> None:
    try:
        auth_db.record_pose_sample(user_id, is_good=is_good)
    except auth_db.DatabaseUnavailableError as error:
        logger.warning("Failed to record pose sample: %s", error)
