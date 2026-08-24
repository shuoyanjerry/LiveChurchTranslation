import Foundation
import SettingsAPI
import Testing

@Suite struct AppSettingsBoundsTests {
    @Test func clampsReaderFontSizeAtConstructionAndDecoding() throws {
        #expect(AppSettings(readerFontSize: 200).readerFontSize == 44)
        #expect(AppSettings(readerFontSize: 2).readerFontSize == 18)
        #expect(AppSettings(readerFontSize: .nan).readerFontSize == 28)

        let oversized = Data(#"{"readerFontSize":1000}"#.utf8)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: oversized)
        #expect(decoded.readerFontSize == 44)
    }
}
