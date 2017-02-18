#!/usr/bin/env zsh

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
    mycurl $1 | hxnormalize -x | \
        hxselect -c 'div.dn' | sed 's/<a data-tracking..*//g'
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
    local template="https://www.google.com/search?q=%s+lyrics"
    local search_url=$(printf $template ${search_str// /+})
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

help() {
    echo "
Usage: lyrics [-rh] str
where str might be a songname, a songname and an artist name or some lyrics.
Get song lyrics from multiple, selectable sources.
    -r Raw mode. By default, clean the title name of strings like
       \"$lyrics_clean_title_tokens_all\",
       which increases the chance of finding the lyrics. If this option is set,
       the song title is searched as it is given.
    -h Print this help and exit

Example usage:
lyrics \"anathema thin air\""
}

main () {
    local clean_tokens=(demo live acoustic remix bonus)
    while getopts ":s:rh" opt; do
        case $opt in
            r)
                clean_tokens=()
                shift $((OPTIND-1))
                ;;
            \?|:)
                help
                exit 1
                ;;
            h)
                help
                exit 0
                ;;
        esac
    done

    local search_str urls lyrics
    if [[ $# -eq 0 || $# -gt 1 ]]; then
        echo "\e[0;31merror\033[0m: Not enough or too many arguments"
        help
        exit 1
    else
        search_str=$1
    fi

    for token in $clean_tokens; do
        search_str=$(echo $search_str | sed "s/ *( *$token.*) *//")
    done

    urls=(${(@f)$(search_for_urls $search_str)})
    for url in $urls; do
        lyrics=$(lyrics_from_url $url)
        if [[ ! -z $lyrics ]]; then
            break
        fi
    done
    echo $lyrics
}

main $@
