import AppKit
import Foundation

struct EditorPreset: Sendable {
    let id: String
    let displayName: String
    let bundleId: String?
    let candidatePaths: [String]
}

struct ResolvedEditor: Sendable, Equatable {
    let id: String
    let displayName: String
    let bundleId: String?
    let url: URL

    var path: String { url.path }
}

enum EditorRegistry {
    static let presets: [EditorPreset] = [
        EditorPreset(
            id: "antigravity",
            displayName: "Antigravity IDE",
            bundleId: "com.google.antigravity",
            candidatePaths: [
                "/Applications/Antigravity.app",
                "/Applications/Antigravity IDE.app",
                "~/Applications/Antigravity.app",
                "~/Applications/Antigravity IDE.app"
            ]
        ),
        EditorPreset(
            id: "vscode",
            displayName: "Visual Studio Code",
            bundleId: "com.microsoft.VSCode",
            candidatePaths: [
                "/Applications/Visual Studio Code.app",
                "~/Applications/Visual Studio Code.app"
            ]
        ),
        EditorPreset(
            id: "cursor",
            displayName: "Cursor",
            bundleId: "com.todesktop.230313mzl4w4u92",
            candidatePaths: [
                "/Applications/Cursor.app",
                "~/Applications/Cursor.app"
            ]
        ),
        EditorPreset(
            id: "zed",
            displayName: "Zed",
            bundleId: "dev.zed.Zed",
            candidatePaths: [
                "/Applications/Zed.app",
                "~/Applications/Zed.app"
            ]
        ),
        EditorPreset(
            id: "windsurf",
            displayName: "Windsurf",
            bundleId: "com.exafunction.windsurf",
            candidatePaths: [
                "/Applications/Windsurf.app",
                "~/Applications/Windsurf.app"
            ]
        ),
        EditorPreset(
            id: "sublime",
            displayName: "Sublime Text",
            bundleId: "com.sublimetext.4",
            candidatePaths: [
                "/Applications/Sublime Text.app",
                "~/Applications/Sublime Text.app"
            ]
        )
    ]

    static func detectInstalledEditors() -> [ResolvedEditor] {
        var found: [ResolvedEditor] = []
        var seenPaths = Set<String>()

        for preset in presets {
            for rawPath in preset.candidatePaths {
                let expanded = NSString(string: rawPath).expandingTildeInPath
                if FileManager.default.fileExists(atPath: expanded) && !seenPaths.contains(expanded) {
                    seenPaths.insert(expanded)
                    let url = URL(fileURLWithPath: expanded)
                    let bundleId = Bundle(url: url)?.bundleIdentifier ?? preset.bundleId
                    found.append(ResolvedEditor(
                        id: preset.id,
                        displayName: preset.displayName,
                        bundleId: bundleId,
                        url: url
                    ))
                    break
                }
            }
        }
        return found
    }

    static func resolve(query: String) throws -> ResolvedEditor {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. Check presets by alias / id
        let aliasMap: [String: String] = [
            "code": "vscode",
            "vs-code": "vscode",
            "visualstudiocode": "vscode",
            "ag": "antigravity"
        ]
        let targetId = aliasMap[clean] ?? clean

        if let preset = presets.first(where: { $0.id == targetId }) {
            for rawPath in preset.candidatePaths {
                let expanded = NSString(string: rawPath).expandingTildeInPath
                if FileManager.default.fileExists(atPath: expanded) {
                    let url = URL(fileURLWithPath: expanded)
                    let bundleId = Bundle(url: url)?.bundleIdentifier ?? preset.bundleId
                    return ResolvedEditor(
                        id: preset.id,
                        displayName: preset.displayName,
                        bundleId: bundleId,
                        url: url
                    )
                }
            }
            if let bundleId = preset.bundleId,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                return ResolvedEditor(
                    id: preset.id,
                    displayName: preset.displayName,
                    bundleId: bundleId,
                    url: url
                )
            }
            throw AppError.editorNotInstalled(preset.displayName)
        }

        // 2. Direct path provided
        let expandedQuery = NSString(string: query).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expandedQuery) {
            let url = URL(fileURLWithPath: expandedQuery)
            let name = url.deletingPathExtension().lastPathComponent
            let bundleId = Bundle(url: url)?.bundleIdentifier
            return ResolvedEditor(
                id: name.lowercased(),
                displayName: name,
                bundleId: bundleId,
                url: url
            )
        }

        // 3. Search /Applications/<Query>.app
        let appName = query.hasSuffix(".app") ? query : "\(query).app"
        for folder in ["/Applications", NSString(string: "~/Applications").expandingTildeInPath] {
            let candidate = (folder as NSString).appendingPathComponent(appName)
            if FileManager.default.fileExists(atPath: candidate) {
                let url = URL(fileURLWithPath: candidate)
                let name = url.deletingPathExtension().lastPathComponent
                let bundleId = Bundle(url: url)?.bundleIdentifier
                return ResolvedEditor(
                    id: name.lowercased(),
                    displayName: name,
                    bundleId: bundleId,
                    url: url
                )
            }
        }

        throw AppError.unknownEditor(query)
    }
}
