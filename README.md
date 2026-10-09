# auspex-i18n

Every user-facing string in [Auspex](https://github.com/AstroQore/auspex),
authored once in `catalog/en.json`, translated in `catalog/zh-Hans.json`, and
consumed by the app through SwiftPM. Strings only: no product logic lives
here.

`catalog/` is the source. `implementations/swift` is generated from it by
`scripts/generate.py` and checked in, so the app never needs Python to build.
The layout is the one [vibe-bar-i18n](https://github.com/AstroQore/vibe-bar-i18n)
uses.

[AGENTS.md](AGENTS.md) is the operating manual — key naming, translation
style, versioning, what does not belong here. This file is just the parts you
need on the way in.

## Use it

```swift
.package(url: "https://github.com/AstroQore/auspex-i18n.git", exact: "0.1.0")
```

```swift
import AuspexLocalization

Text(L10n.Common.cancel)
Text(L10n.Now.status(time: time, live: live, working: working))
Text(L10n.Trace.earlierRows(count: 3))
```

Strings resolve through the host's own resources first, then this package's
resource bundle inside the host's `Contents/Resources`, and only in a source
build or a test host through `Bundle.module` — so a packaged app finds its
strings without ever reaching SwiftPM's accessor, which traps once the build
directory it names is gone. A packaging step therefore copies
`auspex-i18n_AuspexLocalization.bundle` (and, for the system's per-app
language picker, its `.lproj` directories) into `Contents/Resources`.

With no override the package follows the macOS language. To offer an in-app
language picker, set the override — it takes effect on the next read, no
relaunch:

```swift
L10n.availableLocales             // ["en", "zh-Hans"]
L10n.localeOverride = "zh-Hans"   // force a language
L10n.localeOverride = nil         // back to the system language
```

`"zh"`, `"zh-Hans"` and `"zh-Hans-CN"` all resolve to `zh-Hans`; a tag this
package does not ship falls back to the system language rather than to raw
keys. Still list the tags in the app's `CFBundleLocalizations`: that is what
drives the system's own per-app language picker.

## Add a key

1. Add it to `catalog/en.json` with a `comment` saying where it appears, and
   to every other locale. Placeholders are named — `{count}`, never `%@`.
2. `python3 scripts/generate.py`
3. `python3 scripts/validate.py`
4. Commit the catalog change and the regenerated files together.

`validate.py` is the gate: schema, key parity, placeholder parity, ICU plural
syntax, glossary compliance, duplicate sentences, and whether the generated
files match the catalog. It names the file, the key and the problem.

## Add a language

1. `catalog/<bcp47>.json` — same keys, `locale` matching the file name, no
   `comment` or `placeholders` (those live in the source locale only).
2. `python3 scripts/generate.py && python3 scripts/validate.py`. The Swift
   lane gains a `<locale>.lproj`. No script edit is needed — locales come
   from the directory listing.
3. In Auspex: add the tag to `CFBundleLocalizations`, a case to
   `AppLanguage`, and the `.lproj` to `Scripts/build_app.sh`'s check.

## Work on it

```sh
python3 scripts/validate.py          # everything, including generated freshness
python3 scripts/generate.py          # rewrite the Swift lane; deterministic
python3 scripts/generate.py --check  # exit 1 if a checked-in file is stale
swift build && swift test            # Swift lane
```

Only Python 3.9+ is required for the scripts — the standard library, no
packages, so the version macOS ships is enough.

## License

MIT. See [LICENSE](LICENSE).
