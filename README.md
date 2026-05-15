# Neurise Project for Mac

Neurise Project for Mac is a macOS SwiftUI app with a FastAPI backend for real-time posture monitoring. The app captures camera frames, sends them to the backend, draws pose landmarks, compares the current pose against a user-specific baseline, and records posture data in PostgreSQL for dashboard reporting.

## Features

- macOS SwiftUI app
- FastAPI backend
- PostgreSQL database via Docker Compose
- YOLO pose point extraction
- User signup and login
- User-specific good posture calibration
- Adjustable posture threshold in Settings
- Real-time landmark preview
- Global macOS warning overlay when bad posture is sustained
- Dashboard based on stored user posture records

## Project Structure

```text
.
├── Neurise_Project_app.xcodeproj
├── Neurise_Project_app
│   ├── SwiftFrontend/NeuriseSwiftApp
│   │   ├── Models
│   │   ├── Services
│   │   └── Views
│   ├── main.py
│   ├── auth_db.py
│   ├── pose_service.py
│   ├── draw_landmark.py
│   ├── pose_estimation.py
│   ├── yolo26n-pose.pt
│   └── requirements.txt
├── docker-compose.yml
├── environment.yml
└── .gitignore
```

## Requirements

- macOS
- Xcode
- Anaconda or Miniconda
- Docker Desktop
- Git

## Backend Setup

Create or update the conda environment:

```bash
cd /Users/hwang-giseong/Documents/Neurise_Project_app
conda env update -f environment.yml
conda activate NeuriseProject
```

Start PostgreSQL:

```bash
docker compose up -d db
```

Run the FastAPI backend:

```bash
cd /Users/hwang-giseong/Documents/Neurise_Project_app/Neurise_Project_app
conda activate NeuriseProject
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

Check that the backend is running:

```bash
curl http://127.0.0.1:8000
```

## macOS App Setup

1. Open `Neurise_Project_app.xcodeproj` in Xcode.
2. Select the `Neurise_Project_app` scheme.
3. Select `My Mac` as the run target.
4. Run the app with `Cmd + R`.
5. In the app Settings tab, keep the server URL as:

```text
http://127.0.0.1:8000
```

## How Posture Calibration Works

For each user, the app first checks whether a good-posture baseline exists.

If no baseline exists:

1. The app asks the user to maintain a good posture.
2. It collects pose points for about 10 seconds.
3. The backend averages those pose points.
4. The averaged pose is saved as that user's baseline.

During monitoring, the backend compares the current pose points with the saved baseline. If the average difference exceeds the user's threshold, the posture is marked as bad.

The default threshold is `10%`. Users can change it in the app Settings tab.

## Warning Overlay

When bad posture continues for the configured duration in the Swift app, a macOS overlay warning appears above other apps. This lets the user see the warning even while coding in an IDE or using another foreground app.

## Database

PostgreSQL runs through Docker Compose.

Default connection:

```text
postgresql://neurise:neurise_password@localhost:5433/neurise
```

Main data stored:

- Users
- Pose baseline per user
- Temporary calibration samples
- Pose samples for dashboard statistics

## GitHub Notes

Files intentionally ignored:

- `.venv/`: local Python virtual environment
- `__pycache__/`: Python cache files
- `.DS_Store`: macOS Finder metadata
- `.idea/`: local PyCharm settings
- `xcuserdata/`: local Xcode user settings
- legacy KNN artifacts no longer used by the current baseline-based model

## Common Commands

Start database:

```bash
docker compose up -d db
```

Stop database:

```bash
docker compose down
```

Run backend:

```bash
cd Neurise_Project_app
conda activate NeuriseProject
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

Push changes:

```bash
git add .
git commit -m "Update project"
git push
```
