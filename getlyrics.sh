#!/usr/bin/env zsh

all_lyrics_websites="metrolyrics songlyrics darklyrics makeitpersonal genius \
                     azlyrics lyricsfreak musixmatch songtexte versuri"
# If lyrics envvar is not exported by user, consider all the sources,
# otherwise split the envvar string into an array. The -w option, if
# specified, makes both both these assignments obsolete.
: ${(A)LYRICS_WEBSITES:=${=all_lyrics_websites}}
: ${(A)LYRICS_WEBSITES::=${=LYRICS_WEBSITES}}

help_str="$0 - All the lyrics in one place

Usage: $0 [-efdlrwsh] [string file folder]

       Search and save song lyrics using one of the sources:
       string - A string containing artist name, song name, part of the searched 
                lyrics or any combination of the above. This is the only option
                that does *not* save the lyrics for later retrieval.
       file   - A media file containing artist/song title info (mp3 supported)
       folder - A folder containing media file(s).
              - With no source given, get the info from the media player, if 
                supported and running (cmus and moc supported).

Options:
    -e <str> Replace the \"lyrics\" string that is appended by default to the
       search string. This can help increase the chance of finding the lyrics.

    -f <file> Extract the search string from a media file. If lyrics are found, 
       save them to a local database. If the lyrics are already in the database,
       return those instead.

    -d <folder> Similar to -f, but for all the media files in that folder, 
       recursively. This implies the -s option as well.

    -l Only list the candidate urls, but do not extract the lyrics from any of them.

    -r Raw mode. Do not remove tokens like \"live\", \"acoustic version\", etc.
       from the search string. These tokens are removed by default from the
       search_string to increase the chance of finding the lyrics.

    -w List the websites from which the application can extract the lyrics.

    -s Only save the lyrics but do not print them to stdout. If the lyrics already
       exist in the database, do nothing.

    -h Print this help and exit"

supported_websites="www.songlyrics.com
www.metrolyrics.com
www.genius.com
www.azlyrics.com
www.lyricsfreak.com
www.songmeanings.com
www.musixmatch.com
www.metalkingdom.net
www.songtexte.com (german)
www.versuri.ro (romanian)"

mycurl() {
    local url=$1
    local user_agent="User-Agent: Mozilla/5.0 (Macintosh; \ 
        Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML,\
        like Gecko) Chrome/44.0.2403.89 Safari/537."
    curl -sLH $user_agent $1
}

clean_string() {
    local dirty=$1
    # Remove all tags, leading/trailing spaces and duplicate empty lines.
    echo $dirty | sed -e 's/<[^>]*>//g' | \
        sed 's/^ *//; s/ *$//' | cat -s
}

rm_extra_spaces() {
    echo $1 | sed 's/^[[:space:]]*//; s/[[:space:]] *$//;
                   s/[[:space:]][[:space:]]*/ /g'
}

