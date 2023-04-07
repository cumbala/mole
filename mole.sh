#!/bin/sh

###
### mole.sh
###
### Author: Konstantin Romanets (xroman18), xroman18@stud.fit.vut.cz
### Date:   2023-03-23
### Desc:   Implementation of the mole text editor for IOS Project 1
###
### VUT FIT 2023
###

unset MODE
unset FLAG_M
unset GROUP
unset FILE
unset AFTER_DATE
unset BEFORE_DATE
#DEBUG=1
unset DEBUG
export POSIXLY_CORRECT=YES
GROUP=
FILE=

EDITOR="${EDITOR:-${VISUAL:-vi}}"

error() {
    >&2 echo "\033[31m[Error] $1\033[m"
    exit 1
}
warn() {
    >&2 echo "\033[33m[Warning] $1\033[m"
}
debug_warn() {
    if [ -n "$DEBUG" ]; then
        >&2 echo "\033[33m[Debug] $1\033[m"
    fi
}
debug_echo() {
    if [ -n "$DEBUG" ]; then
        >&2 echo "\033[34m[Debug] $1\033[m"
    fi
}

cmd_exists() {
    if ! command -v "$1" 2>&1 /dev/null
    then
        false
    fi

    true
}

usage() {
    echo "Usage: mole [-g GROUP] [FILTERS] [DIRECTORY] FILE"
}
help() {
    echo "mole - Makes One's Life Easier text editor"
    echo
    echo "Usage: mole.sh [-g GROUP] FILE"
    echo "       mole.sh [-m] [FILTERS] [DIRECTORY]"
    echo "       mole.sh list [FILTERS] [DIRECTORY]"
    echo
    echo "Options:"
    echo "    -h            Show help message"
    echo "    FILE          The file to open in the editor or the path to the folder with files"
    echo "    [-g GROUP]    Specifies the group of files to put FILE into"
    echo "    [-m]          Opens a file in directory that has been opened the most"
    echo "    [FILTERS]     Filters the files to open"
    echo "    [DIRECTORY]   Specifies the directory to open"
    echo "    list          Lists files in directory that have been edited using this program with groups assigned to them"
    echo
    echo "Filters:"
    echo "    -g GROUP1[,GROUP2[,...]]  Filters the files by the groups they are in"
    echo "    -a DATE                   Filters the files after the specified date"
    echo "    -b DATE                   Filters the files before the specified date"
    echo
    echo "Date format: YYYY-MM-DD"


}

now() {
    date +"%Y-%m-%d_%H-%M-%S" 
}

