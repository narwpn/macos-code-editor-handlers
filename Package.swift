// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "macos-code-editor-handlers",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "code-editor-handlers", targets: ["CodeEditorHandlers"])
    ],
    targets: [
        .executableTarget(
            name: "CodeEditorHandlers"
        )
    ]
)
