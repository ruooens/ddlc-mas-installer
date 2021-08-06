#!/bin/sh
while [ "$#" -gt 0 ]; do
    case "$1" in
        "--help")
            cat >&2 <<EOF
Usage: $0 [options] target


Positional parameters:

  target          directory to install DDLC + MAS to


Optional parameters:

  -M,--mac        install Mac version of DDLC
  -m,--mod-only   install just MAS mod
  --accept-terms  accept risks of using programmatical
                  way to retrieve copy of DDLC
EOF
            exit
            ;;
        "-M"|"--mac")
            mac=1
            ;;
        "--accept-terms")
            accept=1
            ;;
        "-m"|"--mod-only")
            modonly=1
            ;;
        -*)
            cat <<EOF
Unrecognized option $1. For usage help run '$0 --help'
EOF
            exit 1
            ;;
        *)
          break
          ;;
    esac

    shift
done

target="${1:-Monika After Story}"
cleanup() {
    rm -rf "$target" "$target.tmp"
}
trap cleanup INT EXIT

if [ -z "$modonly" ]; then
    if [ -z "$accept" ]; then
        cat <<EOF

  This game is free but the developer accepts your support by
  letting you pay what you think is fair for the game.
  For further details visit https://teamsalvato.itch.io/ddlc/purchase.

  It is highly recommended that you retrieve a copy of DDLC by the
  link above, install it and complete it (if you still haven't), then
  (and only then) run this script with --mod-only flag:

    $0 --mod-only target

  This script provides a way to programmatically retrieve a copy of DDLC,
  however, developer does not provide any warranty it will work or
  will not violate Team Salvato Intellectual Property Guidelines and/or
  Itch.IO Terms of Service; user discretion is advised:

    $0 --accept-terms target

  By retrieving a copy of DDLC package by using this script you agree that
  developer is not liable for any damage or legal terms violation caused by
  the usage of this script.

EOF
        exit
    fi

    case "$(uname -s)" in
        "Darwin"*)
            if [ -z "$mac" ]; then
                cat <<EOF
Note: this script seems to be running on MacOS machine, and you're going to
download Windows/Linux version of DDLC. Perhaps you meant to use --mac flag?
EOF
            fi
            ;;
        *)
            if [ -n "$mac" ]; then
                cat <<EOF
Note: this script seems to be running on non-MacOS machine, and you're going to
download Mac version of DDLC. Perhaps you didn't mean to use --mac flag?
EOF
            fi
            ;;
    esac

    if [ -e "$target" ]; then
        _target="$target"
        target="$(mktemp -u -p "$(dirname "$target")" "$(basename "$target")-XXXXXX")"
        echo "Note: $_target already exists, installing DDLC to $target."
        unset _target
    fi

    printf "%s\n" "Downloading and unpacking DDLC..."
    set -e
    id="$(curl -sL "$(curl -sL -H "Content-Type: application/x-www-form-urlencoded" -d "" https://teamsalvato.itch.io/ddlc/download_url | perl -lne 'if (/"url":"(.+?)"/) { $u = $1; $u =~ s/\\\//\//g; print $u }')" | perl -lne '$in = join("", <STDIN>); while ($in =~ /<a[^\/]*data-upload_id="(.+?)".*?<\/a>/g) { print $1 }')"

    nid="$(echo "$id" | wc -l)"
    if [ "$nid" -eq 0 ]; then
        echo "Could not retrieve DDLC download URL."
        exit 2
    elif [ "$nid" -eq 1 ]; then
        if [ -n "$mac" ]; then
            echo "Could not retrieve unambiguous DDLC download URL."
            exit 2
        fi

        cid="$(echo "$id" | head -n 1)"
    else
        if [ -n "$mac" ]; then
            cid="$(echo "$id" | tail -n 1)"
        else
            cid="$(echo "$id" | head -n 1)"
        fi
    fi

    curl -L "$(curl -sL -H "Content-Type: application/x-www-form-urlencoded" -d "" "https://teamsalvato.itch.io/ddlc/file/$cid" | perl -lne 'if (/"url":"(.+?)"/) { $u = $1; $u =~ s/\\\//\//g; print $u }')" -o "$target.tmp"
    unzip -o -q "$target.tmp" -d "$target"
    rm "$target.tmp"
    if [ -z "$mac" ]; then
        nested="$(find "$target" -mindepth 1 -maxdepth 1 -type d)"
        mv "$nested" "$target.tmp"
        rm -d "$target"
        mv "$target.tmp" "$target"
        echo
        echo "Installed DDLC v$(echo "$nested" | perl -ne 'print $1 if /-(\d+(\.\d+(\.\d+(\.\d+)?)?)?)-.*$/')."
    else
        echo "Installed DDLC v$(echo "$target/Contents/Info.plist" | perl -lne 'print $1 if /<string>(\d+(\.\d+(\.\d+(\.\d+)?)?)?)<\/string>/' Monika\ After\ Story/DDLC.app/Contents/Info.plist | head -n 2 | tail -n 1)."
        target="$target/DDLC.app/Contents/Resources/autorun"
    fi

    unset nested
fi

if [ ! -d "$target" ]; then
    if [ -z "$noddlc" ]; then
        echo "$target directory does not exist."
    else
        echo "$target directory does not exist. Perhaps you didn't mean to use --skip-ddlc flag?"
    fi
    exit 2
fi

printf "%s\n" "Downloading and installing Monika After Story mod..."
mas_url="$(curl -sL https://api.github.com/repos/monika-after-story/monikamoddev/releases/latest | perl -lne 'print $1 if /"browser_download_url": "(.+?-Mod\.zip)"/')"
curl -L "$mas_url" -o "$target.tmp"
unzip -o -q "$target.tmp" -d "$target/game"
rm "$target.tmp"
echo "Installed Monika After Story v$(echo "$mas_url" | perl -ne 'print $1 if /-(\d+(\.\d+(\.\d+(\.\d+)?)?)?)-Mod.zip$/')."

trap - EXIT
