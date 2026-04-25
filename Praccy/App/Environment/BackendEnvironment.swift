import SwiftUI

/// Environment keys injected at the scene root. `MockBackend` default keeps isolated previews running.
private struct PraccyBackendKey: EnvironmentKey {
    static let defaultValue: any PraccyBackend = MockBackend()
}

private struct PraccyBackendQueueKey: EnvironmentKey {
    static let defaultValue: BackendOperationQueue? = nil
}

extension EnvironmentValues {
    var backend: any PraccyBackend {
        get { self[PraccyBackendKey.self] }
        set { self[PraccyBackendKey.self] = newValue }
    }

    /// `nil` in previews that don't exercise the offline path; callers should no-op when missing.
    var backendQueue: BackendOperationQueue? {
        get { self[PraccyBackendQueueKey.self] }
        set { self[PraccyBackendQueueKey.self] = newValue }
    }
}
