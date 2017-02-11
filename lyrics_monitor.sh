#!/usr/bin/env zsh

MONITORDIR="$HOME/music/"
inotifywait -m -r -e create -e move --format '%w%f' "${MONITORDIR}" | while read NEWFILE
do
    if [[ -d $NEWFILE ]]; then
        for file in $NEWFILE/**/*.mp3; do
            ~/projects/lyrics/lyrics.sh -e "false" -f $file
        done
    else
        ~/projects/lyrics/lyrics.sh -e "false" -f $NEWFILE
    fi
done
