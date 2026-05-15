import AppKit
import Foundation

struct UploadResponse: Decodable {
    let message: String
    let width: Int
    let height: Int
    let result: String?
    let landmarkImage: String
}

struct UploadFrameResult {
    let image: NSImage
    let postureResult: String?
}

struct WeeklyPoseLog: Decodable, Identifiable {
    let id = UUID()
    let day: String
    let totalMinutes: Int
    let goodPostureMinutes: Int

    private enum CodingKeys: String, CodingKey {
        case day
        case totalMinutes
        case goodPostureMinutes
    }
}

struct DashboardSnapshot: Decodable {
    let userName: String
    let previousWeekTotalMinutes: Int
    let logs: [WeeklyPoseLog]
    let lastSessionTotalMinutes: Int
    let lastSessionGoodMinutes: Int

    var totalMinutes: Int {
        logs.reduce(0) { $0 + $1.totalMinutes }
    }

    var totalGoodMinutes: Int {
        logs.reduce(0) { $0 + $1.goodPostureMinutes }
    }

    var goodPostureRate: Int {
        guard totalMinutes > 0 else { return 0 }
        return Int(round(Double(totalGoodMinutes) / Double(totalMinutes) * 100))
    }

    static func sample(userName: String) -> DashboardSnapshot {
        DashboardSnapshot(
            userName: userName,
            previousWeekTotalMinutes: 860,
            logs: [
                WeeklyPoseLog(day: "월", totalMinutes: 126, goodPostureMinutes: 92),
                WeeklyPoseLog(day: "화", totalMinutes: 148, goodPostureMinutes: 111),
                WeeklyPoseLog(day: "수", totalMinutes: 98, goodPostureMinutes: 72),
                WeeklyPoseLog(day: "목", totalMinutes: 165, goodPostureMinutes: 134),
                WeeklyPoseLog(day: "금", totalMinutes: 132, goodPostureMinutes: 93),
                WeeklyPoseLog(day: "토", totalMinutes: 76, goodPostureMinutes: 59),
                WeeklyPoseLog(day: "일", totalMinutes: 104, goodPostureMinutes: 83)
            ],
            lastSessionTotalMinutes: 52,
            lastSessionGoodMinutes: 39
        )
    }
}