### workarounds for macos bullshit ###
# sed -i
sh_sed() {
    if [ "$(uname)" = "Darwin" ]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# realpath -m / readlink -fm
sh_path() {
    if [ -n "$*" ]; then
        if [ "$(uname)" = "Darwin" ]; then
            if [ "$(cmd_exists "grealpath")" ]; then
                grealpath -m "$@"
            elif [ "$(cmd_exists "greadlink")" ]; then
                greadlink -fm "$@"
            else
                error "sh_path :: realpath not found"
            fi
        else
            if [ "$(cmd_exists "realpath")" ]; then
                realpath -m "$@"
            elif [ "$(cmd_exists "readlink")" ]; then
                readlink -fm "$@"
            else
                error "sh_path :: realpath not found"
            fi
        fi
    fi
}

file_create() {
    if [ -z "$1" ]; then
        error "No file specified"
    else
        mkdir -p -- "$(dirname "$1")" && touch -- "$1"
    fi

    debug_echo "Created file $1"
}

env_check() {
    # Check if MOLE_RC environment variable is set
    if [ -z "$MOLE_RC" ]; then
        error "env_check :: MOLE_RC environment variable not set"
    fi
}

config_check_create() {
    # if MOLE_RC file does not exist, create it
    if [ ! -f "$MOLE_RC" ]; then
        file_create "$MOLE_RC"
        debug_echo "config_create :: molerc created"
    fi
}

# molerc is a csv file
# columns: directory;file;group;count;last_opened;date_1;date_2;...;date_n
# example: config_get "directory" "/home/user"
# params: group, directory, file, count, last_opened
config_add() { 
    if [ -z "$1" ]; then
        GRP=""
    else
        GRP="$1"
    fi
    
    echo "$GRP;$2;$3;$4;$5;$6" >> "$MOLE_RC"
}

# params: group, directory, file
config_find() {
    LINE="$(grep "^$1;$2;$3" "$MOLE_RC")"
    debug_echo "config_find :: LINE = $(echo "$LINE" | cut -d ';' -f 1-5)"
    echo "$LINE"
}

# params: [index_from_top]
config_get_line() {
    if [ -z "$1" ]; then
        INDEX=0
    else
        INDEX="$1"
    fi

    debug_echo "config_get_line :: INDEX = $INDEX"

    LINE="$(tail -n "$INDEX" "$MOLE_RC" | head -n 1)"
    debug_echo "config_get_line :: LINE = $LINE"
    echo "$LINE"
}

config_get_first() {
    config_get_line 1
}

config_get_last() {
    LINE_COUNT="$(wc -l "$MOLE_RC" | cut -d ' ' -f 1)"
    config_get_line "$LINE_COUNT"
}

# params: [dir]
# returns group
config_get_last_opened_group() {
    if [ -z "$1" ]; then
        DIR="$(pwd)"
    else
        DIR="$1"
    fi

#    debug_echo "config_get_last_opened_group :: DIR = $DIR"

    GRP="$(grep ";$DIR;" "$MOLE_RC" | sort -t ';' -k 5 -r | head -n 1 | cut -d ';' -f 1)"
    debug_echo "config_get_last_opened_group :: GRP = $GRP"
    echo "$GRP"
}

# params: [dir], [group]
# returns filename
config_get_last_opened() {
    if [ -z "$1" ]; then
        DIR="$(pwd)"
    else
        DIR="$1"
    fi

    debug_echo "config_get_last_opened :: DIR = $DIR"

    if [ -z "$2" ]; then
        GRP=""
    else
        GRP="$2"
    fi

    if [ -z "$GRP" ]; then
        LAST_OPENED="$(grep ";$DIR;" "$MOLE_RC" | sort -t ';' -k 5 -r | head -n 1)"
#        LAST_OPENED="$LINE"
#        GRP="$(echo "$LINE" | cut -d ';' -f 1)"
    else
        LAST_OPENED="$(grep "^$GRP;$DIR;" "$MOLE_RC" | sort -t ';' -k 5 -r | head -n 1)"
    fi

    if [ -z "$LAST_OPENED" ]; then
        echo ""
        return
    fi

    FILEPATH="$(echo "$LAST_OPENED" | cut -d ';' -f 2)/$(echo "$LAST_OPENED" | cut -d ';' -f 3)"
    debug_echo "config_get_last_opened :: GROUP = $GROUP; LAST_OPENED = $FILEPATH"

    echo "$FILEPATH"
}

# params: [dir]
# returns group
config_get_most_opened_group() {
    if [ -z "$1" ]; then
        DIR="$(pwd)"
    else
        DIR="$1"
    fi
    
    GRP="$(grep ";$DIR;" "$MOLE_RC" | sort -t ';' -k 4 -r | head -n 1 | cut -d ';' -f 1)"
    debug_echo "config_get_most_opened_group :: GRP = $GRP"
    echo "$GRP"
}

# params: [dir]
# returns filename
config_get_most_opened() {
    if [ -z "$1" ]; then
        DIR="$(pwd)"
    else
        DIR="$1"
    fi

    MOST_OPENED="$(grep "$DIR;" "$MOLE_RC" | sort -t ';' -k 4 -r -n | head -n 1)"

    if [ -z "$MOST_OPENED" ]; then
        echo ""
        return
    fi

    FILEPATH="$(echo "$MOST_OPENED" | cut -d ';' -f 2)/$(echo "$MOST_OPENED" | cut -d ';' -f 3)"
    debug_echo "config_get_most_opened :: MOST_OPENED = $FILEPATH"

    echo "$FILEPATH"
}

# params: group, directory, file
config_get_count() {
    COUNT="$(grep "^$1;$2;$3" "$MOLE_RC" | cut -d ';' -f 4)"
    debug_echo "config_get_count :: COUNT = $COUNT"
    echo "$COUNT"
}

# increases the count of the file by 1 and appends the most recent opening date
# moving the previous date one column to the right
# params: directory, file
config_inc_count() {
    COUNT="$(config_get_count "$GROUP" "$1" "$2")"
    NEW_COUNT="$((COUNT + 1))"
    debug_echo "config_inc_count :: NEW_COUNT = $NEW_COUNT"

    LINE="$(config_find "$GROUP" "$1" "$2")"
    
#    if [ "$(echo "$LINE" | ws -l)" -gt 1 ]; then
#        LINE="$(echo "$LINE" | head -n 1)"
#    fi 
    
    debug_echo "config_inc_count :: LINE = $(echo "$LINE" | cut -d ';' -f 1-5)"

    GRP="$(echo "$LINE" | cut -d ';' -f 1)"

    debug_echo "config_inc_count :: GRP=$GRP; GROUP=$GROUP"

    if [ "$GROUP" != "" ] && [ "$GRP" = "" ] || [ "$GRP" != "$GROUP" ]; then
#        NEW_LINE="$(echo "$LINE" | cut -d ';' -f 1-3);$NEW_COUNT;$(now);$(echo "$LINE" | cut -d ';' -f 5-)"
        debug_echo "config_inc_count :: needs new entry"
        config_add "$GROUP" "$1" "$2" "1" "$(now)"
    else
        NEW_LINE="$(echo "$LINE" | cut -d ';' -f 1-3);$NEW_COUNT;$(now);$(echo "$LINE" | cut -d ';' -f 5-)"
        debug_echo "config_inc_count :: NEW_LINE = $(echo "$NEW_LINE" | cut -d ';' -f 1-5)"

        sh_sed "s|$LINE|$NEW_LINE|g" "$MOLE_RC"
    fi
}

# displays the list of all files and their assigned groups
# after_date and before_date are inclusive
# FILE1: group1, group2
# FILE2: group1, group3
# ...
#
# params: [filters: [groups], [after_date], [before_date]], [directory]
display_list() {
    if [ -z "$1" ]; then
        GRP=""
    else
        GRP="$1"
    fi

    if [ -z "$4" ]; then
        DIR="$(pwd)"
    else
        DIR="$4"
    fi

    debug_echo "display_list :: GRP=$GRP; AFTER_DATE=$2; BEFORE_DATE=$3; DIR=$DIR"

    if [ -z "$GRP" ]; then
        LIST="$(grep ";$DIR;" "$MOLE_RC" | cut -d 'f' -f 1-5 |sort -t ';' -k 5 -r)"
    else
        LIST="$(grep "^$GRP;$DIR;" "$MOLE_RC" | cut -d 'f' -f 1-5 | sort -t ';' -k 5 -r)"
    fi
    if [ -n "$2" ]; then
        LIST="$(echo "$LIST" | awk -F ';' -v date="$2" '$5 >= date {print}')"
    fi

    if [ -n "$3" ]; then
        LIST="$(echo "$LIST" | awk -F ';' -v date="$3" '$5 <= date {print}')"
    fi

    if [ -z "$LIST" ]; then
        return
    fi

    echo "$LIST" | awk -F ';' '
    {
        group = $1
        file = $3
        if (file != "") {
            file_count[file]++
            if (file_count[file] == 1) {
                if (group == "") {
                    group = "-"
                }
                file_groups[file] = group
            } else {
                if (group == "") {
                    group = "-"
                }
                file_groups[file] = file_groups[file] ", " group
            }
        }
    }

    END {
        max_len = 0
        for (f in file_groups) {
            len = length(f)
            if (len > max_len) {
                max_len = len
            }
        }
        for (file in file_groups) {
            printf "%s:%*s%s\n", file, max_len - length(file) + 1, " ", file_groups[file]
        }
    }
    ' | sort
}

# format
# FILE1;DATETIME_1;DATETIME_2;...;DATETIME_N
# FILE2;DATETIME_1;DATETIME_2;...;DATETIME_N
# ...
# params: [filters: [groups], [after_date], [before_date]], [directories]
display_log() {
    if [ "$(uname)" = "Darwin" ]; then
        LOG_FILE="/Users/$USER/.mole/log_${USER}_$(now)"
    else
        LOG_FILE="/home/$USER/.mole/log_${USER}_$(now)"
    fi
    
    file_create "$LOG_FILE"

    if [ -z "$1" ]; then
        GRP=""
    else
        GRP="$1"
    fi

    DIR="$4"

    debug_echo "display_log :: GRP=$GRP; AFTER_DATE=$2; BEFORE_DATE=$3; DIR=$DIR"
    
#    echo "$DIR" | while read -d ' ' path; do
#        # filter out all the dirs
#        grep ";$path;" "$MOLE_RC"
#    done
    
    # split $DIR using space as delimiter
    if [ -n "$DIR" ]; then
        if [ -z "$GRP" ]; then
    #        LIST="$(grep ";$DIR;" "$MOLE_RC" | cut -d 'f' -f 1-5 | sort -t ';' -k 5 -r)"
            LIST="$(echo "$DIR" | tr ' ' '\n' | while read -r n; do
                grep ";$n;" "$MOLE_RC"
            done | sort -t ';' -k 5 -r)"
        else
    #        LIST="$(grep "^$GRP;$DIR;" "$MOLE_RC" | cut -d 'f' -f 1-5 | sort -t ';' -k 5 -r)"
            LIST="$(echo "$DIR" | tr ' ' '\n' | while read -r n; do
                grep "^$GRP;$n;" "$MOLE_RC"
            done | sort -t ';' -k 5 -r)"
        fi
    else
        LIST="$(cat "$MOLE_RC")"
    fi
    if [ -n "$2" ]; then
        LIST="$(echo "$LIST" | awk -F ';' -v date="$2" '$5 >= date {print}')"
    fi

    if [ -n "$3" ]; then
        LIST="$(echo "$LIST" | awk -F ';' -v date="$3" '$5 <= date {print}')"
    fi

    if [ -z "$LIST" ]; then
        return
    fi

    # iterate over unique files
    echo "$LIST" | cut -d ';' -f 2-3 | uniq | while read -r file; do
        FILEPATH="$(echo "$file" | cut -d ';' -f 1)"
        FILENAME="$(echo "$file" | cut -d ';' -f 2)"

        DATES="$(echo "$LIST" | grep ";$FILEPATH;$FILENAME;" | cut -d ';' -f 5- | tr '\n' ';' | sed "s|;;|;|g" | sort -r)"

        echo "$FILEPATH/$FILENAME;$DATES" >> "$LOG_FILE"
    done

    bzip2 "$LOG_FILE"
}

