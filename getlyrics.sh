#!/usr/bin/env zsh

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

songlyrics() {
    curl -s $1 | hxnormalize -x | hxselect -c 'p.songLyricsV14'
}

metrolyrics() {
    curl -s $1 | hxnormalize -x | hxselect -c -s '\n\n' 'p.verse'
}

genius() {
    curl -sL $1 | hxnormalize -x | hxselect -c 'lyrics.lyrics'
}

azlyrics() {
    mycurl $1 | awk '/Usage of azlyrics.com/{f=1; next}/<!--/{f=0}f==1'
}

lyricsfreak() {
    mycurl $1 | hxnormalize -x | hxselect -c 'div.dn' | \
        sed 's/<a data-tracking..*//g'
}

songmeanings() {
    mycurl $1 | hxnormalize -x | hxselect -c 'div.lyric-box' | \
        awk 'BEGIN{f=1}/<div/{f=0}f'
}

musixmatch() {
    # Add line breaks to lyrics section to prevent one big lump of words.
    mycurl $1 | awk '{print $0"<br></br>"}' | \
        hxnormalize -x | hxselect -c 'p.mxm-lyrics__content'
}

metalkingdom() {
    mycurl $1 | hxselect -c 'div.sly-lyrics'
}

songtexte() {
    curl -s $1 | sed 's/div id/div class/g' | \
        hxnormalize -x | hxselect -c 'div.lyrics'
}

versuri() {
    curl -s $1 | \
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
    local artist=$(rm_extra_spaces $1)
    artist=${artist// /-}
    echo $(db_location)$artist
}

db_song_location() {
    local artist=$(rm_extra_spaces $1)
    local song=$(rm_extra_spaces $2)
    artist=${artist// /-}
    song=${song// /-}
    echo $(db_location)$artist"/"$song
}

save_db() {
    local artist=${1:l}
    local song=${2:l}
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
    local artist=${1:l}
    local song=${2:l}
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
    local clean_tokens=(demo live acoustic remix bonus)
    local extra_str="lyrics"
    local from_file="false"
    local from_folder="false"
    local only_urls="false"
    local only_save="false"
    while getopts ":e:f:d:lrwsh" opt; do
        case $opt in
            e)
                extra_str=$OPTARG
                ;;
            f)
                from_file=$OPTARG
                ;;
            d)
                from_folder=$OPTARG
                ;;
            l)
                only_urls="true"
                ;;
            r)
                clean_tokens=()
                ;;
            w)
                echo $supported_websites
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
    local save_to_db="false"
    # 

    # Get the search string, from one of the sources.
    if [[ ! $from_folder =~ "false" ]]; then # from all media files in folder
        for media_file in $from_folder/**/*.mp3; do
            ($0 -sf $media_file)  # Call self. Saving to db is taken care of.
        done
        exit 0
    elif [[ ! $from_file =~ "false" ]]; then # from media file.
        artist=$(file_artist $from_file)
        song=$(file_song $from_file)
        save_to_db="true"
        search_str=$(printf "%s %s" "$artist" "$song")
    elif [[ $# -eq 0 ]]; then   # from music player
        if cmus_running; then
            artist=$(cmus_artist)
            song=$(cmus_song)
            save_to_db="true"
            search_str=$(printf "%s %s" "$artist" "$song")
        elif moc_running; then
            artist=$(moc_artist)
            song=$(moc_song)
            save_to_db="true"
            search_str=$(printf "%s %s" "$artist" "$song")
        else
            echo "error: No known players available or running."
            exit 1
        fi
    elif [[ $# -eq 1 ]]; then   # from the command line
         search_str=$1
    else                        # no other source available
        echo $help_str
        exit 1
    fi

    # Cleanup the search string.
    for token in $clean_tokens; do
        search_str=$(echo $search_str | sed "s/ *( *$token.*) *//")
    done

    # Try our luck and search own db first. If that's succesful,
    # there's nothing else to do.
    if [[ $save_to_db =~ "true" ]]; then
        lyrics=$(from_db $artist $song)
        if [[ ! -z "${lyrics// /}" ]]; then
            if [[ $only_save =~ "false" ]]; then
                echo $lyrics
            fi
            exit 0
        fi
    fi

    # Otherwise, go to www and get candidate urls containing lyrics.
    urls=(${(@f)$(search_for_urls $search_str $extra_str)})

    # Echo the urls, if that is what is asked for, and exit.
    if [[ $only_urls =~ "true" ]]; then
        echo ${(F)urls}
        exit 0
    fi

    # Extract the lyrics from the first url for which we have a parser.
    for url in $urls; do
        lyrics=$(lyrics_from_url $url)
        if [[ ! -z $lyrics ]]; then
            break
        fi
    done

    # Save lyrics to db, if available and needed.
    if [[ $save_to_db =~ "true" ]] && [[ ! -z "${lyrics// /}" ]]; then
        save_db $artist $song $lyrics
    fi

    # Return the lyrics to stdout, if needed.
    if [[ $only_save =~ "false" ]]; then
        echo -n $lyrics
    fi

    # Or report 'lyrics not found for specified media file' error.
    if [[ ! $from_file =~ "false" ]] && [[ -z "${lyrics// /}" ]]; then
        >&2 echo $from_file
    fi
}

main $@
