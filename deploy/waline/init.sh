#!/bin/sh
# Run from any directory; does not overwrite an existing database or dotenv file.
set -eu
cd "$(dirname "$0")"
umask 077
mkdir -p data
tmp=
trap 'if [ -n "$tmp" ]; then rm -f -- "$tmp"; fi' EXIT
if [ ! -e data/waline.sqlite ]; then
    tmp=$(mktemp data/.waline-sqlite.XXXXXX)
    curl --fail --silent --show-error --location --max-time 30 \
      "https://raw.githubusercontent.com/walinejs/waline/eb1aedb94e1979d53655be20a14f707f8d314793/assets/waline.sqlite" \
      -o "$tmp"
    printf '%s  %s\n' ac08959a80b2756701742d97ad445fab24597428b3bc56e0c87541c4ea8b1b37 "$tmp" | sha256sum -c
    mv -n "$tmp" data/waline.sqlite
    rm -f -- "$tmp"
    tmp=
fi
if [ ! -e .env ]; then
    tmp=$(mktemp .waline-env.XXXXXX)
    token=$(openssl rand -hex 32)
    printf 'JWT_TOKEN=%s\n' "$token" > "$tmp"
    mv -n "$tmp" .env
    rm -f -- "$tmp"
    tmp=
fi
printf '%s\n' '初始化完成。运行 docker compose up -d；不要分享 .env 或数据库。'
