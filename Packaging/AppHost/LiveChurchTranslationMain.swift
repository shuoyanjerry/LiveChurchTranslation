import ChurchTranslatorApp
import Darwin

@main
enum LiveChurchTranslationMain {
    @MainActor
    static func main() {
        if Array(CommandLine.arguments.dropFirst()) == ["--verify-installation"] {
            exit(InstallationProbe.run() ? EXIT_SUCCESS : EXIT_FAILURE)
        }
        LiveChurchTranslationApp.main()
    }
}
