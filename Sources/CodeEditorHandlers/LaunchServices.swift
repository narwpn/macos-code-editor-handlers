import AppKit
import Foundation
import UniformTypeIdentifiers

enum AppError: LocalizedError {
    case editorNotInstalled(String)
    case unknownEditor(String)
    case noEditorFound
    case applyFailed(Int)

    var errorDescription: String? {
        switch self {
        case let .editorNotInstalled(name):
            return "Editor '\(name)' was not found in /Applications or ~/Applications."
        case let .unknownEditor(query):
            let available = EditorRegistry.presets.map(\.id).joined(separator: ", ")
            return "Could not find editor '\(query)'. Available presets: \(available) (or specify full .app path)."
        case .noEditorFound:
            return "No known code editors were automatically detected. Please specify an editor or path."
        case let .applyFailed(count):
            return "\(count) file association change(s) failed or could not be verified."
        }
    }
}

struct AppInfo: Sendable, Equatable {
    let name: String
    let bundleId: String?
    let path: String
}

struct HandlerRecord: Sendable {
    let item: AssociationItem
    let currentApp: AppInfo?
    let isTargeted: Bool

    var extensionsFormatted: String {
        item.extensions.map { ".\($0)" }.joined(separator: ", ")
    }
}

enum LaunchServicesClient {
    static func appInfo(for url: URL) -> AppInfo {
        let name = url.deletingPathExtension().lastPathComponent
        let bundleId = Bundle(url: url)?.bundleIdentifier
        return AppInfo(name: name, bundleId: bundleId, path: url.path)
    }

    static func currentHandler(for utType: UTType) -> AppInfo? {
        guard let url = NSWorkspace.shared.urlForApplication(toOpen: utType) else {
            return nil
        }
        return appInfo(for: url)
    }

    static func audit(associations: [AssociationItem], target: ResolvedEditor?) -> [HandlerRecord] {
        return associations.map { item in
            let current = currentHandler(for: item.utType)
            let isTargeted: Bool
            if let target {
                if let curBid = current?.bundleId, let targetBid = target.bundleId {
                    isTargeted = curBid == targetBid
                } else if let current {
                    isTargeted = current.path == target.path
                } else {
                    isTargeted = false
                }
            } else {
                isTargeted = false
            }
            return HandlerRecord(item: item, currentApp: current, isTargeted: isTargeted)
        }
    }

    static func setDefaultApplication(at appURL: URL, for utType: UTType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: utType) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
