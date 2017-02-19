# zaw source for ack/ag searcher

autoload -U read-from-minibuffer

function zaw-lyrics-src-searcher() {
    local buf
    read-from-minibuffer "lyrics: "
    if [[ -z "${REPLY// }" ]]; then
        buf=$(find ~/lyrics -type f)
    else
        buf=$(ag -i $REPLY ~/lyrics/)
    fi
    if [[ $? != 0 ]]; then
        return 1
    fi
    buf=$(echo $buf | awk 'BEGIN{FS=":"}{print $1, $3}' | \
              awk 'BEGIN{FS="/"}{print $(NF-1), $NF}')
    : ${(A)candidates::=${(f)buf}}
    : ${(A)cand_descriptions::=${(f)buf}}
    actions=(\
             zaw-lyrics-src-searcher-play \
             zaw-lyrics-src-searcher-youtube \
        )
    act_descriptions=(\
                      "Cat" \
                      "Search on youtube" \
        )
}

function zaw-muse-artist-search() {
    #candidates=(${(@f)$(ls ~/lyrics)})
    : ${(A)candidates::=${(@f)$(ls ~/lyrics)}}
    #candidates=("\033[35m one" "two" "three")
    actions=(\
             zaw-muse-artist-search-lastfm \
        )
    act_descriptions=(\
            "Open artist in last.fm" \
        )
    #zaw-lyrics-src-searcher
}

function zaw-muse-artist-search-lastfm() {
    local pattern="www.last.fm/music/%s"
    local artist=${1//-/+}
    firefox $(printf $pattern $artist)
}

function zaw-lyrics-src-searcher-play () {
    local filename=${1%%:*}
    local array=(${(s:/:)filename})
    local title=$array[-1]
    local artist=$array[-2]
    local command=$(printf "/%s %s" ${artist//-/ } ${title//-/ })
    echo "\n" $artist "-" $title "\n"
    cat $filename
    cmus-remote -C $command
    cmus-remote -C "win-activate"
    #zle accept-line
}

function zaw-lyrics-src-searcher-youtube() {
    local filename=${1%%:*}
    local array=(${(s:/:)filename})
    local title=$array[-1]
    local artist=$array[-2]
    title=${title//-/+}    # Ducky likes pluses
    artist=${artist//-/+}
    local template="https://duckduckgo.com/?q=!ducky+%s+%s+site"
    local command=$(printf $template $artist $title)
    firefox $command"%3Ayoutube.com"
}

zaw-register-src -n lyrics-searcher zaw-lyrics-src-searcher
zaw-register-src -n artist-search zaw-muse-artist-search