parse_args() {
    debug_echo "parse_args :: $*"

    if [ "$1" = "list" ] || [ "$1" = "secret-log" ]; then
        MODE="$1"
        shift 1
    fi

    while getopts ":uhmg:a:b:" opt; do
        case $opt in
            u)
                usage
                exit 0
                ;;
            h)
                help
                exit 0
                ;;
            m)
                FLAG_M=1
                ;;
            g)
                GROUP="$OPTARG"
                ;;
            a)
                AFTER_DATE="$OPTARG"
                ;;
            b)
                BEFORE_DATE="$OPTARG"
                ;;
            \?)
                error "parse_args :: Invalid option: -$OPTARG"
                ;;
            :)
                error "parse_args :: Option -$OPTARG requires an argument."
                ;;
        esac
    done

#    if [ $OPTIND -eq 1 ]; then
#        debug_warn "parse_args :: No options passed"
#    fi

    shift $((OPTIND - 1))

    if [ -z "$MODE" ]; then
        MODE="edit"
    fi

    # Remaining args
    FILE="$*"

    debug_echo "parse_args :: MODE=$MODE; M=$FLAG_M; A=$AFTER_DATE; B=$BEFORE_DATE; G=$GROUP; FILE=$FILE;"
}

start() {
    env_check
    config_check_create
}

