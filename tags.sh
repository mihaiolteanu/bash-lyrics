#!/usr/bin/env zsh

get-artist-tags() {
    local artist=$1
    local template="www.last.fm/music/%s"
    local url=$(printf $template $artist)
    local tags=$(curl -sL $url | hxnormalize -x | \
                     hxselect -c -s '/' 'li.tag a')

    tags=${(z)tags}
    tags=${tags//;/}            # Some stray characters?!
    #tags=(${(ps:*:)tags})
    echo $tags
}

get-artist-tags "$@"

