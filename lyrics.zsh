#!/usr/bin/env zsh

all_lyrics_websites="metrolyrics songlyrics darklyrics makeitpersonal genius \
                     azlyrics lyricsfreak musixmatch songtexte versuri"
# If lyrics envvar is not exported by user, consider all the sources,
# otherwise split the envvar string into an array. The -w option, if
# specified, makes both both these assignments obsolete.
: ${(A)LYRICS_WEBSITES:=${=all_lyrics_websites}}
: ${(A)LYRICS_WEBSITES::=${=LYRICS_WEBSITES}}

SELF=$(basename "$0")
help_str="$SELF - All the lyrics in one place

Usage: $SELF [-efdlrwsh] [string file folder]

       Search and save song lyrics using one of the sources:
       string - A free-form string containing artist name, song name, part of
                the searched lyrics or any combination of the above. This is
                the only option that does *not* save the lyrics for later retrieval.
       file   - A media file containing artist/song title info (mp3 supported)
       folder - A folder containing media file(s).
              - With no source given, get the info from the media player, if 
                supported and running (cmus and moc supported).

Options:
    -d <folder> Run in daemon mode. Monitor the given folder for new media files
       and update the database with the lyrics, if found.
    -e <str> Replace the \"lyrics\" string that is appended by default to the
       search string. This can help increase the chance of finding the lyrics. Only
       has an effect for free-form searches

    -r Raw mode. Do not remove tokens like \"live\", \"acoustic version\", etc.
       from the song titles. These tokens are removed by default from the
       song titles to increase the chance of finding the lyrics.

    -w <str1 str2 ...> Manually select the order and the name of the websites used
       to extract the lyrics from. Alternatively, the LYRICS_WEBSITES
       variable can be exported. (Example: $SELF -w \"metrolyrics azlyrics\")

    -W List all the websites from which the application can extract the lyrics.

    -s Only save the lyrics but do not print them to stdout. If the lyrics already
       exist in the database, do nothing. Enabled by default when the source is
       a folder.

    -g Display websites usage statistics.

    -G Clear websites usage statistics.

    -l Display the website where the last lyrics were found.

    -h Print this help and exit"

# Extract the contents of any html tag. Pure magic!
alias hxmagic="hxnormalize -x | hxselect -c"

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
    echo $dirty | sed -e 's/<[^>]*>//g' | sed 's/^ *//; s/ *$//' | cat -s
}

rm_extra_spaces() {
    echo $1 | sed 's/^[[:space:]]*//; s/[[:space:]] *$//;
                   s/[[:space:]][[:space:]]*/ /g'
}

# Cleanup an artist or song item.
clean_search_item() {
    local cleanup_tokens=(demo live acoustic remix bonus)
    local item=$1
    item=${item//[.,?!\/\']/}        # remove special chars
    item=$(rm_extra_spaces $item)    # no extra spaces
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
               "artist is empty" \
               "Something went wrong") # usually went wrong formatted url
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
    lyrics=$(curl -s $url | hxmagic 'p.songLyricsV14')
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
    curl -s $url | hxmagic -s '\n\n' 'p.verse'
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
    curl -sL $url | hxmagic 'lyrics.lyrics'
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
        raw_title=$3
        artist_template="http://www.lyricsfreak.com/%s/%s/"
        lyrics_template="http://www.lyricsfreak.com/%s"
        url=$(printf $artist_template ${artist:0:1} $artist)
        suburl=$(mycurl $url | grep -i "$raw_title" | hxwls)
        url=$(printf $lyrics_template $suburl)
    fi
    # Without awk filtering, the div.dn magic always returns something, even
    # when no lyrics were found, usually something from lyricsfreak frontpage.
    mycurl $url | awk '/<!-- SONG LYRICS -->/, /<!-- \/SONG LYRICS -->/' | \
        hxmagic 'div.dn' | sed 's/<a data-tracking..*//g'
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
    mycurl $url | awk '{print $0"<br></br>"}' | hxmagic 'p.mxm-lyrics__content'
}

