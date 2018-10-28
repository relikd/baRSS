# baRSS – *Menu Bar RSS Reader*

![screenshot](doc/screenshot.png)

For nearly a decade I've been using the then free version of [RSS Menu](https://itunes.apple.com/us/app/rss-menu/id423069534). However, with the release of macOS Mojave, 32bit applications are no longer supported.

*baRSS* is an open source community project and will be available on the AppStore soon (hopefully); free of charge. Everything is built from the ground up with a minimal footprint in mind.


Why is this project not written in Swift?
-----------------------------------------

Actually, I started this project with Swift. Even without adding much functionality, the app was exceeding the 10 Mb file size. Compared to the nearly finished Alpha version with 500 Kb written in Objective-C. The reason for that, Swift frameworks are always packed into the final application. I decided that this level of encapsulation is a waste of space for such a small application.


3rd Party Libraries
-------------------

This project uses a modified version of Brent Simmons [RSXML](https://github.com/brentsimmons/RSXML) for feed parsing. RSXML is licensed under a MIT license (same as this project).


Current project state
---------------------

The basic functionality is there. Manually added feeds will be downloaded and stored in an SQLite database. The complete management of feeds is there (sorting, grouping, editing, deleting). The bar menu is functional too, including unread count, URL opening and display.


ToDo
----

- [ ] Preferences
	- [x] Choose favorite web browser
		- [x] Show list of installed browsers
	- [ ] Choose status bar icon?
	- [ ] Tick mark feed items based on prefs
	- [ ] Open a few links (# editable)
	- [ ] Performance: Update menu partially
	- [x] Start on login
	- [x] Make it system default application
	- [ ] Display license info (e.g., RSXML)
	- [ ] Short article names
	- [ ] Import / Export (all feeds)
		- [ ] Support for `.opml` format
		- [ ] Append or replace


- [ ] Status menu
	- [ ] Update menu header after mark (un)read
	- [ ] Pause updates functionality
	- [x] Update all feeds functionality
	- [ ] Hold only relevant information in memory


- [ ] Edit feed
	- [ ] Show statistics
		- [ ] How often gets the feed updated (min, max, avg)
		- [ ] Automatically choose best interval?
		- [ ] Show time of next update
	- [x] Auto fix 301 Redirect or ask user
	- [ ] Make `feed://` URLs clickable
	- [ ] Feeds with authentication
	- [ ] Show proper feed icon
		- [ ] Download and store icon file


- [ ] Other
	- [ ] App Icon
	- [ ] Translate text to different languages
	- [x] Automatically update feeds with chosen interval
		- [x] Reuse ETag and Modification date
		- ~~[ ] Append only new items, keep sorting~~
		- [x] Delete old ones eventually
		- [x] Pause on internet connection lost
	- [ ] Download with ephemeral url session?
	- [ ] Purge cache
		- [ ] Manually or automatically
		- [ ] Add something to restore a broken state
	- [ ] Code Documentation (mostly methods)
	- [ ] Add Sandboxing
		- [ ] Disable Startup checkbox (or other workaround)


- [ ] Additional features
	- [ ] Sync with online services!
	- [ ] Notification Center
	- [ ] Sleep timer. (e.g., disable updates during working hours)
	- [ ] Pure image feed? (show images directly in menu)
	- [ ] Infinite storage. (load more button)
	- [ ] Automatically open feed items?
	- [ ] Per feed launch application (e.g., for podcasts)
		- [ ] Per group setting to exclude unread count from menu bar

