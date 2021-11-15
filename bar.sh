#!/bin/bash

# Just for fun :)

# TODO: Implement https:////github.com/hyperupcall/bash-algo/blob/main/pkg/lib/public/bash-algo.sh
# TODO: Implement edit
# TODO: Implement remove
# TODO: Implement timestamp
# TODO: Clean append and create and split up function

SELF="${BASH_SOURCE[0]##*/}"
NAME="${SELF%.sh}"

OPTS="azRXlvnxh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
$USAGE

    Options:
        -a      Append
        -X      Extract
        -l      list
        -v      View
        -n      No dot files
        -R      Don't restore rights
        -z      Compress
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

    Environment Variable:
        BAR_COMPRESS    default : gzip
        BAR_UNCOMPRESS  default : gunzip

    NOTE:
        Currently no compression is scripted
        Currently you can't extract single files in current directory

"

shopt -s nullglob
shopt -s extglob
shopt -s globstar
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

    for key in "${!files[@]}"; do if [[ -d "${files[$key]}" ]]; then barFiles+=("${files[$key]}"/**); else barFiles+=("${files[$key]}"); fi; done

    for file in "${barFiles[@]}"; do if ! [[ -d "$file" ]]; then ((counter++)); printf '%s %s,' "$file" "$counter"; fi; done > "$barName"
    printf '\n' >> "$barName"

    # Now create the bar assoc
    for file in "${barFiles[@]}"; do
        if ! [[ -d "$file" ]]; then
            barFileInfo
            printf '%s %s %s %s %s\n' "$file" "$chmod" "$uid" "$gid" "$content"
        fi
    done >> "$barName"
}

barFileInfo(){
    content="$(_cat $file | base64 -w 0)"
    read -r _ chmod uid gid < <(stat -c '%t %a %u %g' $file)
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

barAppend(){
    local counter
    local tmpBarFile="$(mktemp)"

    while IFS=, read -ra list; do read -r _ counter <<<"${list[-1]}"; break; done < "$barName"

    printf '%s %s,' ${list[@]} > "$tmpBarFile"
    for key in "${!files[@]}"; do if [[ -d "${files[$key]}" ]]; then barFiles+=("${files[$key]}"/**); else barFiles+=("${files[$key]}"); fi; done


    for file in "${barFiles[@]}"; do if ! [[ -d "$file" ]]; then ((counter++)); printf '%s %s,' "$file" "$counter"; fi; done >> "$tmpBarFile"
    printf '\n' >> "$tmpBarFile"

    # Skip first line
    # XXX: With sed and _cat it would be MUCH faster...
    while read -r line ; do
        [[ -z "$s" ]] || { printf '%s\n' "$line" >> "$tmpBarFile"; continue; }
        s=0
    done < "$barName"

    for file in "${barFiles[@]}"; do
        if ! [[ -d "$file" ]]; then
            barFileInfo
            printf '%s %s %s %s %s\n' "$file" "$chmod" "$uid" "$gid" "$content"
        fi
    done >> "$tmpBarFile"

    mv "$tmpBarFile" "$barName"

}

barGetInfo(){
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
    local info=$(barGetInfo)
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

barExtractMkdir(){
    [[ -d "${destination%/}/${name%/*}" ]] || mkdir -p "${destination%/}/${name%/*}"
}

barExtractFile(){
    printf '%s' "$content" | base64 -d > "${destination%/}/$name"
}

barExtractRights(){
    if [[ -z "$noRights" ]]; then
        chown "$uid:$gid"   "${destination%/}/$name"
        chmod "$chmod"      "${destination%/}/$name"
    fi
}

barExtract(){
    local skip=1
    if [[ -z "${files[@]}" ]]; then
        while read -r name chmod uid gid content; do
            ! [[ -z $skip ]] && { unset skip; continue; }
            barExtractMkdir
            barExtractFile
            barExtractRights
        done < "$barName"
    else
        for file in "${files[@]}"; do
            info="$(barGetInfo)"
            [[ -z "$info" ]] && _quit 2 "File ($file) not found"
            read -r name chmod uid gid content <<<"$info"
            barExtractMkdir
            barExtractFile
            barExtractRights
            unset info
        done
    fi
}

barCompress(){
    if ! [[ -z "$compress" ]]; then
        : "${BAR_COMPRESS:=gzip}"
        ${BAR_COMPRESS} "${barName}"
    fi
}

barUncompress(){
    if ! [[ -z "$compress" ]]; then
        : "${BAR_UNCOMPRESS:=gunzip}"
        ${BAR_UNCOMPRESS} "${barName}"
        barName="${barName%.*}"
    fi
}

mode="create"

while getopts "${OPTS}" arg; do
    case "${arg}" in
        x)
            set -x
        ;;
        a)
            mode=append
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
        R)
            noRights=1
        ;;
        z)
            compress=1
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
        barCreate
        barCompress
    ;;
    append)
        files=($@)
        barUncompress
        barAppend
        barCompress
    ;;
    extract)
        destination="${1:-./}"; shift
        files=($@)
        barUncompress
        barExtract
        barCompress
    ;;
    view)
        file="$1"
        barUncompress
        barView
        barCompress
    ;;
    list)
        barUncompress
        barList
        barCompress
    ;;
esac
