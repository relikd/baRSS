# baRSS – *Menu Bar RSS Reader*

![screenshot](doc/screenshot.png)

For nearly a decade I've been using the then free version of [RSS Menu](https://itunes.apple.com/us/app/rss-menu/id423069534). 
However, with the release of macOS Mojave, 32bit applications are no longer supported. 
Furthermore, the currently available version in the Mac App Store was last updated in 2014 (as of writing).

*baRSS* was build from scratch with a minimal footprint in mind. It will be available on the AppStore eventually. 
If you want a feature to be added, drop me an email or create an issue. 
Look at the other issues, in case somebody else already filed one similar. 
If you like this project and want to say thank you drop me a line (or other stuff like money). 
Regardless, I'll continue development as long as I'm using it on my own. 
Admittedly, I've invested way too much time in this project already (1595h+) …


### Why is this project not written in Swift?

Actually, I started this project with Swift. Even without adding much functionality, the app was exceeding the 10 Mb file size. 
Compared to the nearly finished Alpha version with 500 Kb written in Objective-C. 
The reason for that, Swift frameworks are always packed into the final application. 
I decided that this level of encapsulation is a waste of space for such a small application.

With Swift 5 and ABI stability this would not be any issue, but sadly Swift 5 was released after already half of the project was done.
In retrospect it would be much nicer to have it written it like that from the beginning.
But on the other hand, this project is macOS 10.12 compatible.


### 3rd Party Libraries

This project uses a modified version of Brent Simmons [RSXML](https://github.com/brentsimmons/RSXML) for feed parsing. 
RSXML is licensed under a MIT license (same as this project).


Install
-------

Requires macOS Sierra (10.12) or higher.

### Easy way
go to [releases](https://github.com/relikd/baRSS/releases) and downloaded the latest version.

### Build from source

You'll need Xcode and [Carthage](https://github.com/Carthage/Carthage#installing-carthage). The latter is optional, you can build the [RSXML](https://github.com/relikd/RSXML) library from source instead. Carthage just makes it more convenient.
Download and unzip this project, navigate to the root folder and run `carthage bootstrap --platform macOS`. 

That's it. Open Xcode and build the project. Note, there are some compiler flags that append 'beta' to the development release. If you prefer the optimized release version go to `Product > Archive`.


Hidden options
--------------

1) When holding down the option key, the menu will show an item to open only a few unread items at a time. 
This number can be changed with the following Terminal command (default: 10):

```defaults write de.relikd.baRSS openFewLinksLimit -int 10```

2) In preferences you can choose to show 'Short article names'. This will limit the number of displayed characters to 60 (default). 
With this Terminal command you can customize this number:

```defaults write de.relikd.baRSS shortArticleNamesLimit -int 50```

3) If you hold down the option key and click on an article item, you can mark a single item (un-)read.

4) Limit number of displayed articles in feed menu.
**Note:** unread count for feed and group may be different than the unread items inside (if unread articles are omitted).

```defaults write de.relikd.baRSS articlesInMenuLimit -int 40```



ToDo
----

- [ ] Missing
	- [ ] App Icon & UI icons (a shout out to all designers out there!)
	- [ ] Text / UI localization
	- [ ] Feeds with authentication
	- [ ] Sandbox (does work, except for:)
		- [ ] Default RSS application checkbox (disable or other workaround)


- [ ] Nice to have (... on increased demand)
	- [ ] Automatically choose best update interval (e.g., avg)
	- [ ] Sync with online services
	- [ ] Notification Center
	- [ ] Distraction Mode
		- [ ] Distract less: Sleep timer. (e.g., disable updates during working hours)
		- [ ] Distract more: Automatically open feed items
	- [ ] Add support for media types
		- [ ] music / video? (open media player)
		- [ ] Pure image feed? (show images directly in menu)
	- [ ] Per feed / group settings
		- [ ] select launch application (e.g., for podcasts)
		- [ ] exclude unread count from menu bar (e.g., unimportant feeds)
	- [ ] ~~Infinite storage. (load more button)~~