darklyrics() {
    local artist title raw_title lyrics url
    local albums_template lyrics_template album awk_filter
    if [[ $1 =~ "http" ]]; then
        url=$1
    else
        artist=${1// /}
        title=${2// /}
        raw_title=$3
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
    local artist title lyrics url
    local search_template lyrics_template suburl
    if [[ $1 =~ "http" ]]; then
        url=$1
    else
        artist=${1// /-}
        title=${2// /-}
        search_template="http://www.songtexte.com/search?q=%s+%s&c=all"
        lyrics_template="http://www.songtexte.com/%s"
        url=$(printf $search_template $artist $title)
        suburl=$(curl -s $url | grep -i "$title..*html" | hxwls | head -n1)
        url=$(printf $lyrics_template $suburl)
    fi 
    lyrics=$(curl -s $url | sed 's/div id/div class/g' | hxmagic 'div.lyrics')
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
        raw_title=$3
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
            hxmagic 'p'
}

# Get the best mached urls from the search string.
search_for_urls() {
    local search_str=$1
    local extra_str=$2
    local template="https://www.google.com/search?q=%s+%s"
    local search_url=$(printf $template ${search_str// /+} $extra_str)
    mycurl $search_url | hxmagic 'h3.r' | hxwls
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

# The first line of the returned string is the website name where the
# lyrics were found and the rest of the string are the lyrics themselves.
lyrics_from_artist_song() {
    local artist song raw_song last_website lyrics
    artist=$1
    song=$2
    raw_song=$3
    last_website=$(get_last_website)
    for website in $last_website $LYRICS_WEBSITES; do
        lyrics=$($website $artist $song $raw_song) # call function with website name.
        if [[ ! -z "${lyrics// /}" ]]; then
            echo $website       # first line contains the website name
            break
        fi
    done
    clean_string $lyrics        # the rest of the string contains the lyrics
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


# Collect info regarding the most-used lyrics websites.
stats_location() {
    echo "$HOME/lyrics/.stats"
}

stats_add_website() {
    local website pattern stats_file
    website=$1
    stats_file=$(stats_location)
    # Increment the website count or add it if it doesn't exist.
    pattern="/%s/{\$1+=1; found=1}1{print} END{if(found!=1) print \"1 %s\"}"
    pattern=$(printf $pattern $website $website)
    awk $pattern $stats_file > /tmp/lyrics_stats && \
        mv /tmp/lyrics_stats $stats_file
}

stats_display() {
    local stats_file=$(stats_location)
    cat $stats_file
}

stats_clear() {
    local stats_file=$(stats_location)
    echo -n "" > $stats_file
}


# Store the last website where lyrics were found. In folder searches,
# the chances are high that the next search if for the same artist or
# even album. So why not search on the same website.
last_website_location() {
    echo "$HOME/lyrics/.lastwebsite"
}

save_last_website() {
    local last_website_file=$(last_website_location)
    echo $1 > $last_website_file
}

get_last_website() {
    local last_website_file=$(last_website_location)
    cat $last_website_file
}


monitor_folder() {
    local folder=$1
    inotifywait -m -r -e create -e move --format '%w%f' "${folder}" | \
        while read newfile
    do
        if [[ -d $newfile ]]; then   # folder
            for file in $newfile/**/*.mp3; do
                $SELF $file
            done
        else                         # single file
            $SELF -s $newfile
        fi
    done
}


main () {
    local extra_str="lyrics"
    local only_save="false"
    while getopts ":d:e:rw:WsgGlh" opt; do
        case $opt in
            d)
                monitor_folder $OPTARG
                ;;
            e)
                extra_str=$OPTARG
                ;;
            r)
                clean_tokens=()
                ;;
            w)
                : ${(A)LYRICS_WEBSITES::=${=OPTARG}}
                ;;
            W)
                echo ${(F)LYRICS_WEBSITES}
                exit 0
                ;;
            s)
                only_save="true"
                ;;
            g)
                stats_display
                exit 0
                ;;
            G)  stats_clear
                exit 0
                ;;
            l)
                get_last_website
                exit 0
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

    local search_str urls artist song raw_song website_and_lyrics website
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
                $SELF -s -w $LYRICS_WEBSITES $media_file
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

    raw_song=$song              # remember the original value, some
                                # parsers need it for searching
    artist=$(clean_search_item $artist)
    song=$(clean_search_item $song)

    # Actually search the lyrics
    if [[ $reliable_src =~ "true" ]]; then
        # In the lyrics database..
        lyrics=$(from_db $artist $song)
        if [[ -z "${lyrics// /}" ]]; then
            # ..or on the web, when the artist and song is known
            website_and_lyrics=$(lyrics_from_artist_song $artist $song $raw_song)
            website=$(echo $website_and_lyrics | head -n1)
            lyrics=$(echo $website_and_lyrics | tail -n+2)
            # Save the lyrics if any were found and make updates.
            if [[ ! -z "${lyrics// /}" ]]; then
                save_db $artist $song $lyrics
                stats_add_website $website
                save_last_website $website
            fi
        fi
    else
        # For the free-form strings, use a search engine, as the artist and
        # song name are not necessarly known or cannot be 100% infered in
        # this case. Also, no saving in this case.

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
