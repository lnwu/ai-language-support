import Foundation

final class LocalizationManager {
    static let shared = LocalizationManager()

    private var bundle: Bundle = .main

    private init() {
        setupLanguage()
    }

    private func setupLanguage() {
        let systemLanguage = Locale.preferredLanguages.first ?? "en"

        let language: String
        if systemLanguage.hasPrefix("zh") {
            language = "zh-Hans"
        } else {
            language = "en"
        }

        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        }
    }

    func localized(_ key: String, _ args: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        if args.isEmpty {
            return format
        }
        return String(format: format, arguments: args)
    }
}

extension String {
    var localized: String {
        LocalizationManager.shared.localized(self)
    }

    func localized(_ args: CVarArg...) -> String {
        LocalizationManager.shared.localized(self, arguments: args)
    }
}
