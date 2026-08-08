import Darwin
import Foundation
import UniformTypeIdentifiers

private struct CLIConfig {
    enum Action {
        case status
        case set
        case list
        case help
    }

    var action: Action = .status
    var targetQuery: String?
    var dryRun = false
    var yes = false
    var verbose = false

    static func parse(_ arguments: [String]) -> CLIConfig {
        var config = CLIConfig()
        var positional: [String] = []

        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "-h", "--help", "help":
                config.action = .help
                return config
            case "-y", "--yes":
                config.yes = true
            case "--dry-run":
                config.dryRun = true
            case "-v", "--verbose", "--all":
                config.verbose = true
            case "status", "audit", "check":
                config.action = .status
            case "set", "apply":
                config.action = .set
            case "list", "ls":
                config.action = .list
            default:
                if !arg.hasPrefix("-") {
                    positional.append(arg)
                }
            }
            index += 1
        }

        if let first = positional.first {
            config.targetQuery = first
        }

        return config
    }
}

private enum ANSI {
    static let isTTY = isatty(STDOUT_FILENO) != 0

    static func bold(_ text: String) -> String { isTTY ? "\u{001B}[1m\(text)\u{001B}[0m" : text }
    static func green(_ text: String) -> String { isTTY ? "\u{001B}[32m\(text)\u{001B}[0m" : text }
    static func yellow(_ text: String) -> String { isTTY ? "\u{001B}[33m\(text)\u{001B}[0m" : text }
    static func red(_ text: String) -> String { isTTY ? "\u{001B}[31m\(text)\u{001B}[0m" : text }
    static func cyan(_ text: String) -> String { isTTY ? "\u{001B}[36m\(text)\u{001B}[0m" : text }
    static func gray(_ text: String) -> String { isTTY ? "\u{001B}[90m\(text)\u{001B}[0m" : text }
}

@main
struct CodeEditorHandlersCLI {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        let config = CLIConfig.parse(args)

