# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project does NOT adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]
### Added
- Adding feed: 5xx server errors have a reload button which will initiate a new download with the same URL
- Adding feed: Cmd+R will reload the same URL
- Settings, Feeds: Cmd+R will reload the data source
- Settings, Feeds: Refresh interval string localizations
- Settings, Feeds: Right click menu with edit actions
- Settings, Feeds: Drag & Drop feeds from / to OPML file
- Settings, Feeds: Drag & Drop feed titles and urls as text
- Accessibility hints for most UI elements

### Fixed
- Adding feed: Show users any 5xx server error response and extracted failure reason
- Adding feed: If URLs can't be resolved in the first run (5xx error), try a second time. E.g., 'Done' click (issue: #5)
- Settings, Feeds: Actions 'delete' and 'edit' use clicked items instead of selected items
- Comparison of existing articles with nonexistent guid and link
- Don't mark articles read if opening URLs failed
- If an error occurs, show document URL (path to file or web url)

### Changed
- Interface builder files replaced with code equivalent
- Settings, Feeds: Single add button for feeds, groups, and separators
- Settings, Feeds: Always append new items at the end
- Adding feed: Display error reason if user cancels the creation of a new feed item
- Adding feed: Refresh interval hotkeys set to: Cmd+1 … Cmd+6


## [0.9.4] - 2019-04-02
### Fixed
- Article order got mixed up for some feeds (issue: #4)
- If multiple consecutive items reappear in the middle of the feed mark them read

### Changed
- Removed 'Start on login'. Use Preferences > Users > Login Items instead.


## [0.9.3] - 2019-03-14
### Added
- Changelog
- UI: Show body tag in article tooltip if abstract tag is empty

### Fixed
- 'Update all feeds' will shows unread items count properly during update
- Fixed update for feeds where all article URLs point to the same resource (issue: #3)


## [0.9.2] - 2019-03-07
### Added
- Limit number of articles that are displayed in feed menu (issue: #2)

### Fixed
- Cmd+Q in preferences will close the window instead of quitting the application
- Crash when libxml2 encountered and set an error
- libxml2 will ignore lower ascii characters (0x00–0x1F)


## [0.9.1] - 2019-02-14
### Added
- Mark single article as un/read (hold down option key and click on article)

### Fixed
- Mouse click on 'Done' button, while entering a new feed URL, will start download properly
- Use guid url if link is not set (issue: #1)
- Issue with feeds not being detected if XML tags start after 4kb
- Support uppercase schemes (e.g., 'FEED:')
- UI: Hide 'Next update in -25yrs'
- UI: Show alert after click on 'Fix Cache'

### Changed
- Auto increment build number
- Removed static images for group icon, default feed icon, and warning icon
- Remove html tags from abstract on save (not on display)


## [0.9] - 2019-02-11
Initial release


[Unreleased]: https://github.com/relikd/baRSS/compare/v0.9.4...HEAD
[0.9.4]: https://github.com/relikd/baRSS/compare/v0.9.3...v0.9.4
[0.9.3]: https://github.com/relikd/baRSS/compare/v0.9.2...v0.9.3
[0.9.2]: https://github.com/relikd/baRSS/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/relikd/baRSS/compare/v0.9...v0.9.1
[0.9]: https://github.com/relikd/baRSS/compare/e1f36514a8aa2d5fb9a575b6eb19adc2ce4a04d9...v0.9
