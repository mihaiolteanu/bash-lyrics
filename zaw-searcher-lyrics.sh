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

    # Make things look pretier.
    buf=$(echo $buf | \
          sed -r 's/:[0-9]+:/|/' | \
          awk -F/ 'BEGIN{OFS="|"}{print $(NF-1), $NF}' | \
          awk '{gsub("-", " "); print $0}' | \
          # Output three columns of fixed length, including
          # artist, song and actual lyrics where the length2 is
          # determined at runtime from the longest strings
          awk -F\| '
            { if (length($1) > artist_len) artist_len=length($1)
            if (length($2) > song_len) song_len=length($2)
            if (length($3) > lyrics_len) lyrics_len=length($3)
            a[NR][1]=$1; a[NR][2]=$2; a[NR][3]=$3 }
            END {
            patt=sprintf("%%-%ds | %%-%ds | %%-%ds\n", artist_len+1, song_len+1, lyrics_len+1)
            for(i=1; i<=NR; i++) printf(patt, a[i][1], a[i][2], a[i][3])}')
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

rm_extra_spaces() {
    echo $1 | sed 's/^[[:space:]]*//; s/[[:space:]] *$//;
                   s/[[:space:]][[:space:]]*/ /g'
}

function zaw-muse-artist-search-lastfm() {
    local pattern="www.last.fm/music/%s"
    local artist=${1//-/+}
    firefox $(printf $pattern $artist)
}

function zaw-lyrics-src-searcher-play () {
    local array=(${(s:|:)1})
    local artist=$(rm_extra_spaces $array[1])
    local song=$(rm_extra_spaces $array[2])
    local command=$(printf "/%s %s" $artist $song)
    cmus-remote -C $command
    cmus-remote -C "win-activate"
    zle accept-line
}

function zaw-lyrics-src-searcher-youtube() {
    local array=(${(s:|:)1})
    local artist=$(rm_extra_spaces $array[1])
    local song=$(rm_extra_spaces $array[2])
    artist=${artist// /+}
    song=${song// /+}    # Ducky likes pluses
    local template="https://duckduckgo.com/?q=!ducky+%s+%s+site"
    local command=$(printf $template $artist $song)
    firefox $command"%3Ayoutube.com"
}

zaw-register-src -n lyrics-searcher zaw-lyrics-src-searcher
zaw-register-src -n artist-search zaw-muse-artist-search