# Cleanup an artist or song item.
clean_search_item() {
    local cleanup_tokens=(demo live acoustic remix bonus)
    local item=$1
    item=$(rm_extra_spaces $item)    # no extra spaces
    item=${item//[.,?!]/}            # remove special chars
    item=${item:l}                   # lowercase
    for token in $cleanup_tokens; do # remove tokens
        item=$(echo $item | sed "s/ *( *$token.*) *//")
    done
    echo $item
}

makeitpersonal() {
    local artist title lyrics url template error_str
    if [[ $1 =~ "http" ]]; then
        url=$1
    else
        artist=${1// /-}
        title=${2// /-}
        template="https://makeitpersonal.co/lyrics?artist=%s&title=%s"
        url=$(printf $template $artist $title)
    fi
    lyrics=$(curl -s $url)
    error_str=("Sorry, We don't have lyrics for this song yet" \
               "title is empty" \
               "artist is empty")
    if [[ $error_str =~ $lyrics ]]; then
        lyrics=""
    fi
    echo -n $lyrics
}

songlyrics() {
    local artist title lyrics url template
    if [[ $1 =~ "http" ]]; then
        url=$1
    else
        artist=${1// /-}
        title=${2// /-}
        template="http://www.songlyrics.com/%s/%s-lyrics/"
        url=$(printf $template $artist $title)
    fi
    lyrics=$(curl -s $url | hxnormalize -x | hxselect -c 'p.songLyricsV14')
    if [[ $lyrics =~ "Sorry, we have no" ]]; then
        lyrics=""
    fi
    echo -n $lyrics
}

metrolyrics() {
    local artist title lyrics url template
    if [[ $1 =~ "http" ]]; then
        url=$1
    else
        artist=${1// /-}
        title=${2// /-}
        template="http://www.metrolyrics.com/%s-lyrics-%s.html"
        url=$(printf $template $title $artist)
    fi
    curl -s $url | hxnormalize -x | hxselect -c -s '\n\n' 'p.verse'
}

genius() {
    local artist title url template
    if [[ $1 =~ "http" ]]; then
        url=$1
    else
        artist=${1// /-}
        title=${2// /-}
        template="https://genius.com/%s-%s-lyrics"
        url=$(printf $template $artist $title)
    fi
    curl -sL $url | hxnormalize -x  | hxselect -ci 'lyrics.lyrics'
}

azlyrics() {
    local artist title url template
    if [[ $1 =~ "http" ]]; then
        url=$1
    else
        artist=${1// /}
        title=${2// /}
        template="http://www.azlyrics.com/lyrics/%s/%s.html"
        url=$(printf $template $artist $title)
    fi
    mycurl $url | awk '/Usage of azlyrics.com/{f=1; next}/<!--/{f=0}f==1'
}

lyricsfreak() {
    local artist title raw_title url template
    local artist_template lyrics_template suburl
    if [[ $1 =~ "http" ]]; then
        url=$1
    else
        artist=${1// /+}
        title=${2// /+}
        raw_title=$2
        artist_template="http://www.lyricsfreak.com/%s/%s/"
        lyrics_template="http://www.lyricsfreak.com/%s"
        url=$(printf $artist_template ${artist:0:1} $artist)
        suburl=$(mycurl $url | grep -i "$raw_title" | hxwls)
        url=$(printf $lyrics_template $suburl)
    fi
    mycurl $url | hxnormalize -x | hxselect -c 'div.dn' | \
        sed 's/<a data-tracking..*//g'
}

musixmatch() {
    local artist title url template
    if [[ $1 =~ "http" ]]; then
        url=$1
    else
        artist=${1// /-}
        title=${2// /-}
        template="https://www.musixmatch.com/lyrics/%s/%s"
        url=$(printf $template $artist $title)
    fi
    # Add line breaks to lyrics section to prevent one big lump of words.
    mycurl $url | awk '{print $0"<br></br>"}' | \
        hxnormalize -x | hxselect -c 'p.mxm-lyrics__content'
}

darklyrics() {
    local artist title raw_title lyrics url
    local albums_template lyrics_template album awk_filter
    if [[ $1 =~ "http" ]]; then
        url=$1
    else
        artist=${1// /}
        title=${2// /}
        raw_title=$2
        albums_template="http://www.darklyrics.com/%s/%s.html"
        lyrics_template="http://www.darklyrics.com/lyrics/%s/%s.html"
        url=$(printf $albums_template ${artist:0:1} $artist)
        album=$(mycurl $url | grep "href" | grep -i "$raw_title" | \
                head -n1 | hxwls)
        if [[ ! -z "${album// }" ]]; then
            album=${$(basename $album):r}
            url=$(printf $lyrics_template $artist $album)
        fi
    fi
    awk_filter=$(printf 'BEGIN{IGNORECASE=1}/h3..*%s/{f=1;next}/h3/{f=0}f' \
                         $raw_title)
    mycurl $url | awk $awk_filter
}

songtexte() {
    local artist title raw_title lyrics url
    local search_template lyrics_template suburl
    if [[ $1 =~ "http" ]]; then
        url=$1
    else
        artist=${1// /-}
        title=${2// /-}
        raw_title=$2
        search_template="http://www.songtexte.com/search?q=%s+%s&c=all"
        lyrics_template="http://www.songtexte.com/%s"
        url=$(printf $search_template $artist $title)
        suburl=$(curl -s $url | grep -i "<span>$raw_title<\/span>" | hxwls | head -n1)
        url=$(printf $lyrics_template $suburl)
    fi 
    lyrics=$(curl -s $url | sed 's/div id/div class/g' | \
                 hxnormalize -x | hxselect -c 'div.lyrics')
    if [[ $lyrics =~ "Leider kein Songtext" ]]; then
        lyrics=""
    fi
    echo -n $lyrics
}

versuri() {
    local artist title raw_artist raw_title lyrics url template
    local main_template search_template lyrics_template suburl
    if [[ $1 =~ "http" ]]; then
        url=$1
    else
        artist=${1// /+}
        title=${2// /+}
        raw_artist=$1
        raw_title=$2
        main_template="http://www.versuri.ro/cat/%s.html"
        artist_template="http://www.versuri.ro%s"
        lyrics_template="http://www.versuri.ro%s"
        url=$(printf $main_template ${artist:0:1})
        suburl=$(curl -s $url | grep -i "$raw_artist" | hxwls)
        url=$(printf $artist_template $suburl)
        suburl=$(curl -s $url | grep -i "$raw_title" | hxwls)
        url=$(printf $lyrics_template $suburl)
    fi
    curl -s $url | \
        # Skip all the div and include everything between index0f and BOTTOM-CENTER
        awk '/div/{next}/var index0f/{f=1;next}/BOTTOM-CENTER/{print;f=0}f' | \
        hxnormalize -x | hxselect -c 'p'
}

# Get the best mached urls from the search string.
search_for_urls() {
    local search_str=$1
    local extra_str=$2
    local template="https://www.google.com/search?q=%s+%s"
    local search_url=$(printf $template ${search_str// /+} $extra_str)
    mycurl $search_url | hxnormalize -x | hxselect 'h3.r' | hxwls
}

# Return the lyrics from the given url if there is a parser for that domain.
lyrics_from_url() {
    local url=$1
    local lyrics=""
    local domain=$(echo $url | \
        awk -F// '{gsub("www.", "", $2); print $2}' | awk -F. '{print $1}')
    if typeset -f $domain >/dev/null; then
        lyrics=$($domain $url)
    fi
    clean_string $lyrics
}

lyrics_from_artist_song() {
    local artist=$1
    local song=$2
    local sources=$LYRICS_WEBSITES
    for src_fn in $sources; do
        local lyrics=$($src_fn $artist $song )
        if [[ ! -z "${lyrics// /}" ]]; then
            break
        fi
    done
    clean_string $lyrics
}

# Return error if cmus is not available or it's not playing at the moment.
cmus_running() {
    local str=$(cmus-remote -Q 2>/dev/null)
    if [[ -z ${str// /} ]]; then
        return 1
    fi
    local statuss=$(echo $str | awk -F"status " '/status/{print $2}')
    if [[ $statuss =~ "stopped" ]]; then
        return 1
    fi
    return 0
}

cmus_artist() {
    cmus-remote -Q | awk -F"tag artist " '/tag artist/{print $2}'
}

cmus_song() {
    cmus-remote -Q | awk -F"tag title " '/tag title/{print $2}'
}

moc_running() {
    local str=$(mocp -i 2>/dev/null)
    if [[ -z ${str// /} ]]; then
        return 1
    fi
    local statuss=$(echo $str | awk -F"State: " '/State/{print $2}')
    if [[ $statuss =~ "STOP" ]]; then
        return 1
    fi
    return 0
}

moc_artist() {
    mocp -i 2>/dev/null | awk -F"Artist: " '/Artist/{print $2}'
}

moc_song() {
    mocp -i 2>/dev/null | awk -F"SongTitle: " '/SongTitle/{print $2}'
}


# Retrieve artist/song search string from a media file.
file_tag() {
    local file=$1
    local tag=$2
    local id3tags=$(id3v2 -l $file)
    # Make sure the file has id3v2 tags.
    if [[ $id3tags =~ "No ID3v2 tag" ]]; then
        id3v2 --convert $file > /dev/null
    fi
    local pattern=$(printf '/%s/{print $2}' $tag)
    id3v2 -l $file | awk -F": " $pattern
}

file_artist() {
    file_tag $1 "(TPE1|TP1)"
}

file_song() {
    file_tag $1 "(TIT2|TT2)"
}


# Database functions.
db_location() {
    echo "$HOME/lyrics/"
}

db_artist_location() {
    local artist=${1// /-}
    echo $(db_location)$artist
}

db_song_location() {
    artist=${1// /-}
    song=${2// /-}
    echo $(db_location)$artist"/"$song
}

save_db() {
    local artist=$1
    local song=$2
    local lyrics=$3
    if [[ -z "${artist// /}" ]] || [[ -z "${song// /}" ]] || [[ -z "${lyrics// /}" ]]; then
        return                  # No point in saving gibberish.
    fi
    local location=$(db_song_location $artist $song)
    if [[ ! -a $location ]]; then
        mkdir -p $(db_artist_location $artist)
        echo $lyrics > $location
    fi
}

from_db() {
    local artist=$1
    local song=$2
    local lyrics=""
    if [[ -z "${artist// /}" ]] || [[ -z "${song// /}" ]]; then
        return
    fi
    local location=$(db_song_location $artist $song)
    if [[ -a $location ]]; then
        lyrics=$(<$location)
    fi
    echo $lyrics
}


main () {
    local extra_str="lyrics"
    local only_save="false"
    while getopts ":e:lrw:Wsh" opt; do
        case $opt in
            e)
                extra_str=$OPTARG
                ;;
            r)
                clean_tokens=()
                ;;
            w)
                : ${LYRICS_WEBSITES::=$OPTARG}
                ;;
            W)
                echo ${(F)LYRICS_WEBSITES}
                exit 0
                ;;
            s)
                only_save="true"
                ;;
            \?)
                echo $help_str
                exit 1
                ;;
            h)
                echo $help_str
                exit 0
                ;;
        esac
    done
    shift $((OPTIND-1))

    local search_str urls artist song
    local lyrics=""
    # db is only used when search string is from file or folder,
    # otherwise the artist and song strings are not reliable
    local reliable_src="true"

    # Get the search string, from one of the sources.
    if [[ $# -eq 0 ]]; then     # from music player
        if cmus_running; then
            artist=$(cmus_artist)
            song=$(cmus_song)
        elif moc_running; then
            artist=$(moc_artist)
            song=$(moc_song)
        else
            echo "error: No known players available or running."
            exit 1
        fi
    elif [[ $# -eq 1 ]]; then
        if [[ -d $1 ]]; then    # from folder
            for media_file in $1/**/*.mp3; do
                ($0 -s $media_file)  # Call self. Saving to db is taken care of.
            done
            exit 0
        elif [[ -a $1 ]]; then  # from file
            artist=$(file_artist $1)
            song=$(file_song $1)
        else                    # from cli parameter string
            reliable_src="false"
            search_str=$1
        fi
    else                        # no other sources available
        echo $help_str
        exit 1
    fi

    artist=$(clean_search_item $artist)
    song=$(clean_search_item $song)

    # If lyrics not found in the db, save them, otherwise, copy them.
    if [[ $reliable_src =~ "true" ]]; then
        lyrics=$(from_db $artist $song)
        if [[ -z "${lyrics// /}" ]]; then
            lyrics=$(lyrics_from_artist_song $artist $song)
            # Save lyrics to db, if available and needed.
            if [[ ! -z "${lyrics// /}" ]]; then
                save_db $artist $song $lyrics
            fi
        fi
    else
        # Only use a search engine for unreliable sources (artist and/or
        # song name are not necessarly known or cannot be split apart from
        # one another). The source in this case is usually a cli string.

        # Use a search engine to get candidate urls.
        urls=(${(@f)$(search_for_urls $search_str $extra_str)})

        # Extract the lyrics from the first url for which we have a parser.
        for url in $urls; do
            lyrics=$(lyrics_from_url $url)
            if [[ ! -z $lyrics ]]; then
                break
            fi
        done
    fi

    # Return the lyrics to stdout, if needed.
    if [[ $only_save =~ "false" ]]; then
        echo -n $lyrics
    fi

    # Or report 'lyrics not found for specified media file' error.
    if [[ -z "${lyrics// /}" ]]; then
        >&2 echo $1
    fi
}

main $@
