import Foundation
import Combine
import Network

protocol NetworkMonitorProtocol {
    var isOnline: Bool { get }
    var isOnlinePublisher: AnyPublisher<Bool, Never> { get }
}

class NetworkMonitor: NetworkMonitorProtocol {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    private let subject = CurrentValueSubject<Bool, Never>(true)
    
    var isOnlinePublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }
    var isOnline: Bool { subject.value }
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.subject.send(path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

class MockNetworkMonitor: NetworkMonitorProtocol {
    private let subject = CurrentValueSubject<Bool, Never>(true)
    
    var isOnlinePublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }
    var isOnline: Bool { subject.value }
    
    func setOnline(_ online: Bool) { subject.send(online) }
}

