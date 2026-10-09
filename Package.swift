// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "auspex-i18n",
    // The one consumer of the Swift lane is Auspex, a macOS 26 app.
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "AuspexLocalization", targets: ["AuspexLocalization"])
    ],
    // The Swift lane sits under `implementations/` and the manifest points
    // into it with explicit paths, the shape AstroQore/vibe-bar-i18n and
    // AstroQore/agent-session-kit use: a consumer's dependency URL and
    // `import AuspexLocalization` never mention a lane, and a second lane can
    // be added beside this one without moving anything.
    targets: [
        // `path` is the lane root rather than the sources directory because
        // SwiftPM resolves `resources:` relative to `path` and refuses to
        // look outside it; `sources:` then narrows compilation back to the
        // one source directory.
        //
        // `.process`, not `.copy`. Measured in vibe-bar-i18n on Swift 6.3 /
        // macOS 26 and unchanged here: `.process("Resources")` is the only
        // spelling whose `.lproj` directories SwiftPM registers against
        // `defaultLocalization` and flattens to the bundle root. `.copy`
        // copies the tree one level too deep and only resolves by a
        // coincidence of CFBundle's "version 1" bundle layout.
        //
        // SwiftPM lowercases the directory it emits, so `zh-Hans` in
        // `catalog/` becomes `zh-hans.lproj` in the built bundle.
        // `L10n.availableLocales` therefore reports the catalog's canonical
        // tags and the bundle lookup tries both spellings;
        // `implementations/swift/Tests` asserts all of it.
        .target(
            name: "AuspexLocalization",
            path: "implementations/swift",
            exclude: ["Tests"],
            sources: ["Sources/AuspexLocalization"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AuspexLocalizationTests",
            dependencies: ["AuspexLocalization"],
            path: "implementations/swift/Tests/AuspexLocalizationTests"
        )
    ]
)
