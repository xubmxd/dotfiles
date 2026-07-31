#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C.UTF-8

################################################################################
# Configuration
################################################################################

bars=18
vert=0
clean=0
threshold=60

################################################################################
# Helper functions
################################################################################

usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]

Options:
  --vert          Vertical output (JSON)
  --clean         Hide module when idle
  --bars N        Number of bars
  -h, --help      Show this help
EOF
    exit 0
}

validate_bars() {
    [[ "$1" =~ ^[0-9]+$ ]] || {
        echo "Invalid bar count." >&2
        exit 1
    }
}

spotify_playing() {
    playerctl --player=spotify status 2>/dev/null | grep -qx "Playing"
}

################################################################################
# Parse arguments
################################################################################

while [[ $# -gt 0 ]]; do
    case "$1" in
        --vert)
            vert=1
            ;;
        --clean)
            clean=1
            ;;
        --bars)
            bars="$2"
            validate_bars "$bars"
            shift
            ;;
        --bars=*)
            bars="${1#*=}"
            validate_bars "$bars"
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

################################################################################
# Hide module if Spotify isn't playing
################################################################################

while true; do

    if ! spotify_playing; then
        if (( vert )); then
            echo '{"text":""}'
        else
            echo
        fi

        sleep 1
        continue
    fi

    ############################################################################
    # Glyphs
    ############################################################################

    case ${CAVA_GLYPHS:-unicode} in
        unicode)
            glyphs=(
                ▁ ▂ ▃ ▄ ▅ ▆ ▇ █
            )
            ;;
        ascii)
            glyphs=(
                . : - = + '*' '#' @
            )
            ;;
        *)
            exit 1
            ;;
    esac

    config=$(cat <<EOF
[general]
bars=$bars
framerate=60

[output]
method=raw
raw_target=/dev/stdout
data_format=ascii
ascii_max_range=7
EOF
)

    cava -p /dev/fd/3 3<<<"$config" | awk \
        -v vert="$vert" \
        -v clean="$clean" \
        -v threshold="$threshold" \
        -v c0="${glyphs[0]}" \
        -v c1="${glyphs[1]}" \
        -v c2="${glyphs[2]}" \
        -v c3="${glyphs[3]}" \
        -v c4="${glyphs[4]}" \
        -v c5="${glyphs[5]}" \
        -v c6="${glyphs[6]}" \
        -v c7="${glyphs[7]}" '

BEGIN{
c[0]=c0;c[1]=c1;c[2]=c2;c[3]=c3
c[4]=c4;c[5]=c5;c[6]=c6;c[7]=c7
}

{
    split($0,a,";")

    out=""
    idle=1

    for(i=1;i<=length(a);i++){

        v=a[i]+0

        if(v<0)v=0
        if(v>7)v=7

        if(v>0)idle=0

        out=out c[v]
    }

    if(clean && idle){
        count++
        if(count>=threshold){
            if(vert)
                print "{\"text\":\"\"}"
            else
                print ""
            fflush()
            next
        }
    }else{
        count=0
    }

    if(vert){
        print "{\"text\":\"" out "\"}"
    }else{
        print out
    }

    fflush()
}
'

    sleep 1

done
