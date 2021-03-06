#!/bin/bash

# Just for fun :)

# TODO: Implement https:////github.com/hyperupcall/bash-algo/blob/main/pkg/lib/public/bash-algo.sh

SELF="${BASH_SOURCE[0]##*/}"
# shellcheck disable=SC2034
NAME="${SELF%.sh}"

OPTS="VazrRXlvnxh"
USAGE="Usage: $SELF [$OPTS]"

HELP="
$USAGE

    Options:
        -a      Append
        -X      Extract
        -r      Remove
        -l      list
        -v      View       
        -n      No dot files
        -R      Don't restore rights
        -z      Compress
        -s      Dry-run
        -x      Xtrace
        -V      Verbose (can be call multiple times to get higher level)

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
        BAR_COMPRESS            default : gzip
        BAR_UNCOMPRESS          default : gunzip
        BAR_LOADABLE_PATH       default : /usr/lib/bash

    NOTE:
        Currently you can't extract single files in current directory

        If you use bar without the loadable finfo, you will hit the file limitation

"

shopt -s nullglob
shopt -s extglob
shopt -s globstar
shopt -s dotglob

_quit(){
    local retCode="$1" msg="${*:2}"

    printf '%s \n' "$msg"
    exit "$retCode"
}

_verbose(){
    # This function should be a simple debug function, which will print the line given based on debug level
    # implement in getops the following line:
    # (( DEBUG_LEVEL++))
    local LEVEL=1 c printout
    local funcnamenumber
    (( funcnamenumber=${#FUNCNAME[@]} - 2 ))
    : "${DEBUG_LEVEL:=0}"
    (( DEBUG_LEVEL == 0 )) && return
    # Add level 1 if first char is not set a number
    [[ "$1" =~ ^[0-9]$ ]] && { LEVEL=$1; shift; }
    
    (( LEVEL <= DEBUG_LEVEL )) && {
        until (( ${#c} == LEVEL )); do c+=":"; done
        printout="+ $c    "
        if (( funcnamenumber > 0 )); then
            printout+="("
            for ((i=1;i<=funcnamenumber;i++)); do
                printout+="${FUNCNAME[$i]} <- "
            done
            printout="${printout% <- }) - "
        fi
        printf '%s\n' "$printout $*" 1>&2
    }  
}

# https://github.com/hyperupcall/bash-algo/blob/main/pkg/lib/public/bash-algo.sh
# Replace base64 by using the contenant above and replace cat by usin printf
# This can decrease performance

barFindFiles(){
    _verbose "${files[*]}"

    # Find files to archive and skeep directories
    for key in "${!files[@]}"; do if [[ -d "${files[$key]}" ]]; then barFiles+=("${files[$key]}"/**); else barFiles+=("${files[$key]}"); fi; done
    
    # Get files indexation
    for file in "${barFiles[@]}"; do [[ " ${list[*]} " =~ " $file " ]] && continue; if ! [[ -d "$file" ]]; then ((counter++)); printf '%s %s,' "$file" "$counter"; fi; done
    printf '\n'
}

barCreate() {
    local counter=0

    barFindFiles > "$barName"
    _verbose "${barFiles[*]}"

    _barStat

    for file in "${barFiles[@]}"; do
        if ! [[ -d "$file" ]]; then
            barFileInfo

            _verbose 2 "$file chmod(${chmod[$counter]}) chown(${uid[$counter]}) chgrp(${gid[$counter]}) timestamp(${timestamp[$counter]})"
            printf '%s %s %s %s %s %s\n' "$file" "${chmod[$counter]}" "${uid[$counter]}" "${gid[$counter]}" "${timestamp[$counter]}" "$content"
        fi
    done >> "$barName"
}

barFileInfo(){
    _verbose "$file"
    content="$(base64 -w 0 "$file")"
}

biarGetLine(){
    local line=0
    mapfile -n 1 -t info <"$barName"
    IFS=, read -ra list <<<"${info[0]}"
    
    for key in "${list[@]}"; do
        [[ "${file}" == "${key%% *}" ]] && {
            read -r _ line <<<"$key"
            _verbose "$key"
            printf '%s' "$line"
            return
        }
    done
}

barAppend(){
    _verbose "${files[*]}"
    local counter
    local tmpBarFile
    tmpBarFile="$(mktemp)"

    mapfile -n 1 -t info <"$barName"
    IFS=, read -ra list <<<"${info[0]}"
    read -r _ counter <<<"${list[-1]}"

# shellcheck disable=SC2068
    printf '%s %s,' ${list[@]} > "$tmpBarFile"
    barFindFiles >> "$tmpBarFile"

    orBarFiles=(${barFiles[@]})

    # Skip first line
    # XXX: With sed and _cat it would be MUCH faster...
    while read -r file line ; do
        [[ -z "$s" ]] || { 
            if [[ " ${barFiles[*]} " =~ " $file " ]]; then
                barFiles=($file); _barStat; barFiles=(${orBarFiles[@]})
                barFileInfo
                printf '%s %s %s %s %s %s\n' "$file" "${chmod[0]}" "${uid[0]}" "${gid[0]}" "${timestamp[0]}" "$content" >> "$tmpBarFile"
            else
                printf '%s %s\n' "$file" "$line" >> "$tmpBarFile"
                continue
            fi
        }
        s=0
    done < "$barName"

    _barStat
    counter=0
    for file in "${barFiles[@]}"; do
         [[ " ${list[*]} " =~ " $file " ]] && continue
        if ! [[ -d "$file" ]]; then
            barFileInfo
            printf '%s %s %s %s %s %s\n' "$file" "${chmod[$counter]}" "${uid[$counter]}" "${gid[$counter]}" "${timestamp[$counter]}" "$content"
        fi
    (( counter++ ))
    done >> "$tmpBarFile"

    mv "$tmpBarFile" "$barName"
        
}

barGetInfo(){
    _verbose "$file"
    local counter=0
    local line
    line=$(barGetLine)

    mapfile -n 1 -s "$line" -t info <"$barName"

    read -r name chmod uid gid timestamp content <<<"${info[0]}"
    printf '%s %s %s %s %s %s' "$name" "$chmod" "$uid" "$gid" "$timestamp" "$content"
    return
}

barView(){
    local info
    info=$(barGetInfo)
    _verbose "$info"

    [[ -z "$info" ]] && _quit 2 "File not found"
    read -r _ _ _ _ _ content <<<"$info"
    printf '%s' "$content" | base64 -d | ${PAGER:-less}
    
}

barList(){
    mapfile -n 1 -t info <"$barName"
    _verbose "${info[0]}"
    IFS=, read -ra list <<<"${info[0]}"
    for file in "${list[@]}"; do
        printf '%s\n' "${file[@]%% *}"
    done
}

barExtractMkdir(){
    _verbose 2 "create ${destination%/}/${name%/*}"
    [[ -d "${destination%/}/${name%/*}" ]] || mkdir -p "${destination%/}/${name%/*}"
}

barExtractFile(){
    _verbose 2 "create content to ${destination%/}/$name"
    printf '%s' "$content" | base64 -d > "${destination%/}/$name"
}

barExtractRights(){
    if [[ -z "$noRights" ]]; then
        printf -v timestamp '%(%F %T)T' "$timestamp"
        
        _verbose 2 "set timestamp (${timestamp//\#/ }) to ${destination%/}/$name"
        touch -d "${timestamp//\#/ }"   "${destination%/}/$name"
        
        _verbose 2 "chown ($uid:$gid) to ${destination%/}/$name"
        chown "$uid:$gid"               "${destination%/}/$name"

        _verbose 2 "chmod ($chmod) to ${destination%/}/$name"
        chmod "$chmod"                  "${destination%/}/$name"
    fi
}

barExtract(){
    local skip=1
    if [[ -z "${files[@]}" ]]; then
        _verbose "extract all files"
        while read -r name chmod uid gid timestamp content; do
            ! [[ -z $skip ]] && { unset skip; continue; }
            barExtractMkdir
            barExtractFile
            barExtractRights
        done < "$barName"
    else
        _verbose "extract (${files[@]})"
        for file in "${files[@]}"; do
            info="$(barGetInfo)"
            [[ -z "$info" ]] && _quit 2 "File ($file) not found"
            read -r name chmod uid gid timestamp content <<<"$info"
            barExtractMkdir
            barExtractFile
            barExtractRights
            unset info
        done
    fi
}

barCompress(){
    if ! [[ -z "$compress" ]]; then
        _verbose 2 "Compress using $BAR_COMPRESS"
        ${BAR_COMPRESS} "${barName}"
    fi
}

barUncompress(){
    if ! [[ -z "$compress" ]]; then
        _verbose 2 "Uncompress using $BAR_UNCOMPRESS"
        ${BAR_UNCOMPRESS} "${barName}"
        barName="${barName%.*}"
    fi
}

barRemove(){
    _verbose "${files[@]}"
    local -a toIgnore
    local counter=1
    local tmpBarFile
    tmpBarFile="$(mktemp)"

    while read -r line; do 
        if [[ -z "$s" ]]; then
            IFS=, read -ra list <<<"$line"
            for item in "${list[@]}"; do 
                read -r file line <<<"$item"
# shellcheck disable=SC2076
                [[ " ${files[*]} " =~ " $file " ]] && {
                    toIgnore+=("$line")
                    continue
                }
                filesNewList+="$file $counter,"
                (( counter++ ))
            done
            printf '%s\n' "$filesNewList" > "$tmpBarFile"
            local counter=1
            local s=0
        else
# shellcheck disable=SC2076
            [[ " ${toIgnore[*]} " =~ " $counter " ]] && { (( counter++ )); continue; }
            printf '%s\n' "$line" >> "$tmpBarFile"
            (( counter++ ))
        fi
    done < "$barName"

    mv "$tmpBarFile" "$barName"   
}

barVerify(){
    [[ -z "$barName" ]] && _quit 2 "Bar name not set! $HELP"
    _verbose 3 "$mode"

    case "$mode" in
        create|append|remove)
            [[ -z "$files" ]] && _quit 2 "Files not defined! $HELP"
        ;;&
        extract)
            [[ -z "$destination" ]] && _quit 2 "Destination not defined! $HELP"
        ;;&
        view)
            [[ -z "$file" ]] && _quit 2 "file not defined! $HELP"
        ;;&
    esac

}

_barStat(){
    if PATH= type finfo &>/dev/null; then
        _verbose 2 "using finfo"
        chmod=( $(finfo -o ${barFiles[*]}) )
        uid=( $(finfo -u ${barFiles[*]}) ) 
        gid=( $(finfo -g ${barFiles[*]}) )
        timestamp=( $( finfo -m ${barFiles[*]} ) )
    else
        _verbose 2 "using stat"
        chmod=( $(stat -c '%a' ${barFiles[*]}) )
        uid=( $(stat -c '%u' ${barFiles[*]}) )
        gid=( $(stat -c '%g' ${barFiles[*]}) )
        timestamp=( $(stat -c '%Y' ${barFiles[*]}) )
    fi 
}

barPath(){
    # we will check for each command if they exist, if not use the default builtin
    for _builtin in finfo; do
        [[ -f "${BAR_LOADABLE_PATH%/}/$_builtin" ]] && {
            _verbose 3 "enable ${BAR_LOADABLE_PATH%/}/$_builtin"
            enable -f "${BAR_LOADABLE_PATH%/}/$_builtin" "$_builtin"
        }
    done
}

# create default modules
: "${BAR_COMPRESS:=gzip}"
: "${BAR_UNCOMPRESS:=gunzip}"
: "${BAR_LOADABLE_PATH:=/usr/lib/bash}"

mode="create"

while getopts "${OPTS}" arg; do
    case "${arg}" in
        V)
            (( DEBUG_LEVEL++ ))
        ;;
        x) 
            set -x
        ;;
        a)
            mode=append
        ;;
        r)
            mode=remove
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
barPath

case "$mode" in
    extract)
        destination="${1:-./}"; shift
    ;;&
    create|append|remove|extract)
        files=($@)
    ;;&
    *)
        barVerify
    ;;&
   append|remove|extract|view|list)
        barUncompress
    ;;&
    create)
        barCreate
    ;;&
    append)
        barAppend
    ;;&
    remove)
        barRemove
    ;;&
    extract)
        barExtract
    ;;&
    view)
        file="$1"
        barView
    ;;&
    list)
        barList
    ;;&
    *)
        barCompress
    ;;
esac
