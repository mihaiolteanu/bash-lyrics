# lyrics - All the lyrics in one place.
Command line tool to grab the lyrics from the current playing song (cmus or moc), 
a media file or for the whole folder. Multiple lyrics website parsers available, 
including metrolyrics, darklyrics, azlyrics and more.

## features
- Save the lyrics to local database for future searches
- Run in daemon mode to search lyrics when media files are added to the watched folder
- Over 10 lyrics websites supported and more to come. Create an issue if you have a wish
- Get the lyrics for the current playing song (cmus and moc supported)
- Get the lyrics for a specified media file or for all media files in a folder
- Select which websites to search first and in which order
- Free-form search: search the lyrics as you would on google
- Remove live, demo and other such strings from the song title for a higher success rate

## extra features for zaw:
- Search and filter the lyrics from the local database interactively. Selecting the lyrics
  plays the song in your music player (cmus supported). Alternate action finds the video
  and plays it on youtube
- Search and filter artists from the database interactively. Selecting the artist opens the
  the artist page on last.fm
- Any other zaw magic to be had? I'm open to suggestions.

## install
### dependencies
- Arch Linux:
    sudo pacman -S id3v2 inotify-tools
    yaourt html-xml-utils
- Ubuntu:
    sudo apt-get install id3v2 html-xml-utils inotify-tools
### lyrics application
    git clone https://github.com/mihaiolteanu/lyrics
    cd lyrics
    ./install
### zaw functionality
- antigen
    antigen bundle mihaiolteanu/lyrics

## examples


