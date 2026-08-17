import Foundation
import Synchronization

private let hiddenEventsFilePath = "temp/hidden-events.json"

/// Hidden events as they are kept on the disk: the ids together with the day
/// they were hidden on, so they can be dropped as soon as the day changes.
private struct StoredHiddenEvents: Codable, Sendable {
    var day: String
    var eventIds: Set<String>

    static let empty = StoredHiddenEvents(day: "", eventIds: [])
}

/// Ids of the events the user hid, persisted for the current day only.
///
/// Hiding an event is meant to last until the end of the day, so the ids are
/// stored together with that day and are thrown away the first time the store is
/// asked about another one. That makes the day rollover free: nothing has to
/// remember to clean the file up, neither at midnight nor at the next start up.
///
/// The in-memory state is the one the app reads and it is updated synchronously,
/// so a hidden event never comes back because a reload raced a keystroke. The
/// file is written on a private serial queue, which keeps the render loop away
/// from the disk and still guarantees that the last requested state is the one
/// that ends up in the file.
final class HiddenEventsStore: Sendable {
    private let fileURL: URL
    private let state: Mutex<StoredHiddenEvents>
    private let writeQueue = DispatchQueue(label: "calendar-clock.hidden-events", qos: .utility)

    init(fileURL: URL = URL.currentDirectory().appendingPathComponent(hiddenEventsFilePath)) {
        self.fileURL = fileURL
        self.state = Mutex(Self.restore(from: fileURL))
    }

    /// Ids hidden on `day`. Ids stored for any other day are discarded.
    func eventIds(on day: Date) -> Set<String> {
        let dayKey = Self.dayKey(for: day)

        let (eventIds, expired) = state.withLock { stored -> (Set<String>, Bool) in
            guard stored.day == dayKey else {
                let hadEventIds = !stored.eventIds.isEmpty
                stored = StoredHiddenEvents(day: dayKey, eventIds: [])
                return ([], hadEventIds)
            }
            return (stored.eventIds, false)
        }

        // the stored ids belonged to another day, drop them from the file as well
        if expired {
            scheduleWrite(StoredHiddenEvents(day: dayKey, eventIds: []))
        }

        return eventIds
    }

    /// Hides or shows a single event and returns the complete set of ids hidden
    /// on `day` afterwards, so the caller can mirror it into the app state.
    @discardableResult
    func setHidden(_ isHidden: Bool, eventId: String, on day: Date) -> Set<String> {
        let dayKey = Self.dayKey(for: day)

        let updated = state.withLock { stored -> StoredHiddenEvents in
            if stored.day != dayKey {
                stored = StoredHiddenEvents(day: dayKey, eventIds: [])
            }
            if isHidden {
                stored.eventIds.insert(eventId)
            } else {
                stored.eventIds.remove(eventId)
            }
            return stored
        }

        scheduleWrite(updated)

        return updated.eventIds
    }

    /// Waits for the pending writes to reach the disk.
    func flush() {
        writeQueue.sync {}
    }

    private func scheduleWrite(_ stored: StoredHiddenEvents) {
        let fileURL = self.fileURL

        writeQueue.async {
            do {
                let data = try JSONEncoder().encode(stored)
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                )
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("Can't store hidden events at \(fileURL.path): \(error)")
            }
        }
    }

    private static func restore(from fileURL: URL) -> StoredHiddenEvents {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(StoredHiddenEvents.self, from: data)
        } catch {
            print("Can't read hidden events at \(fileURL.path): \(error)")
            return .empty
        }
    }

    /// `yyyy-MM-dd` in the current calendar. Built from date components instead
    /// of a `DateFormatter` to keep the store free of shared mutable state.
    private static func dayKey(for day: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
        )
    }
}
