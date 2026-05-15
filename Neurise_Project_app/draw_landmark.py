import cv2
import numpy as np


SKELETON = [
    (0, 1),
    (0, 2),
    (1, 3),
    (2, 4),
    (5, 6),
    (5, 7),
    (6, 8),
]


def draw_landmarks(image, keypoints):
    annotated_image = image.copy()
    points = np.asarray(keypoints, dtype=float)

    if points.size == 0:
        cv2.putText(
            annotated_image,
            "No pose landmarks",
            (24, 42),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.9,
            (0, 255, 255),
            2,
            cv2.LINE_AA,
        )
        return annotated_image

    points = np.squeeze(points)
    if points.ndim != 2 or points.shape[1] < 2:
        return annotated_image

    points = points[:, :2]
    height, width = annotated_image.shape[:2]

    if np.nanmax(np.abs(points)) <= 2:
        points = points.copy()
        points[:, 0] *= width
        points[:, 1] *= height

    drawable_points = []
    for x_value, y_value in points:
        if not np.isfinite(x_value) or not np.isfinite(y_value):
            drawable_points.append(None)
            continue

        x = int(round(x_value))
        y = int(round(y_value))
        if x < 0 or y < 0 or x >= width or y >= height:
            drawable_points.append(None)
            continue

        drawable_points.append((x, y))

    for start_index, end_index in SKELETON:
        if start_index >= len(drawable_points) or end_index >= len(drawable_points):
            continue

        start_point = drawable_points[start_index]
        end_point = drawable_points[end_index]
        if start_point is None or end_point is None:
            continue

        cv2.line(annotated_image, start_point, end_point, (0, 255, 0), 3, cv2.LINE_AA)

    for point in drawable_points:
        if point is None:
            continue

        cv2.circle(annotated_image, point, 6, (0, 0, 255), -1, cv2.LINE_AA)
        cv2.circle(annotated_image, point, 8, (255, 255, 255), 2, cv2.LINE_AA)

    return annotated_image
