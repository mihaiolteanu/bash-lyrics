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

# Get lyrics from makeitpersonal.
makeitpersonal() {
    local artist=$(pquery $1 " " "-")
    local title=$(pquery $2 " " "-")
    local template="https://makeitpersonal.co/lyrics?artist=%s&title=%s"
    local url=$(printf $template $artist $title)
    local lyrics=$(curl -s $url)
    if [[ $lyrics =~ "Sorry, We don't have lyrics for this song yet" ]]; then
        lyrics=""              # Bad luck this time.
    fi
    echo $lyrics
}

# Get lyrics from songlyrics.com
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

# Get lyrics from metrolyrics.com
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

# Get lyrics from genius.com
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
    local raw_title=$2          # use for greping
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
    local raw_title=$2          # Needed for greping on the albums page
    local artist=$(pquery $1 " " "") # No separator in title/artist string
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

main() {
    local lyrics=""
    for lyrics_fn in $LYRICS_SOURCES; do
        echo $lyrics_fn > /tmp/lyricslog 
        lyrics=$($lyrics_fn $1 $2)
        if [[ ! -z $lyrics ]]; then
            break;
        fi
    done
    echo $lyrics
}

help() {
    echo "this is help"
}

lyrics_sources_all=(makeitpersonal songlyrics metrolyrics genius azlyrics lyricsfreak darklyrics)
: ${(A)LYRICS_SOURCES:=$lyrics_sources_all}

while getopts ":s:h" opt; do
    case $opt in
        s)
            LYRICS_SOURCES=("${(s/ /)OPTARG}")
            shift $((OPTIND-1))
            ;;
        \?|h|:)                 # unknown, help or argument expected
            help
            ;;
    esac
done

main $@

