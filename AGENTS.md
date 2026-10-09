# AGENTS.md — Auspex Localization Catalog

This file is the operating manual for AI agents and humans working on this
repository. It is **self-contained**: read it top to bottom and you can add a
key, add a language, or wire the app to a new release without asking anyone.

## 1. What this repository is

One catalog of user-facing strings for Auspex:

| Repo | Client | Consumes this via |
| --- | --- | --- |
| `AstroQore/auspex` | macOS native (Swift, SwiftUI) | SwiftPM dependency, exact-pinned tag |

It holds **strings only**. It has no product logic, no session parsing, no
harness adapters. If a change here needs a code change in Auspex, the change
here is probably wrong.

The layout is the one `AstroQore/vibe-bar-i18n` uses, which in turn mirrors
`AstroQore/agent-session-kit`: one repository, implementation lanes under
`implementations/`, and a root manifest that points into them with explicit
paths, so a consumer's dependency URL never mentions a lane. There is one lane
today; a second client would add a sibling directory, not move this one.

```text
catalog/
  en.json            # source of truth — the only file where a string is authored
  zh-Hans.json       # translations
  _glossary.json     # proper nouns that must never be translated
schema/              # JSON Schema for both file shapes
scripts/             # validate + generate, pure functions of catalog/
implementations/
  swift/             # generated .strings/.stringsdict + typed Swift API
Package.swift        # root manifest, points into implementations/swift
package.json         # the version number, in one place (§ 8)
```

## 2. The rules that matter

These are the ones that cause silent breakage months later. The rest of this
file is detail.

1. **A key is an identifier, never an English sentence.** `now.needsYou`, not
   `"Needs you"`. Renaming a key is a breaking change; changing what a key
   *means* is not allowed at all — add a new key and retire the old one.
2. **Placeholders are named, never positional.** Author `{count}` and
   `{harness}`. The Swift generator converts them to positional `%@` / `%lld`
   for `.strings` **and** emits a typed function, so call sites pass named
   arguments and never see the order. Positional authoring is exactly what
   breaks when a translation reorders a sentence.
3. **Only `en.json` declares `comment` and `placeholders`.** Translations
   carry `value` and nothing else. Two files declaring the same metadata is
   two files that will disagree.
4. **The glossary is data, not a convention.** Harness, company, product and
   protocol names live in `catalog/_glossary.json`. A term that appears in a
   source string must appear verbatim in every translation of that string;
   validation enforces it. Auspex's own lint reads the same file to decide
   which literals in its views are names rather than copy.
5. **A sentence the app builds by concatenation is a bug.** Chinese word
   order does not survive `"\(count) sessions"` + `" on this task"`. One key,
   placeholders inside it.
6. **Generated files are checked in.** `implementations/swift/Resources/**`
   and `implementations/swift/Sources/AuspexLocalization/Generated/**` are
   produced by `scripts/`, committed, and verified by CI. A consumer must not
   need Python to build.
7. **Nothing in the app reads `catalog/*.json` at runtime.** It calls the
   generated `L10n` API. That is what lets this repository change shape
   without touching a call site.
8. **Every new user-facing string starts here.** Not in a view, not "for
   now" — a literal added to the app is a string no translator can see.
   Auspex enforces this on its side: `Scripts/lint_localization.py` fails
   `swift test` on a user-facing literal anywhere under `Sources/AuspexApp`.
   § 4 covers the other half — reuse an existing key before adding one.

## 3. Catalog format

`catalog/en.json` — the source locale:

```json
{
  "$schema": "../schema/catalog.schema.json",
  "locale": "en",
  "keys": {
    "common.cancel": {
      "value": "Cancel",
      "comment": "Button that abandons an action in progress."
    },
    "now.status": {
      "value": "{time} · {live} live · {working} working",
      "comment": "Now's header line beside the title: the clock (HH:mm) and two counts of sessions.",
      "placeholders": { "time": "string", "live": "int", "working": "int" }
    }
  }
}
```

`catalog/zh-Hans.json` — a translation:

```json
{
  "$schema": "../schema/catalog.schema.json",
  "locale": "zh-Hans",
  "keys": {
    "common.cancel": { "value": "取消" },
    "now.status": { "value": "{time} · {live} 个活跃 · {working} 个工作中" }
  }
}
```

