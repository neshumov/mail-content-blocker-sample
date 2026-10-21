# Mail Blocker

A minimal, working Mail content blocker for macOS: a container app plus a MailKit extension (`MEContentBlocker`).
You type AdGuard-syntax rules, the app converts them with [SafariConverterLib](https://github.com/AdguardTeam/SafariConverterLib)
to WebKit content-blocking JSON, and the extension hands that JSON to Mail.

    rules (text) -> SafariConverterLib -> rules.json in an App Group -> extension -> Mail.app

Built for the talk "Blocking Without Feedback: Mail Tracker Protection Inside Apple Mail" (Ad Blocker Dev Summit 2026).

## Build

Requirements: macOS 14+, Xcode (we used 26.2), [XcodeGen](https://github.com/yonaskolb/XcodeGen), an Apple ID signed in to Xcode (a free Personal Team is enough).

    cp Local.xcconfig.example Local.xcconfig     # set DEVELOPMENT_TEAM and a unique BUNDLE_ID_PREFIX
    xcodegen generate
    open MailBlocker.xcodeproj                   # build and run the MailBlocker scheme

The Xcode project is generated, not committed. `Local.xcconfig` is not committed either.

## Use

1. Run the app once, then in Mail open **Settings › Extensions** and turn on "Mail Blocker".
2. Edit the rules in the app and press **Convert and save**.
3. Quit and reopen Mail (the **Quit and reopen Mail** button does it). Mail reads the rules only when it launches.
4. The "Extension log" in the app shows when Mail last asked the extension for its rules.

## What to know

- **No feedback.** MailKit has no callback for blocked requests, no counter, and no way to ask whether the user turned the extension on.
  `reloadContentBlocker` reports success but Mail applies new rules only at launch, hence the restart.
- **Network rules work, domain rules do not.** URL patterns with `$image`, `$third-party`, path-only patterns and exceptions block.
  `$domain=` with a positive domain never fires, `$domain=~` always applies, and domain-scoped cosmetic rules are shipped but have no effect.
  Generic `##` rules do hide elements.
- **Converter drops** `$removeparam`, `$redirect`, `$cookie` and regular expressions with `{n}`; scriptlets and CSS injection are ignored because advanced blocking is off.
- WebKit does not load a list of more than 150,000 entries.
- The converter does not validate cosmetic selectors, and WebKit silently discards a whole grouped entry that contains a broken one.

These are results of our runs on macOS 27 with SafariConverterLib 4.3.0.

## Files

| Path | What it does |
|---|---|
| `Extension/MailExtension.swift` | `MEExtension` and `MEContentBlocker`: `contentRulesJSON()` returns the saved JSON |
| `Shared/SharedStorage.swift` | App Group file with the rules, the source text and a small log |
| `App/Converter.swift` | AdGuard rules to WebKit JSON, entry limit and warnings |
| `App/App.swift` | The window: editor, convert and save, restart Mail, JSON and log views |
