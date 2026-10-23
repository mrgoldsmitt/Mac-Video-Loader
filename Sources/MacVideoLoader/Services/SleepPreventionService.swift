import Foundation
import IOKit.pwr_mgt

public final class SleepPreventionService: @unchecked Sendable {
    public static let shared = SleepPreventionService()

    private var assertionID: IOPMAssertionID = 0
    private var isPreventingSleep: Bool = false
    private let lock = NSLock()

    private init() {}

    public func enableSleepPrevention(reason: String = "Mac Video Loader lade Videos herunter") {
        lock.lock()
        defer { lock.unlock() }

        guard !isPreventingSleep else { return }

        let success = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )

        if success == kIOReturnSuccess {
            isPreventingSleep = true
        }
    }

    public func disableSleepPrevention() {
        lock.lock()
        defer { lock.unlock() }

        guard isPreventingSleep else { return }

        let success = IOPMAssertionRelease(assertionID)
        if success == kIOReturnSuccess {
            isPreventingSleep = false
            assertionID = 0
        }
    }
}
