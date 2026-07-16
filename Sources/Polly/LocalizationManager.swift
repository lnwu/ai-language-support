import Foundation

final class LocalizationManager: Sendable {
  static let shared = LocalizationManager()

  fileprivate let bundle: Bundle

  private init() {
    let systemLanguage = Locale.preferredLanguages.first ?? "en"

    let language: String
    if systemLanguage.hasPrefix("zh") {
      language = "zh-Hans"
    } else {
      language = "en"
    }

    if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
     let resolved = Bundle(path: path) {
      self.bundle = resolved
    } else {
      self.bundle = .main
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
    let format = LocalizationManager.shared.bundle.localizedString(forKey: self, value: nil, table: nil)
    if args.isEmpty {
      return format
    }
    return String(format: format, arguments: args)
  }
}
