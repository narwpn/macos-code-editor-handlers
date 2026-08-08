import Foundation
import UniformTypeIdentifiers

struct ExtensionGroup: Sendable {
    let category: String
    let extensions: [String]
}

struct AssociationItem: Sendable {
    let utType: UTType
    let extensions: [String]
    let category: String
}

enum CuratedExtensions {
    static let groups: [ExtensionGroup] = [
        ExtensionGroup(
            category: "Systems & Assembly",
            extensions: [
                "c", "h", "cc", "cpp", "cxx", "c++", "hh", "hpp", "hxx", "h++",
                "m", "mm", "swift", "go", "rs", "zig", "zon", "wat", "wast"
            ]
        ),
        ExtensionGroup(
            category: "Application & Scripting",
            extensions: [
                "py", "pyi", "pyw", "java", "jav", "kt", "kts", "scala", "sc",
                "groovy", "gradle", "cs", "csx", "fs", "fsi", "fsx", "rb", "erb",
                "gemspec", "rake", "php", "phtml", "dart", "lua", "pl", "pm",
                "raku", "jl", "ex", "exs", "erl", "hrl", "hs", "lhs", "ml", "mli",
                "re", "rei", "clj", "cljs", "cljc", "edn", "sol"
            ]
        ),
        ExtensionGroup(
            category: "Web & Frontend",
            extensions: [
                "js", "mjs", "cjs", "jsx", "ts", "tsx", "mts", "cts",
                "vue", "svelte", "astro", "css", "scss", "sass", "less",
                "hbs", "handlebars", "pug", "jinja", "jinja2", "j2"
            ]
        ),
        ExtensionGroup(
            category: "Config, Data & Dotfiles",
            extensions: [
                "json", "jsonc", "json5", "yaml", "yml", "toml", "ini", "cfg",
                "conf", "config", "xml", "dtd", "properties", "kdl",
                "env", "editorconfig", "gitattributes", "gitconfig", "gitignore", "gitmodules"
            ]
        ),
        ExtensionGroup(
            category: "Shell & Automation",
            extensions: [
                "sh", "bash", "bashrc", "bash_profile", "bash_login", "bash_logout",
                "profile", "zsh", "zshrc", "zshenv", "zprofile", "zlogin", "zlogout",
                "csh", "tcsh", "fish", "ps1", "psd1", "psm1", "bat", "cmd"
            ]
        ),
        ExtensionGroup(
            category: "DevOps & Build",
            extensions: [
                "dockerfile", "containerfile", "makefile", "mk", "cmake",
                "tf", "tfvars", "hcl", "nix"
            ]
        ),
        ExtensionGroup(
            category: "Data & Schemas",
            extensions: [
                "sql", "graphql", "gql", "proto", "prisma", "r", "rhistory", "rprofile", "xaml"
            ]
        ),
        ExtensionGroup(
            category: "Documentation & Writing",
            extensions: [
                "md", "markdown", "mdoc", "mdown", "mdtext", "mdtxt", "mdwn", "mkd", "mkdn",
                "rst", "txt", "log", "typ", "tex", "bib", "diff", "patch", "ipynb",
                "lock", "code-workspace"
            ]
        )
    ]

    static func resolveAll() -> [AssociationItem] {
        var seenUTIs: [String: (UTType, [String], String)] = [:]
        var order: [String] = []

        for group in groups {
            for ext in group.extensions {
                let cleanExt = ext.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    .lowercased()
                guard !cleanExt.isEmpty, let utType = UTType(filenameExtension: cleanExt) else { continue }
                let id = utType.identifier
                if var existing = seenUTIs[id] {
                    if !existing.1.contains(cleanExt) {
                        existing.1.append(cleanExt)
                    }
                    seenUTIs[id] = existing
                } else {
                    seenUTIs[id] = (utType, [cleanExt], group.category)
                    order.append(id)
                }
            }
        }

        return order.compactMap { id in
            guard let item = seenUTIs[id] else { return nil }
            return AssociationItem(utType: item.0, extensions: item.1.sorted(), category: item.2)
        }
    }
}
