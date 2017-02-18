#!/usr/bin/env zsh

help_str="lyrics - All the lyrics in one place
Usage: lyrics [-lrsh] string
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
    if [[ $# -eq 0 || $# -gt 1 ]]; then
        echo $help_str
        exit 1
    else
        search_str=$1
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

