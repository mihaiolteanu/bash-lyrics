#!/usr/bin/env zsh

MONITORDIR="$HOME/music/"
inotifywait -m -r -e create -e move --format '%w%f' "${MONITORDIR}" | while read NEWFILE
do
    ./lyrics.sh -e "false" -f $NEWFILE
done
