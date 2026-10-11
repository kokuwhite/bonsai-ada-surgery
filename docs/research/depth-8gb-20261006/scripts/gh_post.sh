#!/usr/bin/env bash
# gh_post.sh <pr|issue> <number> <body-file> [repo]: post a comment and record its id so gh_watch.sh ignores it
repo=${4:-professorpalmer/bonsai-ada-surgery}
url=$(gh $1 comment $2 --repo $repo --body-file $3) && echo "$url" && echo "${url##*-}" >> /c/bonsai/8gb/gh_mine.txt
