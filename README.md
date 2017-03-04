# lyrics - All the lyrics in one place.
Command line tool to download and save the lyrics for the current playing song and 
interactively searching and playing the song from the database.

## features
- Multiple lyrics websites supported, including azlyrics, metrolyrics, darklyrics and more
- Download and save the lyrics for the current playing song (cmus and moc supported)
- Alternatively, download the lyrics for a specified media file or for all media files in a
  folder (useful for creating a lyrics database)
- Run in daemon mode so that the lyrics are automatically downloaded when you add new music
  to the specified folder
- Select which websites to search first and in which order
- Free-form search: search the lyrics as you would on google
- Remove live, demo and other such strings from the song title for a higher success rate

## extra features for zaw
- Install the zaw lyrics plugin and you can search all the lyrics from the database with a
  live filter. Accepting the search plays the song in your media player (cmus and moc
  supported). Alternatively, search the song on youtube
- Search and filter artists from the database interactively. Selecting the artist opens the
  the artist page on last.fm
- Any other zaw magic to be had? I'm open to suggestions.

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

### extra zaw functionality
- antigen

``` shell
    antigen bundle mihaiolteanu/lyrics
```

## examples


