#!/bin/sh
# Copies the project into the public repository's checkout (default ~/git/angel-aquarium-dream),
# leaving out CLAUDE.md (notes about the development machine). Files removed here are removed
# there too. Commit and push in that checkout afterwards.
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
dest=${1:-$HOME/git/angel-aquarium-dream}
mkdir -p "$dest"
cd "$here"
git ls-files --cached --others --exclude-standard . | grep -v '^CLAUDE\.md$' > "$dest/.publish-list"
rsync -a --delete --files-from="$dest/.publish-list" --exclude=.git ./ "$dest/"
# --files-from doesn't delete; remove what's no longer listed
(cd "$dest" && git ls-files 2>/dev/null | grep -v -x -F -f .publish-list | xargs -r git rm -q --)
rm "$dest/.publish-list"
echo "copied to $dest"
