#!/usr/bin/env zsh

help_str="lyrics - All the lyrics in one place
Usage: lyrics [-lrsh] string
           Search for lyrics using the given string, just like a google search.
       lyrics [-lrsh]
           Try to infer the artist and song from your music player.
Options:
    -e <str> Extra string to pass to the search string. By default this is \"lyrics\".
    -l Only list the candidate urls, but do not extract the lyrics from any of them.
    -r Raw mode. Do not remove tokens like \"live\", \"acoustic version\", etc.
       from the input string.
    -s List the websites from which the application can extract the lyrics
    -h Print this help and exit"

supported_websites="www.songlyrics.com
www.metrolyrics.com
www.genius.com
www.azlyrics.com
www.lyricsfreak.com
www.songmeanings.com
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

main () {
    local clean_tokens=(demo live acoustic remix bonus)
    local extra_str="lyrics"
    local only_urls="false"
    while getopts ":e:lrsh" opt; do
        case $opt in
            e)
                extra_str=$OPTARG
                ;;
            l)
                only_urls="true"
                ;;
            r)
                clean_tokens=()
                ;;
            s)
                echo $supported_websites
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

    local search_str urls lyrics
    # Get the search string from a music player, if avaialble.
    if [[ $# -eq 0 ]]; then
        if cmus_running; then
            search_str=$(printf "%s %s" "$(cmus_artist)" "$(cmus_song)")
        elif moc_running; then
            search_str=$(printf "%s %s" "$(moc_artist)" "$(moc_song)")
        else
            echo "error: No known players available or running."
            exit 1
        fi
    elif [[ $# -eq 1 ]]; then
        search_str=$1
    else
        echo $help_str
        exit 1
    fi

    for token in $clean_tokens; do
        search_str=$(echo $search_str | sed "s/ *( *$token.*) *//")
    done

    urls=(${(@f)$(search_for_urls $search_str $extra_str)})

    if [[ $only_urls =~ "true" ]]; then
        echo ${(F)urls}
        exit 0
    fi

    for url in $urls; do
        lyrics=$(lyrics_from_url $url)
        if [[ ! -z $lyrics ]]; then
            break
        fi
    done
    echo $lyrics
}

main $@
