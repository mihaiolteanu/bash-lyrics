exit_msg() {
    echo $1
    exit 1
}

# Check the dependencies.
type "hxnormalize" > /dev/null || exit_msg "html-xml-utils required"
type "id3v2" > /dev/null || exit_msg "id2v2 required"
type "inotifywait" > /dev/null || exit_msg "inotify-tools required"

# Copy the executable to path.
cp lyrics.zsh /usr/local/bin/lyrics || exit 1
chmod +x /usr/local/bin/lyrics

# Setup the database.
mkdir -p "$HOME/lyrics/"
touch "$HOME/lyrics/.lastwebsite"
touch "$HOME/lyrics/.stats"



