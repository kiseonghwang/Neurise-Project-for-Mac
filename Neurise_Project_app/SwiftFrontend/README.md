# Neurise Swift Frontend

기존 FastAPI 백엔드와 PostgreSQL DB는 그대로 두고, HTML/CSS/JS 프론트엔드를 SwiftUI iOS 앱으로 대응시킨 코드입니다.

## 포함된 화면

- 로그인: `/api/login`
- 회원가입: `/api/signup`
- 실시간 자세 측정: `/upload`
- 대시보드: 현재 웹 대시보드와 같은 샘플 데이터를 SwiftUI로 표시
- 설정: 서버 주소 변경, 로그아웃

## Xcode에서 사용하는 방법

1. Xcode에서 `File > New > Project > iOS > App`을 선택합니다.
2. Product Name을 `NeuriseSwiftApp`으로 만듭니다.
3. Interface는 `SwiftUI`, Language는 `Swift`로 선택합니다.
4. 생성된 기본 Swift 파일을 제거하거나 덮어씁니다.
5. `SwiftFrontend/NeuriseSwiftApp` 폴더 안의 Swift 파일들을 Xcode 프로젝트에 추가합니다.
6. `Info.plist`에 카메라 권한 문구를 추가합니다.

```xml
<key>NSCameraUsageDescription</key>
<string>자세 추정을 위해 카메라 프레임을 사용합니다.</string>
```

## HTTP 서버 사용 시 ATS 설정

로컬 FastAPI 서버가 `http://`라면 iOS에서 차단될 수 있습니다. 개발 중에는 `Info.plist`에 아래 설정을 추가할 수 있습니다.

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

실제 배포에서는 HTTPS를 사용하는 것이 좋습니다.

## 서버 주소

기본 서버 주소는 아래와 같습니다.

```swift
http://127.0.0.1:8000
```

- iOS 시뮬레이터: `http://127.0.0.1:8000` 또는 `http://localhost:8000`
- 실제 iPhone: Mac의 로컬 IP 사용, 예: `http://192.168.0.12:8000`

앱 안의 `설정` 탭에서 서버 주소를 바꿀 수 있습니다.

## 백엔드 실행 예시

```bash
docker compose up -d db
DATABASE_URL=postgresql://neurise:neurise_password@localhost:5433/neurise uvicorn main:app --reload
```

`docker-compose.yml`에서 DB 포트를 `5432:5432`로 사용 중이면 `DATABASE_URL`의 포트도 `5432`로 맞추세요.

## 참고

Swift 앱의 대시보드는 현재 `DashboardSnapshot.sample(...)` mock 데이터를 사용합니다. 실제 DB 대시보드 API를 완성하면 `DashboardView`에서 API 호출로 교체하면 됩니다.
