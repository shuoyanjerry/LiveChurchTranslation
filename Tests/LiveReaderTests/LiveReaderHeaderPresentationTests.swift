import Testing
@testable import LiveReader

@Suite struct LiveReaderHeaderPresentationTests {
    @Test func microphoneControlUsesResponsiveLabel() {
        let deviceName = "MacBook Pro 麦克风"

        #expect(
            MicrophoneControlPresentation.title(
                selectedInputName: deviceName,
                expanded: false
            ) == "麦克风设置"
        )
        #expect(
            MicrophoneControlPresentation.title(
                selectedInputName: deviceName,
                expanded: true
            ) == deviceName
        )
    }
}
