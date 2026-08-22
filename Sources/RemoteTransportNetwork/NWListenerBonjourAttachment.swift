@preconcurrency import Network
import RemoteDiscoveryAPI

enum NWListenerBonjourAttachment {
    static func attach(descriptor: RemoteBonjourDescriptor, to listener: NWListener) {
        listener.service = NWListener.Service(
            name: descriptor.name,
            type: descriptor.type,
            domain: nil,
            txtRecord: descriptor.textRecord
        )
    }
}
