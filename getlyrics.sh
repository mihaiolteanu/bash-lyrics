#!/usr/bin/env zsh

# Prepare string for query.  Sites have different needs regarding the
# string for artist and title. Some require dashes instead of spaces,
# others require no spearator at all.
pquery() {
    local result=$1
    local sep=$2
    local rep=$3
    result=${result//$2/$3}     # replace separators
    result=${result//[.,?!]/}   # remove special chars
    echo ${result:l}            # lowercase
}

mycurl() {
    local url=$1
    local user_agent="User-Agent: Mozilla/5.0 (Macintosh; \ 
        Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML,\
        like Gecko) Chrome/44.0.2403.89 Safari/537."
    local resp=$(curl -sLH $user_agent $1)
    echo $resp
}

clean_string() {
    local dirty=$1
    # Remove all tags and leading spaces.
    local clean=$(echo $dirty | sed -e 's/<[^>]*>//g' | sed -e 's/^[[:space:]]*//')
    echo $clean
}

makeitpersonal() {
    local artist=$(pquery $1 " " "-")
    local title=$(pquery $2 " " "-")
    local template="https://makeitpersonal.co/lyrics?artist=%s&title=%s"
    local url=$(printf $template $artist $title)
    local lyrics=$(curl -s $url)
    local error_str=("Sorry, We don't have lyrics for this song yet" \
                         "title is empty" \
                         "artist is empty")
    if [[ $error_str =~ $lyrics ]]; then
        lyrics=""
    fi
    echo $lyrics
}

songlyrics() {
    local artist=$(pquery $1 " " "-")
    local title=$(pquery $2 " " "-")
    local template="http://www.songlyrics.com/%s/%s-lyrics/"
    local url=$(printf $template $artist $title)
    local lyrics=$(curl -s $url | hxnormalize -x | \
                   hxselect -c 'p.songLyricsV14')
    if [[ $lyrics =~ "Sorry, we have no" ]]; then
        lyrics=""
    fi
    lyrics=$(clean_string $lyrics)
    echo $lyrics
}

metrolyrics() {
    local artist=$(pquery $1 " " "-")
    local title=$(pquery $2 " " "-")
    local template="http://www.metrolyrics.com/%s-lyrics-%s.html"
    local url=$(printf $template $title $artist)
    local lyrics=$(curl -s $url | hxnormalize -x  | \
                   hxselect -c -s '\n\n' 'p.verse')
    lyrics=$(clean_string $lyrics)
    echo $lyrics
}

genius() {
    local artist=$(pquery $1 " " "-")
    local title=$(pquery $2 " " "-")
    local template="https://genius.com/%s-%s-lyrics"
    local url=$(printf $template $artist $title)
    local lyrics=$(curl -sL $url | hxnormalize -x  | \
                   hxselect -ci 'lyrics.lyrics')
    lyrics=$(clean_string $lyrics)
    echo $lyrics
}

azlyrics() {
    local raw_title=$2
    local artist=$(pquery $1 " " "")
    local title=$(pquery $2 " " "")
    local template="http://www.azlyrics.com/lyrics/%s/%s.html"
    local url=$(printf $template $artist $title)
    local awk_filter=$(printf 'BEGIN{IGNORECASE=1}/<b>"%s"/{f=1}/<\/div>/{print;f=0}f' $raw_title)
    local lyrics=$(mycurl $url | hxnormalize -x | \
                   awk $awk_filter | hxnormalize -x | hxselect -c 'div')
    lyrics=$(clean_string $lyrics)
    echo $lyrics
}

darklyrics() {
    local raw_title=$2
    local artist=$(pquery $1 " " "")
    local title=$(pquery $2 " " "")
    local lyrics=""
    local albums_template="http://www.darklyrics.com/%s/%s.html"
    local lyrics_template="http://www.darklyrics.com/lyrics/%s/%s.html"
    local url=$(printf $albums_template ${artist:0:1} $artist)
    local album=$(mycurl $url | grep "href" | grep -i "$raw_title" | head -n1 | hxwls)
    if [[ ! -z "${album// }" ]]; then
        album=${$(basename $album):r}
        url=$(printf $lyrics_template $artist $album)
        awk_filter=$(printf 'BEGIN{IGNORECASE=1}/h3..*%s/{f=1;next}/h3/{f=0}f' $raw_title)                
        lyrics=$(mycurl $url | awk $awk_filter)
    fi
    lyrics=$(clean_string $lyrics)
    echo $lyrics
}

lyricsfreak() {
    local raw_title=$2
    local artist=$(pquery $1 " " "+")
    local title=$(pquery $2 " " "+")
    local artist_template="http://www.lyricsfreak.com/%s/%s/"
    local lyrics_template="http://www.lyricsfreak.com/%s"
    local url=$(printf $artist_template ${artist:0:1} $artist)
    local suburl=$(mycurl $url | grep -i "$raw_title" | hxwls)
    url=$(printf $lyrics_template $suburl)
    local lyrics=$(mycurl $url | hxnormalize -x | \
                   hxselect -c 'div.dn' | sed 's/<a data-tracking..*//g')
    lyrics=$(clean_string $lyrics)
    echo $lyrics
}

versuri() {
    local raw_artist=$1
    local raw_title=$2
    local artist=$(pquery $1 " " "+")
    local title=$(pquery $2 " " "+")
    local main_template="http://www.versuri.ro/cat/%s.html"
    local artist_template="http://www.versuri.ro%s"
    local lyrics_template="http://www.versuri.ro%s"
    local url=$(printf $main_template ${artist:0:1})
    local suburl=$(curl -s $url | grep -i "$raw_artist" | hxwls)
    url=$(printf $artist_template $suburl)
    suburl=$(curl -s $url | grep -i "$raw_title" | hxwls)
    url=$(printf $lyrics_template $suburl)
    local lyrics=$(curl -s $url | \
        # Skip all the div and include everything between index0f and BOTTOM-CENTER
        awk '/div/{next}/var index0f/{f=1;next}/BOTTOM-CENTER/{print;f=0}f' | \
        hxnormalize -x | hxselect -c 'p')
    lyrics=$(clean_string $lyrics)
    echo $lyrics
}

main() {
    local lyrics=""
    for lyrics_fn in $LYRICS_SOURCES; do
        lyrics=$($lyrics_fn $1 $2)
        if [[ ! -z $lyrics ]]; then
            break;
        fi
    done
    echo -n $lyrics
}

help() {
    local help_str="Usage: $1 [-sh] artist title
Get song lyrics from multiple, selectable sources.
    -s Use these lyrics sources, in the order they are given. Valid sources are:
       \"$(echo $lyrics_sources_all)\"
       When this option is not given, all the above source are considered,
       or, if LYRICS_SOURCES is set, consider the sources listed in this
       variable instead
    -h Print this help and exit

Example usage:
    Get the lyrics for some metal band that you know might find on darklyrics,
    but for some reason you want to try some other sources first:
$1 -s \"makeitpersonal darklyrics\" \"throes of dawn\" \"slow motion\""
    echo $help_str
}

lyrics_sources_all=(makeitpersonal songlyrics metrolyrics genius azlyrics lyricsfreak darklyrics versuri)
: ${(A)LYRICS_SOURCES:=$lyrics_sources_all}

while getopts ":s:h" opt; do
    case $opt in
        s)
            LYRICS_SOURCES=("${(s/ /)OPTARG}")
            shift $((OPTIND-1))
            ;;
        \?|:)
            help $0
            exit 1
            ;;
        h)
            help $0
            exit 0
            ;;
    esac
done

if [[ $# -eq 0 ]]; then
    help $0
    exit 1
else
    main $@
fi
