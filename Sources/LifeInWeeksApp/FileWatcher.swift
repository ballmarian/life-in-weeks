import CoreServices
import Foundation

/// Watches one folder — `weeks/`, never a whole vault (PRD §5.3, §6.5).
///
/// Events are coalesced: the app writes into this same folder, so every save it
/// makes bounces straight back. Reloading is cheap and idempotent, so the
/// debounce is about avoiding a burst rather than correctness.
final class FileWatcher {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.mbm.lifeinweeks.fsevents")
    private var pending: DispatchWorkItem?
    private let debounce: TimeInterval
    private let onChange: @Sendable () -> Void

    init(debounce: TimeInterval = 0.3, onChange: @escaping @Sendable () -> Void) {
        self.debounce = debounce
        self.onChange = onChange
    }

    deinit { stop() }

    func start(watching url: URL) {
        stop()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue().scheduleNotify()
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
            )
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        pending?.cancel()
        pending = nil
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func scheduleNotify() {
        pending?.cancel()
        let work = DispatchWorkItem { [onChange] in onChange() }
        pending = work
        queue.asyncAfter(deadline: .now() + debounce, execute: work)
    }
}
