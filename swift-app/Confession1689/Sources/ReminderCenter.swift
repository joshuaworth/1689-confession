import Foundation
import UserNotifications

/// Daily reading reminder: a local notification naming the day's exact paragraph.
/// Schedules the next 30 days concretely (each day's label precomputed) and
/// reschedules on every app open. Nothing leaves the device.
enum ReminderCenter {
    static func setEnabled(_ enabled: Bool, hour: Int, minute: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard enabled else { return true }

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        await schedule(hour: hour, minute: minute)
        return true
    }

    static func reschedule(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        await schedule(hour: hour, minute: minute)
    }

    private static func schedule(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        let library = Library.shared
        let calendar = Calendar.current
        let now = Date()

        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = hour
            comps.minute = minute
            guard let fireDate = calendar.date(from: comps), fireDate > now else { continue }

            let id = library.todayParagraphID(date: day)
            guard let found = library.paragraph(for: id) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Today's Reading"
            content.body = "Chapter \(found.chapter.roman) · ¶ \(found.paragraph.number) · \(found.chapter.title)"
            content.sound = nil
            content.userInfo = ["destination": "today"]

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false)
            let request = UNNotificationRequest(identifier: "reading-\(comps.year!)-\(comps.month!)-\(comps.day!)",
                                                content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
