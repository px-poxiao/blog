#!/usr/bin/env bash
set -euo pipefail
umask 022

if [[ ! ${SSH_ORIGINAL_COMMAND:-} =~ ^deploy\ ([1-9][0-9]{0,13})-([1-9][0-9]{0,8})-([0-9a-f]{40})$ ]]; then
    echo 'Expected a deployment release ID' >&2
    exit 1
fi
run=${BASH_REMATCH[1]}
attempt=${BASH_REMATCH[2]}
release="release-$run-$attempt-${BASH_REMATCH[3]}"
cd /srv/blog/releases
exec 9> .deploy.lock
flock 9

old_release=$(readlink current || true)
if [[ $old_release =~ ^release-([0-9]+)-([0-9]+)-[0-9a-f]{40}$ ]]; then
    old_run=${BASH_REMATCH[1]}
    old_attempt=${BASH_REMATCH[2]}
    if (( run < old_run || (run == old_run && attempt <= old_attempt) )); then
        cat > /dev/null
        echo 'This run has already been deployed or superseded.'
        exit 0
    fi
fi

stage=$(mktemp -d .incoming.XXXXXXXX)
switched=false
verified=false

set_link() {
    ln -sfn -- "$1" ".$2.new"
    mv -Tf -- ".$2.new" "$2"
}

clean_up() {
    local status=$?
    if [[ $switched == true && $verified == false ]]; then
        if [[ -n $old_release ]]; then
            set_link "$old_release" current
        else
            rm -f -- current
        fi
    fi
    rm -rf -- "$stage"
    if [[ $verified == false && $(readlink current || true) != "$release" ]]; then
        rm -rf -- "$release"
    fi
    exit "$status"
}
trap clean_up EXIT

tar --extract --gzip --no-same-owner --no-same-permissions -C "$stage"
test -z "$(find "$stage" ! -type f ! -type d -print -quit)"
test -s "$stage/index.html"
test -s "$stage/archive/index.html"
test -s "$stage/pagefind/pagefind.js"
chmod 755 "$stage"
mv -T -- "$stage" "$release"
switched=true
set_link "$release" current

for path in / /archive/ /pagefind/pagefind.js; do
    curl --fail --silent --show-error --max-time 10 --output /dev/null \
        --resolve px-poxiao.cn:3500:127.0.0.1 "https://px-poxiao.cn:3500$path"
done
if [[ -n $old_release ]]; then
    set_link "$old_release" previous
fi
verified=true

for candidate in release-*; do
    if [[ $candidate =~ ^release-[0-9]+-[0-9]+-[0-9a-f]{40}$ &&
        $candidate != "$release" && $candidate != "$old_release" ]]; then
        rm -rf -- "$candidate"
    fi
done
echo "Deployed $release"