editor() {
#    FOLDER="$(ls)"
    $EDITOR "$1"

    # buck you, shellcheck
    # how else am I supposed to check whether a file was created?
    # shellcheck disable=SC2010
    DIFF="$(ls | grep "$1")"
    
    if [ -z "$DIFF" ]; then
        debug_echo "editor :: No changes"
    else
        debug_echo "editor :: File $DIFF created"
        FILE="$(pwd)/$FILE"
    fi
}

main() {
#    if ! setup_editor; then
#        error "main :: No supported text editor found"
#    fi
    debug_echo "main :: EDITOR = $EDITOR"

    start
    parse_args "$@"

    FILE="$(sh_path "$FILE")"

    case $MODE in
        edit)
            debug_echo "main :: Edit mode"

            if [ -z "$FILE" ] || [ -d "$FILE" ]; then
                if [ -n "$FLAG_M" ]; then
                    debug_echo "main :: Most opened file; FILE=$FILE"

                    if [ -z "$GROUP" ]; then
                        GROUP="$(config_get_most_opened_group "$FILE")"
                    fi

                    FILE="$(config_get_most_opened "$FILE")"
                else
                    debug_echo "main :: Most recent file; FILE=$FILE"

                    if [ -z "$GROUP" ]; then
                        GROUP="$(config_get_last_opened_group "$FILE")"
                    fi

                    FILE="$(config_get_last_opened "$FILE" "$GROUP")"
                    debug_echo "main :: GROUP = $GROUP"
                fi

                if [ -z "$FILE" ]; then
                    error "main :: No file specified"
                fi
            fi

            editor "$FILE"

            if [ -n "$(config_find "$GROUP" "$(dirname "$FILE")" "$(basename "$FILE")" )" ]; then
                config_inc_count "$(dirname "$FILE")" "$(basename "$FILE")"
                exit 0
            elif [ "$(dirname "$FILE")" != "." ]; then
                debug_echo "main :: File is in a directory"
                config_add "$GROUP" "$(dirname "$FILE")" "$(basename "$FILE")" "1" "$(now)"
            fi
            ;;
        list)
            debug_echo "main :: List mode"
            display_list "$GROUP" "$AFTER_DATE" "$BEFORE_DATE" "$FILE"
            ;;
        secret-log)
            # $FILE can have multiple directories here
            # as it's parsed as a remainder of the arguments
            debug_echo "main :: Secret log mode"
            display_log "$GROUP" "$AFTER_DATE" "$BEFORE_DATE" "$FILE"
            ;;
    esac

    exit 0
}

main "$@"