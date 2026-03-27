import Foundation

/// Shorthand for NSLocalizedString
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Shorthand with format arguments
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}
