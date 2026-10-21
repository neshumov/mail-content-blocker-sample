# Mail Blocker Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Container app with an editor for AdGuard rules, and a MailKit extension
  (`MEContentBlocker`) that hands the converted rules to Mail.
- `MailBlockerCore` and `MailBlockerShared` Swift package libraries.
- App icon.
- Opening a rules file (`open -a "Mail Blocker" list.txt`) loads it into the editor and applies it. A file that is not UTF-8 text is reported in the window and changes nothing.

### Changed

- Convert and save asks Mail to reload the rules (`MEExtensionManager.reloadContentBlocker`). The window and the README no longer say that Mail reads the rules only at launch: a message open in the preview pane keeps the old rules until the reload, and a new message window picks the new ones up on its own.

### Deprecated

### Removed

### Fixed

- The extension and the app now share one bundle version (the build warned that the app had none).

### Security
