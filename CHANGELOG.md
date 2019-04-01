# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project does NOT adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]
### Fixed
- Article order got mixed up for some feeds (issue: #4)


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


[Unreleased]: https://github.com/relikd/baRSS/compare/v0.9.3...HEAD
[0.9.3]: https://github.com/relikd/baRSS/compare/v0.9.2...v0.9.3
[0.9.2]: https://github.com/relikd/baRSS/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/relikd/baRSS/compare/v0.9...v0.9.1
[0.9]: https://github.com/relikd/baRSS/compare/e1f36514a8aa2d5fb9a575b6eb19adc2ce4a04d9...v0.9
