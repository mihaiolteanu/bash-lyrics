#!/usr/bin/env zsh

# Get lyrics for the currently playing song in cmus.
# To display the lyrics in stumpwm, for example, define a new command
# (defcommand player-lyrics () ()
#     (message-no-timeout (run-shell-command "/path/to/lyrics.sh" t)))

db="$HOME/lyrics"

get-cmus-tag() {
    local cmus_tag=$1
    cmus-remote -Q | grep $cmus_tag | sed "s/$cmus_tag //"
}

get-artist-from-file() {
    local file=$1
    local artist=$(id3v2 -l $file | awk '/TPE1/{$1=""; $2=""; $3=""; print $0}' | sed -e 's/  \+//g')
    echo $artist
}

get-title-from-file() {
    local file=$1
    local title=$(id3v2 -l $file | awk '/TIT2/{$1=""; $2=""; $3=""; print $0}' | sed -e 's/  \+//g')
    echo $title
}

# If media file given as argument, get the artist name from there,
# otherwise get it from cmus. Other source could be added here.
get-artist() {
    local file=$1
    local artist
    if [[ ! -z $file ]]; then
        artist=$(get-artist-from-file $file)
    else
        artist=$(get-cmus-tag "tag artist")
    fi
    echo $artist
}

# Same as for get-artist.
get-title() {
    local file=$1
    local title
    if [[ ! -z $file ]]; then
        title=$(get-title-from-file $file)
    else
        title=$(get-cmus-tag "tag title")
    fi
    echo $title
}

# URL queries can't contain spaces.
prepare-for-query() {
    local result=$(echo $1 | sed "s/ /-/g")
    echo ${result:l}            # lowercase
}

# Location of the lyrics in the db for this artist and song.
get-lyrics-location() {
    local artist=$1
    local title=$2
    local location=$db"/"$artist"/"$title
    echo $location
}

# Location of the artist in the db.
get-artist-location() {
    local artist=$1
    local location=$db"/"$artist
    echo $location
}

# Update the db with these lyrics, if needed.
save-lyrics-db() {
    local artist=$1
    local title=$2
    local lyrics=$3
    local location=$(get-lyrics-location $artist $title)
    if [[ ! -a $location ]]; then
        mkdir -p $(get-artist-location $artist)
        echo $lyrics > $location
    fi        
}

# Fetch the lyrics from the database, if they exist.
get-db-lyrics() {
    local artist=$1
    local title=$2
    local lyrics=""
    local location=$(get-lyrics-location $artist $title)
    if [[ -a $location ]]; then
        lyrics=$(<$location)
    fi
    echo $lyrics
}

# Get lyrics from makeitpersonal.
get-mp-lyrics() {
    local artist=$1
    local title=$2
    local template="https://makeitpersonal.co/lyrics?artist=%s&title=%s"
    local url=$(printf $template $artist $title)
    local lyrics=$(curl -s $url)
    if [[ $lyrics =~ "Sorry, We don't have lyrics for this song yet" ]]; then
        lyrics=""              # Bad luck this time.
    fi
    echo $lyrics
}

# Get lyrics from songlyrics.com
get-sl-lyrics() {
    local artist=$1
    local title=$2
    local template="http://www.songlyrics.com/%s/%s-lyrics/"
    local url=$(printf $template $artist $title)
    local lyrics=$(curl -s $url | hxnormalize -x | \
                   hxselect -c 'p.songLyricsV14' |     \
                   # Remove all tags and leading spaces.
                   sed -e 's/<[^>]*>//g' | sed -e 's/^[[:space:]]*//')
    if [[ $lyrics =~ "Sorry, we have no" ]]; then
        lyrics=""
    fi
    echo $lyrics
}

get-lyrics() {
    local artist=$1
    local title=$2
    local lyrics=""
    # Try multiple sources, pick the first that returns a result or
    # fail in agony. (command subtitution removes newline chars,
    # quoting the whole thing prevents it)
    lyrics=$(get-db-lyrics $artist $title)
    lyrics="${lyrics:-$(get-mp-lyrics $artist $title)}"
    lyrics="${lyrics:-$(get-sl-lyrics $artist $title)}"
    if [[ ! -z "${lyrics// }" ]]; then
        save-lyrics-db $artist $title $lyrics
    fi
    echo $lyrics
}

main() {
    local echo_lyrics=$1
    local raw_artist=$2
    local raw_title=$3

    # Raw values only used for printing, for all other activities I
    # need a nice format without spaces.
    local artist=$(prepare-for-query $raw_artist)
    local title=$(prepare-for-query $raw_title)
    local lyrics=$(get-lyrics $artist $title)
    if [[ $echo_lyrics =~ "true" ]]; then
         printf "%s - %s \n %s" $raw_artist $raw_title $lyrics
    fi
}

# -e "false" disables the printing of lyrics to stdout; useful if run
# only for saving the lyrics
# -f get the artist and song name from the file (mp3) given as argument
# -d save the lyrics for all the mp3 files in the folder given as argument
echo_lyrics=(e "true")
zparseopts -K -- e:=echo_lyrics f:=from_file d:=from_folder

if [[ ! -z $from_folder[2] ]]; then
    count=0
    for file in $from_folder[2]/**/*.mp3; do
        main "false" "$(get-artist $file)" "$(get-title $file)"
        echo $count > /tmp/lyricslog
        count=$((count+1))
    done
else
    main $echo_lyrics[2] "$(get-artist $from_file[2])" "$(get-title $from_file[2])"
fi
