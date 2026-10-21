# Mail Blocker

A minimal, working Mail content blocker for macOS: a container app plus a MailKit extension
([`MEContentBlocker`][mekit]). You type [AdGuard filtering rules][adguardrules], the app converts them with
[SafariConverterLib][converter] into WebKit content-blocking JSON, and the extension hands that JSON to Mail.

    rules (text) -> SafariConverterLib -> rules.json in an App Group -> extension -> Mail.app

Built for the talk "Blocking Without Feedback: Mail Tracker Protection Inside Apple Mail"
(Ad Blocker Dev Summit 2026).

[mekit]: https://developer.apple.com/documentation/mailkit/mecontentblocker
[adguardrules]: https://adguard.com/kb/general/ad-filtering/create-own-filters/
[converter]: https://github.com/AdguardTeam/SafariConverterLib

- [Using the app](#using-the-app)
- [Using as a library](#using-as-a-library)
- [What Mail does with the rules](#what-mail-does-with-the-rules)
- [For developers](#for-developers)
    - [How to build, test, debug](#how-to-build-test-debug)
    - [Repository layout](#repository-layout)
- [License](#license)

## Using the app

1. Run the app once, then in Mail open **Settings › Extensions** and turn on "Mail Blocker".
2. Edit the rules in the app and press **Convert and save**.
3. Quit and reopen Mail (the **Quit and reopen Mail** button does it). Mail reads the rules only when it launches.
4. A list can also be opened from outside: `open -a "Mail Blocker" list.txt` (or drop a .txt file on the Dock icon). It replaces the editor text and is applied at once.
5. The "Extension log" in the app shows when Mail last asked the extension for its rules.

## Using as a library

The conversion and the storage are Swift package libraries, so another Mail extension can reuse them.

```swift
.package(url: "https://github.com/<owner>/mail-content-blocker-sample.git", from: "0.1.0"),
```

Products:

- `MailBlockerCore`: `Converter.convert(_:)` turns the text of a list into a `ConversionSummary`
  (entries, JSON, warnings); `RulesApplier.apply(_:)` also saves it for the extension; `RulesFile` reads a list handed to the app.
- `MailBlockerShared`: `SharedStorage`, the App Group file the app writes and the extension reads.

```swift
let summary = Converter.convert("||pixel.example.com^$image")
try SharedStorage.save(json: summary.json, source: "||pixel.example.com^$image")
```

## What Mail does with the rules

These are results of our runs on macOS 27 with SafariConverterLib 4.3.0.

- **No feedback.** MailKit has no callback for blocked requests, no counter, and no way to ask whether the user
  turned the extension on. `reloadContentBlocker` reports success but Mail applies new rules only at launch,
  hence the restart.
- **Network rules work, domain rules do not.** URL patterns with `$image`, `$third-party`, path-only patterns and
  exceptions block. `$domain=` with a positive domain never fires, `$domain=~` always applies, and domain-scoped
  cosmetic rules are shipped but have no effect. Generic `##` rules do hide elements.
- **The converter drops** `$removeparam`, `$redirect`, `$cookie` and regular expressions with `{n}`; scriptlets
  and CSS injection are ignored because advanced blocking is off.
- WebKit does not load a list of more than 150,000 entries.
- The converter does not validate cosmetic selectors, and WebKit silently discards a whole grouped entry that
  contains a broken one.

## For developers

### How to build, test, debug

Requirements: macOS 14+, Xcode (we used 26.2), [XcodeGen](https://github.com/yonaskolb/XcodeGen), an Apple ID
signed in to Xcode (a free Personal Team is enough).

```shell
cp Local.xcconfig.example Local.xcconfig   # set DEVELOPMENT_TEAM and a unique BUNDLE_ID_PREFIX
xcodegen generate
open MailBlocker.xcodeproj                 # build and run the MailBlocker scheme
```

The Xcode project is generated, not committed. `Local.xcconfig` is not committed either.

The Swift package tests run without signing:

```shell
swift test
```

To debug the extension, open Console.app, filter by the extension's name, and watch the "Extension log" in the
app: it records every call of `contentRulesJSON()`.

### Repository layout

| Path | What it does |
|---|---|
| `Extension/MailExtension.swift` | `MEExtension` and `MEContentBlocker`: `contentRulesJSON()` returns the saved JSON |
| `Sources/MailBlockerShared/` | App Group file with the rules, the source text and a small log |
| `Sources/MailBlockerCore/` | AdGuard rules to WebKit JSON, entry limit and warnings |
| `Sources/MailBlockerCore/RulesFile.swift` | Reading a list handed to the app, and the inbox that holds it until the window is ready |
| `Sources/MailBlockerCore/Applier.swift` | Convert, save for the extension, and the status text the window shows |
| `Tests/` | Tests of the conversion, the file handling, the inbox, the applier and the shared storage (`swift test`) |
| `App/App.swift` | The window: editor, convert and save, restart Mail, JSON and log views |
| `tools/make_icon.py` | Draws the app icon into `App/Assets.xcassets` (needs Pillow; the PNGs are committed) |
| `project.yml`, `Config.xcconfig` | XcodeGen description and the build settings it reads |

## License

GPL-3.0, the same as SafariConverterLib. See [LICENSE](LICENSE).
