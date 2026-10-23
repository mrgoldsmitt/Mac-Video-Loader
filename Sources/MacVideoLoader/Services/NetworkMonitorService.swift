import Foundation
import Network

public final class NetworkMonitorService: @unchecked Sendable {
    public static let shared = NetworkMonitorService()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.macvideoloader.networkmonitor")
    private var wasConnected: Bool = true
    private let lock = NSLock()

    public var onNetworkRestored: (@Sendable () -> Void)?
    public var onNetworkLost: (@Sendable () -> Void)?

    private init() {}

    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.lock.lock()
            let isConnected = (path.status == .satisfied)
            let previous = self.wasConnected
            self.wasConnected = isConnected
            self.lock.unlock()

            if !previous && isConnected {
                self.onNetworkRestored?()
            } else if previous && !isConnected {
                self.onNetworkLost?()
            }
        }
        monitor.start(queue: queue)
    }

    public func stopMonitoring() {
        monitor.cancel()
    }
}