        do {
            switch config.action {
            case .help:
                printHelp()
            case .list:
                printInstalledEditors()
            case .status:
                try await runStatus(config)
            case .set:
                try await runSet(config)
            }
        } catch {
            fputs("\(ANSI.red("error:")) \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func printInstalledEditors() {
        let installed = EditorRegistry.detectInstalledEditors()
        print(ANSI.bold("Detected Code Editors on this Mac:"))
        if installed.isEmpty {
            print("  \(ANSI.yellow("None found in /Applications or ~/Applications."))")
            return
        }
        for editor in installed {
            print("  • \(ANSI.cyan(editor.displayName)) \(ANSI.gray("(\(editor.id))")) ➔ \(editor.path)")
        }
    }

    private static func resolveTargetEditor(query: String?) throws -> ResolvedEditor {
        if let query {
            return try EditorRegistry.resolve(query: query)
        }

        let installed = EditorRegistry.detectInstalledEditors()
        if installed.isEmpty {
            throw AppError.noEditorFound
        }
        if installed.count == 1 {
            return installed[0]
        }

        // Default preference: VS Code (code), then Antigravity IDE, then first detected
        if let vscode = installed.first(where: { $0.id == "vscode" }) { return vscode }
        if let ag = installed.first(where: { $0.id == "antigravity" }) { return ag }
        return installed[0]
    }

    private static func runStatus(_ config: CLIConfig) async throws {
        let target = try resolveTargetEditor(query: config.targetQuery)
        let associations = CuratedExtensions.resolveAll()
        let records = LaunchServicesClient.audit(associations: associations, target: target)

        print("\(ANSI.bold("Target Editor:")) \(ANSI.cyan(target.displayName)) \(ANSI.gray("(\(target.path))"))")
        let matching = records.filter(\.isTargeted).count
        let differing = records.filter { !$0.isTargeted }

        print("\n\(ANSI.bold("Status Summary:"))")
        print("  \(ANSI.green("✔")) \(matching)/\(records.count) types already open in \(target.displayName)")

        if differing.isEmpty {
            print("  \(ANSI.green("All \(records.count) developer file extensions already open in \(target.displayName)."))\n")
            return
        }

        print("  \(ANSI.yellow("➜")) \(differing.count) types differ\n")

        if differing.count <= 25 || config.verbose {
            print(ANSI.bold("Differing Handlers:"))
            for record in differing {
                let current = record.currentApp?.name ?? "none"
                let exts = record.extensionsFormatted
                print("  \(ANSI.yellow("•")) \(exts.padding(toLength: 26, withPad: " ", startingAt: 0)) \(ANSI.gray(current)) ➔ \(ANSI.cyan(target.displayName))")
            }
        } else {
            // Group differing by category for clean, non-flooding display
            print(ANSI.bold("Differing Handlers by Category:"))
            var grouped: [String: [HandlerRecord]] = [:]
            for r in differing {
                grouped[r.item.category, default: []].append(r)
            }
            for (category, items) in grouped.sorted(by: { $0.key < $1.key }) {
                let currentApps = Set(items.compactMap { $0.currentApp?.name ?? "none" }).sorted().joined(separator: ", ")
                let extsSample = items.prefix(4).map(\.extensionsFormatted).joined(separator: ", ")
                let more = items.count > 4 ? " +\(items.count - 4) more" : ""
                print("  \(ANSI.yellow("•")) \(category.padding(toLength: 26, withPad: " ", startingAt: 0)) \(items.count) types \(ANSI.gray("[\(extsSample)\(more)]")) ➔ currently \(ANSI.gray(currentApps))")
            }
            print("\n  \(ANSI.gray("(Pass -v or --all to list all \(differing.count) individual extensions)"))")
        }

        let suggestedAlias = target.id == "vscode" ? "code" : target.id
        print("\n\(ANSI.gray("Tip: Run 'code-editor-handlers set \(suggestedAlias)' to apply changes."))")
    }

    private static func runSet(_ config: CLIConfig) async throws {
        let target = try resolveTargetEditor(query: config.targetQuery)
        let associations = CuratedExtensions.resolveAll()
        let records = LaunchServicesClient.audit(associations: associations, target: target)
        let toUpdate = records.filter { !$0.isTargeted }

        print("\(ANSI.bold("Target Editor:")) \(ANSI.cyan(target.displayName)) \(ANSI.gray("(\(target.path))"))")

        if toUpdate.isEmpty {
            print("\n\(ANSI.green("✔ All \(records.count) developer file associations already target \(target.displayName). Nothing to do!"))")
            return
        }

        print("\n\(ANSI.bold("Changes to Apply (\(toUpdate.count) types):"))")
        for record in toUpdate {
            let current = record.currentApp?.name ?? "none"
            print("  \(ANSI.yellow("➜")) \(record.extensionsFormatted.padding(toLength: 26, withPad: " ", startingAt: 0)) \(ANSI.gray(current)) ➔ \(ANSI.cyan(target.displayName))")
        }

        if config.dryRun {
            print("\n\(ANSI.cyan("Dry run complete.")) No changes were made.")
            return
        }

        if !config.yes {
            print("\nApply \(toUpdate.count) association change(s) to \(target.displayName)? [y/N] ", terminator: "")
            fflush(stdout)
            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  input == "y" || input == "yes" else {
                print("Cancelled.")
                return
            }
        }

        print("\nApplying changes (macOS may display system permission prompts for changed UTIs)...")
        var failures = 0

        for (idx, record) in toUpdate.enumerated() {
            let label = "[\(idx + 1)/\(toUpdate.count)] \(record.extensionsFormatted)"
            print("  \(label)...", terminator: " ")
            fflush(stdout)

            do {
                try await LaunchServicesClient.setDefaultApplication(at: target.url, for: record.item.utType)
                if let verified = LaunchServicesClient.currentHandler(for: record.item.utType),
                   (verified.bundleId == target.bundleId || verified.path == target.path) {
                    print(ANSI.green("✔"))
                } else {
                    failures += 1
                    print(ANSI.red("failed (handler mismatch)"))
                }
            } catch {
                failures += 1
                print(ANSI.red("failed: \(error.localizedDescription)"))
            }
        }

        print("")
        if failures > 0 {
            throw AppError.applyFailed(failures)
        } else {
            print("\(ANSI.green("✔ Successfully applied and verified all \(toUpdate.count) file associations!"))")
        }
    }

    private static func printHelp() {
        print("""
        \(ANSI.bold("code-editor-handlers")) - Fast, minimalist default opener manager for macOS developer files.

        \(ANSI.bold("USAGE:"))
          code-editor-handlers [status] [editor] [options]
          code-editor-handlers set <editor> [options]
          code-editor-handlers list

        \(ANSI.bold("COMMANDS:"))
          status [editor]      Show current opener status (default)
          set <editor>         Set the specified editor as the default opener
          list                 List all detected code editors on this Mac

        \(ANSI.bold("EDITORS:"))
          Preset aliases: antigravity (or ag), vscode (or code), cursor, zed, windsurf, sublime
          Or provide an app name or direct path: /Applications/MyEditor.app

        \(ANSI.bold("OPTIONS:"))
          -y, --yes            Apply without interactive confirmation prompt
          --dry-run            Show proposed changes without applying them
          -v, --verbose, --all Show every individual extension inspection
          -h, --help           Show this help message
        """)
    }
}
