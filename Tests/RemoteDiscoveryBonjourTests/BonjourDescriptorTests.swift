import RemoteDiscoveryBonjour
import Testing

@Suite("Bonjour descriptor")
struct BonjourDescriptorTests {
    @Test("Discovery reveals no session content or credential")
    func safeMetadata() {
        let descriptor = BonjourServiceDescriptor(name: String(repeating: "A", count: 100))
        let text = String(bytes: descriptor.textRecord, encoding: .utf8) ?? ""
        #expect(BonjourServiceDescriptor.serviceType == "_churchtranslate._tcp")
        #expect(descriptor.name.count == 63)
        #expect(text.contains("pairing=required"))
        #expect(!text.lowercased().contains("token"))
        #expect(!text.lowercased().contains("transcript"))
        #expect(descriptor.descriptor().type == "_churchtranslate._tcp")
    }
}
