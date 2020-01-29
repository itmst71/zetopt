#------------------------------------------------------------
# _zetopt::utils
#------------------------------------------------------------
_zetopt::utils::funcname()
{
    local skip_stack_count=0
    if [[ -n ${1-} ]]; then
        skip_stack_count=$1
    fi

    if [[ -n ${BASH_VERSION-} ]]; then
        \printf -- "%s" "${FUNCNAME[$((1 + $skip_stack_count))]}"
    elif [[ -n ${ZSH_VERSION-} ]]; then
        \printf -- "%s" "${funcstack[$((1 + $skip_stack_count + $INIT_IDX))]}"
    fi
}

_zetopt::utils::stack_trace()
{
    local IFS=$' '
    local skip_stack_count=1
    if [[ -n ${1-} ]]; then
        skip_stack_count=$1
    fi
    local funcs_start_idx=$((skip_stack_count + 1))
    local lines_start_idx=$skip_stack_count
    local funcs lines i
    funcs=()
    lines=()
    if [[ -n ${BASH_VERSION-} ]]; then
        funcs=("${FUNCNAME[@]:$funcs_start_idx}")
        funcs[$((${#funcs[@]} - 1))]=$ZETOPT_CALLER_NAME
        lines=("${BASH_LINENO[@]:$lines_start_idx}")
    elif [[ -n ${ZSH_VERSION-} ]]; then
        \setopt localoptions KSH_ARRAYS
        funcs=("${funcstack[@]:$funcs_start_idx}" "$ZETOPT_CALLER_NAME")
        lines=("${funcfiletrace[@]:$lines_start_idx}")
        lines=("${lines[@]##*:}")
    fi
    for ((i=0; i<${#funcs[@]}; i++))
    do
        \printf -- "%s (%s)\n" "${funcs[$i]}" "${lines[$i]}"
    done
}

_zetopt::utils::repeat()
{
    if [[ $# -ne 2 || ! $1 =~ ^[1-9][0-9]*$ ]]; then
        _zetopt::msg::debug "Invalid Argument:" "_zetopt::utils::repeat <REPEAT_COUNT> <STRING>"
        return 1
    fi
    local IFS=$' '
    local repstr="${2//\//\\/}"
    \printf -- "%0*d" $1 | \sed -e "s/0/$repstr/g"
}

_zetopt::utils::seq()
{
    local start= end= delim= custom_delim=false error=

    while [[ ! $# -eq 0 ]]
    do
        case $1 in
            -d|--delemiter) shift; delim=${1-}; custom_delim=true; shift;;
            --) start=$1; shift; end=${1-}; shift; break ;;
            *)
                if [[ -z $start ]]; then
                    start=$1
                elif [[ -z $end ]]; then
                    end=$1
                else
                    error=true
                    break
                fi
                shift ;;
        esac
    done
    if [[ -z $start || -z $end ]]; then
        error=true
    fi
    
    if [[ $error == true ]]; then
        _zetopt::msg::debug "_zetopt::utils::seq <START> <END> [-d,--delimiter <DELIMITER>]"
        return 1
    fi

    if [[ ! $start =~ ^([a-zA-Z]|-?[0-9]+)$ ]] || [[ ! $end =~ ^([a-zA-Z]|-?[0-9]+)$ ]]; then
        _zetopt::msg::debug "Accepts:" "^([a-zA-Z]|-?[0-9]+)$"
        return 1
    fi

    if [[ $custom_delim == true ]]; then
        \eval "echo {$start..$end}" | \sed -e "s/ /$delim/g"
    else
        \eval "echo {$start..$end}"
    fi
}

_zetopt::utils::isLangCJK()
{
    return $(
        [[ -n ${ZSH_VERSION-} ]] \
        && \setopt localoptions NOCASEMATCH \
        || \shopt -s nocasematch
        [[ ${1-} =~ ^(zh_|ja_|ko_) ]] && echo 0 || echo 1
    )
}

_zetopt::utils::fold()
{
    local lang="${_LC_ALL:-${_LANG:-en_US.UTF-8}}" indent_str=" "
    declare -i width=80 min_width=4 indent_cnt=0 tab_cnt=4
    local error=false tab_spaces=
    while [[ $# -ne 0 ]]
    do
        case "$1" in
            -w | --width)
                if [[ ${2-} =~ ^-?[0-9]+$ ]]; then
                    width=$([[ $2 -ge $min_width ]] && printf -- "%s" $2 || echo $min_width)
                else
                    error=true; break
                fi
                shift 2;;
            -l | --lang)
                if [[ -n ${2-} ]]; then
                    lang=$2
                else
                    error=true; break
                fi
                shift 2;;
            -i | --indent)
                if [[ ${2-} =~ ^-?[0-9]+$ ]]; then
                    indent_cnt=$([[ $2 -ge 0 ]] && echo $2 || echo 0)
                else
                    error=true; break
                fi
                shift 2;;
            --indent-string)
                if [[ -n ${2-} ]]; then
                    indent_str=$2
                else
                    error=true; break
                fi
                shift 2;;
            -t | --tab)
                if [[ ${2-} =~ ^-?[0-9]+$ ]]; then
                    tab_cnt=$([[ $2 -ge 0 ]] && printf -- "%s" $2 || echo 4)
                else
                    error=true; break
                fi
                shift 2;;
            --) shift; break;;
            *)  shift; error=true; break;;
        esac
    done
    if [[ $error == true ]]; then
        _zetopt::msg::debug "Usage:" "echo \"\$str\" | _zetopt::utils::fold [-w|--width <WIDTH>] [-l|--lang <LANG>] [-i|--indent <INDENT_COUNT>] [--indent-string <INDENT_STRING>] [-t|--tab <SPACES_COUNT>]"
        return 1
    fi

    local LC_ALL=
    local LANG="en_US.UTF-8" #$(locale -a | grep -iE "^${lang//-/}$" || echo "en_US.UTF-8")
    declare -i wide_char_width=$(_zetopt::utils::isLangCJK "$lang" && echo 2 || echo 1)
    declare -i max_buff_size=$width buff_size curr mbcnt pointer=0 skip
    local IFS=$LF
    local line tmp_buff buff indent=
    if [[ $indent_cnt -ne 0 ]]; then
        indent=$(_zetopt::utils::repeat $indent_cnt "$indent_str")
    fi

    tab_spaces=$(\printf "%${tab_cnt}s" " ")

    while <&0 \read -r line || [[ -n $line ]]
    do
        line=${line//$'\t'/$tab_spaces} # convert tabs to 4 sapces
        line_len=${#line}
        curr=0 pointer=0
        rest_buff_size=$max_buff_size
        while true
        do
            curr_buff_size=$rest_buff_size/$wide_char_width
            tmp_buff=${line:$pointer:$curr_buff_size}
            ascii=${tmp_buff//[! -\~]/}
            mbcnt=${#tmp_buff}-${#ascii}
            rest_buff_size=$((rest_buff_size - mbcnt * wide_char_width - ${#ascii}))
            pointer+=$curr_buff_size
            if [[ $pointer -le $line_len && $rest_buff_size -ge 2 ]]; then
                continue
            fi

            # smart folding
            skip=0
            if [[ $rest_buff_size -eq 1 ]]; then
                if [[ ${line:$pointer:1} =~ ^[\!-/:-@\{-\~]$ ]]; then
                    pointer+=1
                fi

                if [[ ${line:$pointer:2} =~ ^[\ -\~]\ $ ]]; then
                    pointer+=1
                fi
            fi
            if [[ ${line:$((pointer - 2)):2} =~ ^\ [\ -\~]{1,2}$ ]]; then
                pointer=$pointer-1
            elif [[ ${line:$pointer:1} == " " ]]; then
                skip=1
            fi

            total_buff_size=$pointer-$curr
            buff=${line:$curr:$total_buff_size}
            printf -- "%s\n" "$indent$buff"

            curr+=$total_buff_size+$skip
            pointer=$curr
            rest_buff_size=$max_buff_size

            if [[ $curr -ge $line_len ]]; then
                break
            fi
        done
    done
}

_zetopt::utils::undecorate()
{
    if [[ $# -eq 0 ]]; then
        \sed 's/'$'\033''\[[0-9;]*[JKmsu]//g'
    else
        \sed 's/'$'\033''\[[0-9;]*[JKmsu]//g' <<< "$*"
    fi
}

_zetopt::utils::quote()
{
    local q="'" qq='"' str arr
    arr=()
    for str in "$@"; do
        arr+=("'${str//$q/$q$qq$q$qq$q}'")
    done
    local IFS=$' '
    \printf -- "%s\n" "${arr[*]}"
}

_zetopt::utils::max()
{
    if [[ $# -ne 2 ]]; then
        return 1
    fi
    [[ $1 -ge $2 ]] \
    && \printf -- "%s\n" "$1" \
    || \printf -- "%s\n" "$2"
}

_zetopt::utils::min()
{
    if [[ $# -ne 2 ]]; then
        return 1
    fi
    [[ $1 -le $2 ]] \
    && \printf -- "%s\n" "$1" \
    || \printf -- "%s\n" "$2"
}
