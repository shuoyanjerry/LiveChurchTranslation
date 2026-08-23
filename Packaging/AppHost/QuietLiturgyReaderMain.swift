import ChurchTranslatorApp

@main
enum QuietLiturgyReaderMain {
    @MainActor
    static func main() {
        LiveChurchTranslationApp.main()
    }
}
