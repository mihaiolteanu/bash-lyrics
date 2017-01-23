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

get-artist() {
    local artist=$(get-cmus-tag "tag artist")
    echo $artist
}

get-title() {
    local title=$(get-cmus-tag "tag title")
    echo $title
}

# URL queries can't contain spaces.
prepare-for-query() {
    local result=$(echo $1 | sed "s/ /+/g")
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

# Get lyrics from makeitpersonal.
get-mp-lyrics() {
    local artist=$1
    local title=$2
    local source="https://makeitpersonal.co/lyrics?artist=%s&title=%s"
    local request=$(printf $source $artist $title)
    local lyrics=$(curl -s $request)
    if [[ $lyrics =~ "Sorry, We don't have lyrics for this song yet" ]]; then
        lyrics=""              # Bad luck this time.
    fi
    echo $lyrics
}

# Get lyrics from darklyrics.
get-dl-lyrics() {
    local artist=$1
    local title=$2
    local raw_title=${title//+/ }
    local base="http://www.darklyrics.com/"
    local general=$base"%s/%s.html" # Page with all artist albums.
    local final=$base"lyrics/%s/%s.html" # Page with one album and lyrics links.
    local request=""
    local lyrics=""
    # Darklyrics remove the spaces from artist/song query string completly.
    artist=${artist//+/}
    title=${title//+/}
    request=$(printf $general ${artist:0:1} $artist)
    artist_resp=$(curl -sH "User-Agent: Mozilla/5.0" $request)
    album=$(echo $artist_resp | grep "href" | grep -i $raw_title | head -n1 | hxwls)
    if [[ ! -z "${album// }" ]]; then
        album=${$(basename $album):r}
        request=$(printf $final $artist $album)
        lyrics_resp=$(curl -sH "User-Agent: Mozilla/5.0" $request)
        awk_filter=$(printf 'BEGIN{IGNORECASE=1}/h3..*%s/{f=1;next}/h3/{f=0}f' $raw_title)
        lyrics=$(echo $lyrics_resp | awk $awk_filter | sed -e 's/<[^>]*>//g')
    fi
    echo $lyrics
}

# Get lyrics from songlyrics.com
get-sl-lyrics() {
    local artist=${1// /-}
    local title=${2// /-}
    local source="http://www.songlyrics.com/%s/%s-lyrics/"
    local request=$(printf $source $artist $title)
    local lyrics=$(curl -s $request | hxnormalize -x | \
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
    # Try multiple sources, pick the first that returns a result or
    # fail in agony. (command subtitution removes newline chars,
    # quoting the whole thing prevents it)
    local lyrics="${$(get-db-lyrics $artist $title):-${$(get-mp-lyrics $artist $title):-${$(get-dl-lyrics $artist $title):-""}}}"
    if [[ ! -z "${lyrics// }" ]]; then
        save-lyrics-db $artist $title $lyrics
    fi
    echo $lyrics
}

main() {
    local raw_artist=$(get-artist)
    local raw_title=$(get-title)
    # Raw values only used for printing, for all other activities I
    # need a nice format without spaces.
    local artist=$(prepare-for-query $raw_artist)
    local title=$(prepare-for-query $raw_title)
    local lyrics=$(get-lyrics $artist $title)
    printf "%s - %s \n %s" $raw_artist $raw_title $lyrics
}

main
#get-dl-lyrics $1 $2
