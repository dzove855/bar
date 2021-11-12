#!/bin/bash

# Just for fun :)

# TODO: Implement https:////github.com/hyperupcall/bash-algo/blob/main/pkg/lib/public/bash-algo.sh
# TODO: Implement append
# TODO: Implement edit
# TODO: Implement remove
# TODO: Implement timestamp
# TODO: Implement extract with permissions

SELF="${BASH_SOURCE[0]##*/}"
NAME="${SELF%.sh}"

OPTS="Xlvnxh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
$USAGE

    Options:
        -X      Extract
        -l      list
        -v      View
        -n      No dot files
        -s      Dry-run
        -x      Xtrace

    Example:
        Create a bar file
            $SELF NAME.bar file1 dir1/

        View file in bar
            $SELF -v NAME.bar file

        List files in bar
            $SELF -l NAME.bar

        Extract:
            Extract files in a different folder:
                $SELF -X NAME.bar folder

            Extract files in current folder:
                $SELF -X NAME.bar

            Extract custom files in a different folder:
                $SELF -X NAME.bar folder FILE1 FILE2


    NOTE:
        Currently no compression is scripted
        Currently you can't extract single files in current directory

"

shopt -s nullglob
shopt -s extglob
shopt -s dotglob

_quit(){
    local retCode="$1" msg="${@:2}"

    printf '%s \n' "$msg"
    exit "$retCode"
}

# https://github.com/hyperupcall/bash-algo/blob/main/pkg/lib/public/bash-algo.sh
# Replace base64 by using the contenant above and replace cat by usin printf
# This can decrease performance

_cat(){ printf '%s' "$(<$1)"; }

barCreate() {
    local counter=0

    # XXX: We could jsute use superglob
    dir(){ local file; for file in "${1%/}/"*; do [[ -d "$file" ]] && dir "$file" || barFiles+=($file); done }
    # Get files and look if it is directory or not
    for key in "${!files[@]}"; do if [[ -d "${files[$key]}" ]]; then unset files[$key]; dir "${files[$key]}"; else barFiles+=("${files[$key]}"); fi; done

    for file in "${barFiles[@]}"; do ((counter++)); printf '%s %s,' "$file" "$counter"; done > "$barName"
    printf '\n' >> "$barName"

    # Now create the bar assoc
    for file in "${barFiles[@]}"; do
        content="$(_cat $file | base64 -w 0)"
        read -r _ chmod uid gid < <(stat -c '%t %a %u %g' $file)
        printf '%s %s %s %s %s\n' "$file" "$chmod" "$uid" "$gid" "$content"
    done >> "$barName"
}

barGetLine(){
    local line=0
    while IFS=, read -ra list; do
        for key in "${list[@]}"; do
            [[ "${file}" == "${key%% *}" ]] && {
                read -r _ line <<<"$key"
                printf '%s' "$line"
                return
            }
        done
    done < "$barName"
}

barGetContent(){
    local counter=0
    local line=$(barGetLine)
    while read ; do
        (( ( counter + 1 ) == line )) && {
            read -r name chmod uid gid content
            printf '%s %s %s %s %s' "$name" "$chmod" "$uid" "$gid" "$content"
            return
        }
        (( counter++ ))
    done < "$barName"
}

barView(){
    local info=$(barGetContent)
    [[ -z "$info" ]] && _quit 2 "File not found"
    read -r _ _ _ _ content <<<"$info"
    printf '%s' "$content" | base64 -d | ${PAGER:-less}

}
barList(){
    while IFS=, read -ra file; do
        printf '%s\n' "${file[@]%% *}"
        break
    done < "$barName"
}

barExtract(){
    local skip=1
    if [[ -z "${files[@]}" ]]; then
        while read -r name chmod uid gid content; do
            ! [[ -z $skip ]] && { unset skip; continue; }
            [[ -d "${destination%/}/${name%/*}" ]] || mkdir -p "${destination%/}/${name%/*}"
            printf '%s' "$content" | base64 -d > "${destination%/}/$name"
        done < "$barName"
    else
        for file in "${files[@]}"; do
            info="$(barGetContent)"
            [[ -z "$info" ]] && _quit 2 "File ($file) not found"
            read -r name chmod uid gid content <<<"$info"
            [[ -d "${destination%/}/${name%/*}" ]] || mkdir -p "${destination%/}/${name%/*}"
            printf '%s' "$content" | base64 -d > "${destination%/}/$name"
            unset info
        done
    fi
}

mode="create"

while getopts "${OPTS}" arg; do
    case "${arg}" in
        x)
            set -x
        ;;
        X)
            mode=extract
        ;;
        v)
            mode=view
        ;;
        l)
            mode=list
        ;;
        n)
            shopt -u dotglob
        ;;
        h)
            _quit 0 "$HELP"
        ;;
        ?)
            _quit 1 "Invalid Argument: $USAGE"
        ;;
        *)
            _quit 1 "$USAGE"
        ;;
    esac
done
shift $((OPTIND - 1))

barName="$1"; shift

case "$mode" in
    create)
        files=($@)
        declare -A bar
        barCreate
    ;;
    extract)
        destination="${1:-./}"; shift
        files=($@)
        barExtract
    ;;
    view)
        file="$1"
        barView
    ;;
    list)
        barList
    ;;
esac
