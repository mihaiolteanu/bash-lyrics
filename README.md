# lyrics - All the lyrics in one place.
Download and save the lyrics for the current playing song and interactively search and play the song from the saved database.

## features
- Multiple lyrics websites supported:
![screenshot1488633504](https://cloud.githubusercontent.com/assets/8273519/23579068/e18b19f2-00ed-11e7-8078-2c4cf3252cfe.png)
- Download and save the lyrics for the current playing song (cmus and moc supported)
![screenshot1488637361](https://cloud.githubusercontent.com/assets/8273519/23579480/e420be0c-00f6-11e7-82d1-3ee5ec4ebf74.png)
- Alternatively, download the lyrics for a specified media file or for all media files in a 
  folder (useful for creating a lyrics database)
![screenshot1488637443](https://cloud.githubusercontent.com/assets/8273519/23579484/1058b254-00f7-11e7-819a-b9051b5aa240.png)
- Run in daemon mode so that the lyrics are automatically downloaded when you add new songs
  to your music folder
![screenshot1488633275](https://cloud.githubusercontent.com/assets/8273519/23579047/583fc076-00ed-11e7-98a8-f96c9ea0badb.png)
- Select which websites to search first and in which order
![screenshot1488637524](https://cloud.githubusercontent.com/assets/8273519/23579491/3cf6c27e-00f7-11e7-9a08-6b7bd8d9abe8.png)
- Free-form search: search the lyrics as you would on google
![screenshot1488633027](https://cloud.githubusercontent.com/assets/8273519/23579024/c73be76c-00ec-11e7-9621-d7ae4249ff39.png)
- Remove live, demo and other such strings from the song title for a higher success rate
- Outputs the file name to stderr if no lyrics were found. Can be used to generate a log when searching for lyrics in folders

## extra features for zaw
- Install the [zaw](https://github.com/zsh-users/zaw) lyrics plugin and you can search all the lyrics from the database with a
  live filter using `zaw-lyrics-search`. Accepting the search plays the song in your media player (cmus and moc
  supported). Alternatively, search the song on youtube
![screenshot1488632894](https://cloud.githubusercontent.com/assets/8273519/23579008/7733f96c-00ec-11e7-9d96-a9108bc8c9e6.png)
- Search and filter artists from the database interactively using `zaw-artist-search`. Selecting the artist opens
  the the artist page on last.fm
- Any other zaw magic to be had?!

## install
### dependencies
- Arch Linux:

``` shell
    sudo pacman -S id3v2 inotify-tools
    yaourt html-xml-utils
```
- Ubuntu:

``` shell
    sudo apt-get install id3v2 html-xml-utils inotify-tools
```

### the application proper

``` shell
    git clone https://github.com/mihaiolteanu/lyrics
    cd lyrics
    ./install.zsh
```

### zaw plugin
- antigen

``` shell
    antigen bundle zsh-users/zaw
    antigen bundle mihaiolteanu/lyrics
```

## usage and suggestions
The `lyrics` application creates a local database where it saves the lyrics after each succesful search, minus the free-form
searches (google-like) as in these cases, the artist and song name are not known with 100% certainty.
Google searches would have been best, as it speeds up the process tremendously, but google doesn't want that. Use it at your
own peril as you might get blacklisted from too many searches. I think darklyrics and azlyrics might do that too. The 
alternative is to search each website in turn, until a result is found. This is slow, so pick your most likely sources
beforehand, using the -w option, or by exporting the `LYRICS_WEBSITES` enviornment variable. See the `-h`(help) option for
info.

If you're using the zaw plugin, a keybinding is really helpful for quick access:
``` shell
bindkey '^xml' zaw-lyrics-search
bindkey '^xma' zaw-artist-search
```
That's Ctrl+x m l or a.
While filtering, press tab key for alternate actions (like youtube search).

If you're using [stumpwm](https://stumpwm.github.io/), you can display the lyrics for the current playing song in a nice little window:
![screenshot1488637615](https://cloud.githubusercontent.com/assets/8273519/23579508/85f833ae-00f7-11e7-98d0-96f6814f4177.png)

Add this to your `~/.stump.d/init.lisp` file, for example:
``` common-lisp
(defcommand player-lyrics () ()
            (message-no-timeout (run-shell-command "lyrics" t)))
```

Start the daemon at system startup. I'm using stumpwm init files again for this purpose:
``` common-lisp
(run-shell-command "lyrics -d ~/music")
```

### issues
- Still buggy
- Doesn't play well with special characters
- Some lyrics websites might return garbage and that is what is saved in the database (not good)
- Parsing errors galore, including missing html tags, empty variables and the like leading to errors from awk and friends
