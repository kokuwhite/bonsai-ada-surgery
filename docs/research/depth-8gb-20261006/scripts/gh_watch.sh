#!/usr/bin/env bash
# Wait for new GitHub activity (not my own comments), print it and exit (wakes the session).
# My own comment ids: one per line in gh_mine.txt (post with gh_post.sh to record them).
cd /c/bonsai/8gb; touch gh_mine.txt
R=professorpalmer/bonsai-ada-surgery
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
evts() { gh api "repos/$R/events?per_page=100" -q '.[]|select(.type|test("IssueComment|PullRequest|Issues|Push|Release"))|select(.created_at > "'"$START"'")|"\(.id) \(.type) \(.payload.comment.id // "-") \(.created_at) \((.payload.comment.html_url)//(.payload.pull_request.html_url)//(.payload.ref)//"")"' 2>/dev/null; }
prism() { for n in 325 330 314 317 209 332; do gh api "repos/PrismML-Eng/llama.cpp/issues/$n/comments?per_page=100" -q '.[]|"\(.id) \(.html_url)"' 2>/dev/null; done; }
fork() { gh api "repos/professorpalmer/llama.cpp-ada-ternary/events?per_page=100" -q '.[]|select(.type|test("Push|PullRequest|IssueComment"))|select(.created_at > "'"$START"'")|"\(.id) \(.type) \(.created_at) \(.payload.ref // "")"' 2>/dev/null; }
seen=$( { evts; prism; fork; } | grep -E '^[0-9]+ ' | awk '{print $1}' | sort -u)
# a baseline taken while rate-limited is empty, and every old comment would then look new: wait for a real one
until [ $(echo "$seen" | grep -c .) -ge 5 ]; do sleep 300; seen=$( { evts; prism; fork; } | grep -E '^[0-9]+ ' | awk '{print $1}' | sort -u); done
echo "baseline $(date +%T): $(echo "$seen" | wc -l) items"
while true; do
  sleep 120
  all=$( { evts; prism; fork; } | grep -E "^[0-9]+ " )
  [ -z "$all" ] && continue
  new=$(echo "$all" | awk 'NR==FNR{s[$1]=1;next} !($1 in s)' <(echo "$seen") -)
  [ -z "$new" ] && continue
  seen=$(printf '%s\n%s\n' "$seen" "$(echo "$all" | awk '{print $1}')" | sort -u)
  # drop my own comments (event's comment id, or a PrismML comment id, listed in gh_mine.txt)
  other=$(echo "$new" | while read -r id typ cid rest; do
      if grep -qx "$cid" gh_mine.txt 2>/dev/null || grep -qx "$id" gh_mine.txt 2>/dev/null; then continue; fi
      case "$rest" in *"/issues/7#"*) continue;; esac   # issue #7: the 4070 session handles it
      echo "$id $typ $cid $rest"; done)
  [ -z "$other" ] && continue
  echo "NEW $(date +%T)"; echo "$other"; exit 0
done