**Key namespaces** follow the app's surfaces: `common.*` (words every
surface uses), `app.*` (menu commands), `menuBar.*`, `section.*` and
`sidebar.*`, `viewMode.*` (the six views' names), `now.*`, `board.*`,
`session.*`, `state.*`, `attention.*`, `notice.*`, `task.*`, `tasks.*`,
`taskDetail.*`, `delivery.*`, `catchUp.*`, `palette.*`, `trace.*`,
`context.*`, `flight.*`, `perch.*`, `aviary.*`, `crew.*`, `projects.*`,
`ignore.*`, `harnesses.*`, `mcp.*`, `notification.*`, `settings.*`,
`setup.*`, `agents.*`, `characters.*`, `loginItem.*`, `copy.*`, `meta.*`,
`ledger.*`, `time.*`, `search.*`, `placeholder.*`, `colour.*`.

**Placeholder types** are `string`, `int` and `double`. Formatting a date, a
duration or a token count is the app's job — the catalog receives the
formatted value or the raw number, never a pre-formatted sentence.

A key with two or more placeholders generates **indexed** specifiers
(`%1$lld`, `%2$lld`) rather than bare ones, because a translation that
reorders the sentence is the normal case, not the exception. A single
placeholder keeps the plain form, which is what `.stringsdict` expects.

A literal `%` is fine in a value that has placeholders (the generator escapes
it and the formatter collapses it again). In a value with **no** placeholders
it would reach the screen doubled, so make the number a placeholder:
`"context over {percent}% used"`.

Only `{name}` and `{name, plural, …}` are accepted. `select`,
`selectordinal` and `offset:` are rejected by validation: `.stringsdict`
cannot express `offset:`, and the other two degrade badly.

**Plurals** use ICU:

```json
"trace.earlierRows": {
  "value": "{count, plural, one {# earlier row} other {# earlier rows}}",
  "comment": "Trace: button that draws rows cut from the top of a long trace."
}
```

Simplified Chinese has only `other`; English needs `one` and `other`. The
Swift generator emits `.stringsdict` for any key whose value contains a
plural, and a second placeholder may sit inside a branch.

## 4. Reuse before you add

The moment the same sentence exists under two keys they drift: one gets
retranslated, the other does not, and nobody comparing two screenshots can
tell which key each screen used.

Before adding a key:

1. Search `catalog/en.json` for the sentence, then for the concept —
   `grep -i "needs you" catalog/en.json`, then look through the namespace it
   would belong to. Namespaces group by *surface*, and the same sentence on
   two surfaces is still one sentence.
2. Only then add a key.

`scripts/validate.py` enforces the mechanical half: two source values that
say the same thing — ignoring case, trailing punctuation and placeholder
*names* — fail the build. A genuine collision, where two English strings must
stay separately translatable because Chinese distinguishes them, is declared
in a comment: `distinct-from: <other.key>`. English leans on this more than
most languages: "Done" is a button (完成) and a status (已完成), "Live" is a
count (活跃) and a mode (实时), and "Needs you" is a heading where "needs
you" is a chip after a number. That is a sentence a reviewer can weigh, which
a silent duplicate is not.

The half a script cannot check is meaning. That one is on the reviewer.

## 5. Adding a key

1. Add it to `catalog/en.json` with a `comment` that says where it appears —
   a translator cannot see your screen.
2. Add it to every other locale. `python3 scripts/validate.py` fails on a
   missing key; that is deliberate. If a translation is genuinely not ready,
   ship the key with the English text as its value rather than omitting it,
   so the app renders something and the gap is visible in the diff.
3. `python3 scripts/generate.py` to refresh the generated files.
4. `python3 scripts/validate.py` — key parity, placeholder parity, ICU
   syntax, glossary compliance, reuse, schema, and generated-file freshness.
5. Commit the catalog change and the regenerated output together.

## 6. Adding a language

1. `catalog/<bcp47>.json` with the same keys, `locale` matching the filename.
2. Regenerate; the Swift lane gains `<locale>.lproj`. Locales come from the
   directory listing, so no script edit is needed.
3. Auspex needs three changes: the tag in `CFBundleLocalizations` in
   `Resources/Info.plist`, a case in `AppLanguage` (Core) so the Language
   setting can offer it, and the `.lproj` name in `Scripts/build_app.sh`'s
   packaged-localization check.

## 7. Translation style

Written for Simplified Chinese first; the same spirit applies to any locale.

- Terse UI Chinese, not literal translation. A label is a label, not a
  sentence: `取消`, not `请取消`.
- No full stop at the end of a short label or button. Sentences in help text
  and explanations do take one (`。`), and full-width punctuation is used
  throughout: `，`、`：`、`「」`、`（）`.
- Keep glossary terms in English inline: `Claude Code 正在等你`.
- AstroQore's apps keep three nouns in English in Chinese: **harness**,
  **agent**, **skill** (`子 agent`, `安装 harness hook`). Everything else is
  translated: session 会话, task 任务, project 项目, transcript 对话记录,
  context 上下文, prompt 提示词, worktree stays worktree.
- The six views have names (Now, Ledger, Aviary, Flock, Perch, Flight).
  They are translated — 此刻、账本、鸟舍、鸟群、栖枝、航迹 — and every key
  that mentions one must use the same word as `viewMode.*`.
- Numbers and units follow Chinese convention: `3 小时`, `5 分钟前`. Compact
  stopwatch readings (`4m12s`, `1h04m`) are formatted by the app and stay as
  they are.
- An error says what happened and what to do, in that order. No apology.
- If a string cannot be translated well because the English is built from
  fragments, fix the key — do not translate the fragments.

## 8. Versioning and release

Semantic versioning on tags (`v0.1.0`).

- **Adding** a key or a locale: minor.
- **Changing a translation** (same meaning, better wording): patch.
- **Changing what a key means, renaming, or removing** one: major — and
  prefer adding a new key over changing an existing one, so the app can
  migrate on its own schedule.
- Auspex pins exactly, matching the `agent-session-kit` convention:
  `.package(url: …, exact: "0.1.0")` in its `Package.swift`.

`package.json`'s `version` and the git tag are the same number. Bump both in
the release commit; CI fails a tag that disagrees with `package.json`. There
is no npm package today; the field is kept so the version has one source of
truth if a second lane ever arrives.

A release is: validate clean, regenerate clean, bump `package.json`, tag,
push. There is no build artefact to upload — the generated files are in the
tree.

**Licence.** MIT, deliberately, while Auspex is AGPL-3.0-only: a permissive
catalogue is a normal dependency of a copyleft app, and a translator
contributing a language should not have to reason about copyleft to do it.

## 9. Consuming it

```swift
.package(url: "https://github.com/AstroQore/auspex-i18n.git", exact: "0.1.0")
```

```swift
Text(L10n.Common.cancel)
Text(L10n.Now.status(time: time, live: live, working: working))
Text(L10n.Trace.earlierRows(count: hidden))
```

Strings resolve through the host's own resources first, then this package's
resource bundle inside the host's `Contents/Resources`, and only in a source
build or a test host through `Bundle.module` — SwiftPM's accessor traps once
the build directory it names is gone, which is every installed app. Auspex's
`Scripts/build_app.sh` copies `auspex-i18n_AuspexLocalization.bundle` (and its
`.lproj` directories, for the system's per-app language picker) into
`Contents/Resources`, and its packaged-app smoke test proves a zh-Hans string
resolves from there with the build directory hidden.

Auspex sets `L10n.localeOverride` explicitly from its Language setting
(System / English / 简体中文, kept in `~/.auspex/settings.json`) and keys its
window roots on the choice, so a change takes effect without a relaunch.

## 10. What does not belong here

- Harness, company and product names — they are listed in the glossary only
  so they are protected from translation.
- MCP tool names, tool descriptions and results: a protocol surface an agent
  parses, fixed in English.
- What Auspex writes into a harness's own files (config fences, the
  `auspex-coordination` skill).
- Command-line `--help`, renderer diagnostics, log lines, JSON keys, file
  paths, and anything a machine parses. Localizing a machine-readable string
  breaks the machine.
- Marketing copy, README text, release notes.
