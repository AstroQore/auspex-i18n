import Foundation
import Testing

@testable import AuspexLocalization

/// These tests exist to catch the two failures that a localization package
/// otherwise ships silently: a key that resolves to its own identifier
/// because the resource never made it into the bundle, and a translation
/// whose format specifiers no longer line up with the values the call site
/// passes.
///
/// Serialized because ``L10n/localeOverride`` is process-wide state.
@Suite(.serialized)
struct LocalizationTests {
    /// Restores the override after each test, so a failure in one cannot
    /// change what the next one measures.
    private func withOverride<T>(_ locale: String?, _ body: () throws -> T) rethrows -> T {
        let previous = L10n.localeOverride
        L10n.localeOverride = locale
        defer { L10n.localeOverride = previous }
        return try body()
    }

    // MARK: - Bundle wiring

    /// If `Package.swift` used `.copy` instead of `.process`, or the
    /// `.lproj` directories landed a level too deep, this is the test that
    /// notices — before the app does.
    @Test func resourceBundleRegistersEveryLocale() {
        let registered = Bundle.module.localizations.map { $0.lowercased() }
        #expect(!registered.isEmpty, "the package resource bundle has no localizations at all")
        for locale in L10nCatalogFacts.locales {
            #expect(
                registered.contains(locale.lowercased()),
                "\(locale) is in the catalog but not registered on the resource bundle"
            )
        }
    }

    /// With no override, resolution must land on a specific `.lproj`
    /// sub-bundle chosen from `Locale.preferredLanguages`, never on
    /// `Bundle.module` itself — whose `preferredLocalizations` CFBundle
    /// constrains to the *host's* `CFBundleLocalizations`.
    @Test func systemLanguagePathResolvesToASpecificLproj() {
        withOverride(nil) {
            #expect(L10nCatalogFacts.locales.contains(L10n.resolvedLocale))
            let directory = L10n.bundle.bundleURL.lastPathComponent
            #expect(
                directory.hasSuffix(".lproj"),
                "with no override L10n.bundle resolved to \(directory), not a .lproj sub-bundle"
            )
            #expect(directory.lowercased() == "\(L10n.resolvedLocale.lowercased()).lproj")
        }
    }

    @Test func availableLocalesAreTheCatalogLocales() {
        #expect(L10n.availableLocales == L10nCatalogFacts.locales)
        #expect(L10n.availableLocales.contains(L10nCatalogFacts.sourceLocale))
        #expect(L10n.availableLocales == ["en", "zh-Hans"])
    }

    // MARK: - Every key, every locale

    /// `Bundle.localizedString` hands back the key itself when it cannot
    /// find one, which is exactly how a missing translation reaches a
    /// screenshot: `now.needsYou` rendered as a label.
    @Test func everyKeyResolvesInEveryLocale() {
        for locale in L10nCatalogFacts.locales {
            withOverride(locale) {
                #expect(L10n.resolvedLocale == locale)
                for key in L10nCatalogFacts.keys {
                    let resolved = L10nSupport.string(key)
                    #expect(resolved != key, "\(locale): \(key) fell back to its own identifier")
                    #expect(!resolved.isEmpty, "\(locale): \(key) resolved to an empty string")
                }
            }
        }
    }

    /// A translation that drops a `%lld` crashes `String(format:)` on the
    /// missing argument, or silently prints garbage. `validate.py` enforces
    /// this on the catalog; this enforces it on what actually shipped.
    @Test func placeholderCountsMatchTheDeclaredArity() {
        for locale in L10nCatalogFacts.locales {
            withOverride(locale) {
                for key in L10nCatalogFacts.keys where !L10nCatalogFacts.pluralKeys.contains(key) {
                    let expected = L10nCatalogFacts.placeholderCounts[key] ?? 0
                    let template = L10nSupport.string(key)
                    let found = Self.formatSpecifierCount(in: template)
                    #expect(
                        found == expected,
                        "\(locale): \(key) has \(found) format specifiers, expected \(expected); template was \(template)"
                    )
                }
            }
        }
    }

    // MARK: - Override

    @Test func overrideChangesTheResolvedString() {
        withOverride("en") {
            #expect(L10n.Common.cancel == "Cancel")
        }
        withOverride("zh-Hans") {
            #expect(L10n.Common.cancel == "取消")
        }
    }

    /// The generated members are computed, not `static let`. A stored
    /// constant would freeze whichever locale happened to touch it first,
    /// and the language picker would appear to do nothing until relaunch.
    @Test func overrideTakesEffectWithoutRelaunch() {
        withOverride("en") {
            let english = L10n.Settings.Language.system
            L10n.localeOverride = "zh-Hans"
            let chinese = L10n.Settings.Language.system
            #expect(english == "System")
            #expect(chinese == "跟随系统")
        }
    }

    /// A tag the package does not ship must fall back to the system
    /// language, never to raw keys.
    @Test func unknownOverrideFallsBackInsteadOfBreaking() {
        withOverride("qq-Fake") {
            #expect(L10n.Common.cancel != "common.cancel")
        }
        // Region and script subtags are matched leniently.
        withOverride("zh-Hans-CN") { #expect(L10n.Common.cancel == "取消") }
        withOverride("zh") { #expect(L10n.Common.cancel == "取消") }
        withOverride("en-US") { #expect(L10n.Common.cancel == "Cancel") }
    }

    // MARK: - Helpers

    /// Counts `%` conversions, treating `%%` as a literal percent sign.
    private static func formatSpecifierCount(in template: String) -> Int {
        var count = 0
        var index = template.startIndex
        while index < template.endIndex {
            guard template[index] == "%" else {
                index = template.index(after: index)
                continue
            }
            let next = template.index(after: index)
            if next < template.endIndex, template[next] == "%" {
                index = template.index(after: next)  // literal `%%`
                continue
            }
            count += 1
            index = next
        }
        return count
    }
}
