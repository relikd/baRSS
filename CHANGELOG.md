# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project does adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]


## [1.2.1] – 2023-06-17
### Added
- Universal binary (Intel+AppleSilicon)

### Fixed
- Autoresize issues of UI elements in macOS Ventura
- Flexible width TabBarItem
- Updated About page (removed dead link)


## [1.2.0] – 2022-10-01
### Added
- *UI*: Add option to hide read articles (show only unread)


## [1.1.3] – 2020-12-18
### Fixed
- Recognize YouTube channel URLs in the format `/c/channel-name` 


## [1.1.2] – 2020-11-27
### Fixed
- Fixes hidden color option for marking unread entries. Unread menu entries did use `colorStatusIconTint` instead of `colorUnreadIndicator` (thanks @tchek)
- Workaround for not displaying status bar highlight color in macOS 11.0 (issue #7)


## [1.1.1] – 2020-08-31
### Fixed
- Feed indices weren't updated properly which resulted in empty feed menus (issue: #6)


## [1.1.0] – 2020-01-17
### Added
- *QuickLook*: Thumbnail previews for OPML files (QLOPML v1.3)
- *Status Bar Menu*: Tint menu bar icon with Accent color (macOS 10.14+)

### Fixed
- Resolved Xcode warnings in Xcode 11


## [1.0.2] – 2019-10-25
### Fixed
- *Status Bar Menu*: Preferences could not be opened on macOS 10.15
- *Status Bar Menu*: Menu flickering resulting in a hang on macOS 10.15
- *UI*: Text color in `About` tab


## [1.0.1] – 2019-10-04
### Fixed
- Crash on macOS 10.14 due to a `CGColorRef` null pointer


## [1.0.0] – 2019-10-03
### Added
- App Signing
- Sandboxing & hardened runtime environment
- Associate OPML files (double click and right click actions in Finder)
- Quick Look preview for OPML files
- *Adding feed:* 5xx server errors have a reload button which will initiate a new download with the same URL
- *Adding feed:* Empty feed title will automatically reuse title from xml file (even if xml title changes)
- *Adding feed:* Parser for YouTube channel, user, and playlist URLs
- *Adding feed:* `⌘R` will reload the same URL
- *Settings, Feeds:* `⌘R` will reload the data source
- *Settings, Feeds:* Refresh interval string localizations
- *Settings, Feeds:* Right click menu with edit actions
- *Settings, Feeds:* Drag & Drop feeds from / to OPML file
- *Settings, Feeds:* Drag & Drop feed titles and urls as text
- *Settings, Feeds:* OPML export with selected items only
- *DB*: New table for key-value options (app version, etc.)
- *UI:* Accessibility hints for most UI elements
- *UI*: Custom colors via user defaults plist (bar icon tint & unread indicator)
- *UI:* Unread indicator for groups
- *UI*: Show welcome message upon first usage (empty db)
- Welcome message also adds Github releases feed
- Config URL scheme `barss:` with `open/preferences`, `config/fixcache`, and `backup/show`

### Fixed
- *Adding feed:* Show proper HTTP status code error message (4xx and 5xx)
- *Adding feed:* Show (HTML) extracted failure reason for 5xx server errors
- *Adding feed:* If URLs can't be resolved in the first run (5xx error), try a second time. E.g., `Done` click (issue: #5)
- *Adding feed:* Prefer favicons with size `32x32`
- *Adding feed:* Inserting feeds when offline/paused will postpone download until network is reachable again
- *Adding feed:* `Cancel` will indeed cancel download, not just continue and ignore results
- *Settings, Feeds:* Actions `delete` and `edit` use clicked items instead of selected items
- *Settings, Feeds:* Status info with accurate download count (instead of `Updating feeds …`)
- *Settings, Feeds:* Status info shows `No network connection` and `Updates paused`
- *Settings, Feeds:* After feed edit, run update scheduler immediately
- *Status Bar Menu*: Feed title is updated properly
- *UI:* If an error occurs, show document URL (path to file or web url)
- Comparison of existing articles with nonexistent guid and link
- Don't mark articles read if opening URLs failed
- Don't mark articles read that appear in the middle of a feed (ghost items)
- HTML tag removal keeps structure intact

### Changed
- *Adding feed:* Display error reason if user cancels the creation of a new feed item
- *Adding feed:* Refresh interval hotkeys set to: `⌘1` … `⌘6`
- *Settings, Feeds:* Single add button for feeds, groups, and separators
- *Settings, Feeds:* Always append new items at the end
- *Settings, General*: Moved `Fix cache` button to `About` text section
- *Settings, General*: Changing default feed reader is prohibited within sandbox
- *Settings, General*: [Auxiliary application](https://github.com/relikd/URL-Scheme-Defaults) for changing default feed reader
- *Status Bar Menu*: Show `(no title)` instead of `(error)`
- *Status Bar Menu*: `Update all feeds` will show error alert for broken URLs
- *DB*: Dropping table `FeedIcon` in favor of image files cache
- *UI:* Interface builder files replaced with code equivalent
- *UI:* Mark unread articles with blue dot, instead of tick mark


## [0.9.4] – 2019-04-02
### Fixed
- Article order got mixed up for some feeds (issue: #4)
- If multiple consecutive items reappear in the middle of the feed mark them read

### Changed
- *UI:* Removed checkbox `Start on login`. Use Preferences > Users > Login Items instead.


## [0.9.3] – 2019-03-14
### Added
- Changelog
- *UI:* Show body tag in article tooltip if abstract tag is empty

### Fixed
- `Update all feeds` will shows unread items count properly during update
- Fixed update for feeds where all article URLs point to the same resource (issue: #3)


## [0.9.2] – 2019-03-07
### Added
- Limit number of articles that are displayed in feed menu (issue: #2)

### Fixed
- `⌘Q` in preferences will close the window instead of quitting the application
- Crash when libxml2 encountered and set an error
- libxml2 will ignore lower ascii characters (`0x00`–`0x1F`)


## [0.9.1] – 2019-02-14
### Added
- Mark single article as un/read (hold down option key and click on article)

### Fixed
- Mouse click on `Done` button, while entering a new feed URL, will start download properly
- Use guid url if link is not set (issue: #1)
- Issue with feeds not being detected if XML tags start after 4kb
- Support uppercase schemes (e.g., `FEED:`)
- *UI:* Hide `Next update in -25yrs`
- *UI:* Show alert after click on `Fix Cache`

### Changed
- Auto increment build number
- Removed static images for group icon, default feed icon, and warning icon
- Remove html tags from abstract on save (not on display)


## [0.9] – 2019-02-11
Initial release


[Unreleased]: https://github.com/relikd/baRSS/compare/v1.2.1...HEAD
[1.2.1]: https://github.com/relikd/baRSS/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/relikd/baRSS/compare/v1.1.3...v1.2.0
[1.1.3]: https://github.com/relikd/baRSS/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/relikd/baRSS/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/relikd/baRSS/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/relikd/baRSS/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/relikd/baRSS/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/relikd/baRSS/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/relikd/baRSS/compare/v0.9.4...v1.0.0
[0.9.4]: https://github.com/relikd/baRSS/compare/v0.9.3...v0.9.4
[0.9.3]: https://github.com/relikd/baRSS/compare/v0.9.2...v0.9.3
[0.9.2]: https://github.com/relikd/baRSS/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/relikd/baRSS/compare/v0.9...v0.9.1
[0.9]: https://github.com/relikd/baRSS/compare/2fecf33d3101b0e7888bafee9d3b0f8b9cee30c6...v0.9
