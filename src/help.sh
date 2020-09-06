#------------------------------------------------------------
# _zetopt::help
#------------------------------------------------------------
_zetopt::help::init()
{
    local IFS=" "
    _ZETOPT_HELPS_IDX=(
        "0:NAME"
        "1:VERSION"
        "2:USAGE"
        "3:SYNOPSIS"
        "4:DESCRIPTION"
        "5:OPTIONS"
        "6:COMMANDS"
    )
    _ZETOPT_HELPS=("_" "" "" "_" "" "_" "_")
    _ZETOPT_HELPS_CUSTOM=
}

_zetopt::help::search()
{
    local title="${1-}"
    if [[ -z $title ]]; then
        return $ZETOPT_IDX_NOT_FOUND
    fi
    printf -- "%s" "$(
        [[ -n ${ZSH_VERSION-} ]] \
        && setopt localoptions NOCASEMATCH \
        || shopt -s nocasematch
        local IFS=$_LF
        [[ "$_LF${_ZETOPT_HELPS_IDX[*]}$_LF" =~ $_LF([0-9]+):$title$_LF ]] \
        && printf -- "%s" ${BASH_REMATCH[1]} \
        || printf -- "%s" $ZETOPT_IDX_NOT_FOUND
    )"
}

_zetopt::help::body()
{
    local title="${1-}"
    local idx=$(_zetopt::help::search "$title")
    if [[ $idx != $ZETOPT_IDX_NOT_FOUND ]]; then
        printf -- "%s\n" "${_ZETOPT_HELPS[$idx]}"
    fi
}

_zetopt::help::define()
{
    if [[ -z ${_ZETOPT_HELPS_IDX[@]-} ]]; then
        _zetopt::help::init
    fi

    if [[ ${1-} == "--rename" ]]; then
        shift
        _zetopt::help::rename "$@" \
        && return $? || return $?
    fi

    local title="${1-}"
    local idx=$(_zetopt::help::search "$title")
    if [[ $idx == $ZETOPT_IDX_NOT_FOUND ]]; then
        idx=${#_ZETOPT_HELPS[@]}
    fi
    _ZETOPT_HELPS_CUSTOM="${_ZETOPT_HELPS_CUSTOM%:}:$idx:"
    local refidx=$idx
    _ZETOPT_HELPS_IDX[$refidx]="$idx:$title"
    shift 1
    local IFS=
    _ZETOPT_HELPS[$refidx]="$*"
}

_zetopt::help::rename()
{
    if [[ -z ${_ZETOPT_HELPS_IDX[@]-} ]]; then
        _zetopt::help::init
    fi
    if [[ $# -ne 2 || -z ${1-} || -z ${2-} ]]; then
        _zetopt::msg::script_error "Usage:" "zetopt def-help --rename <OLD_TITLE> <NEW_TITLE>"
        return 1
    fi
    local oldtitle="$1"
    local newtitle="$2"
    local idx=$(_zetopt::help::search "$oldtitle")
    if [[ $idx == $ZETOPT_IDX_NOT_FOUND ]]; then
        _zetopt::msg::script_error "No Such Help Title: $oldtitle"
        return 1
    fi
    if [[ $(_zetopt::help::search "$newtitle") -ne $ZETOPT_IDX_NOT_FOUND ]]; then
        _zetopt::msg::script_error "Already Exists: $newtitle"
        return 1
    fi
    local refidx=$idx
    _ZETOPT_HELPS_IDX[$refidx]="$idx:$newtitle"
}

_zetopt::help::show()
{
    if [[ -z ${_ZETOPT_HELPS_IDX[@]-} ]]; then
        _zetopt::help::init
    fi
    declare -i idx_name=0 idx_synopsis=3 idx_options=5 idx_commands=6 idx=0
    declare -i _TERM_MAX_COLS=$(($(\tput cols) - 3))
    declare -i default_max_cols=1000
    declare -i _MAX_COLS=$(_zetopt::utils::min $_TERM_MAX_COLS $default_max_cols)
    declare -i _BASE_COLS=0
    declare -i _OPT_COLS=4
    declare -i _OPT_DESC_MARGIN=2
    declare -i _INDENT_STEP=4
    declare -i _INDENT_LEVEL=0
    local _DECORATION=false
    local IFS body bodyarr title titles cols indent_cnt deco_title
    local _DECO_BOLD= _DECO_END=
    if _zetopt::msg::should_decorate $_FD_STDOUT; then
        _DECO_BOLD="\e[1m"
        _DECO_END="\e[m"
        _DECORATION=true
    fi

    titles=()
    local _HELP_LANG="${_LC_ALL:-${_LANG:-en_US.UTF-8}}" error=false
    while [[ $# -ne 0 ]]
    do
        case "$1" in
            -l | --lang)
                if [[ -n ${2-} ]]; then
                    _HELP_LANG=$2
                else
                    error=true; break
                fi
                shift 2;;
            --) shift; titles+=("$@"); break;;
            *)  titles+=("$1"); shift;;
        esac
    done
    if [[ $error == true ]]; then
        _zetopt::msg::script_error "Usage:" "zetopt show-help [--lang <LANG>] [HELP_TITLE ...]"
        return 1
    fi
    IFS=" "
    if [[ -z "${titles[@]-}" ]]; then
        titles=("${_ZETOPT_HELPS_IDX[@]#*:}")
    fi
    IFS=$_LF
    
    for title in "${titles[@]}"
    do
        idx=$(_zetopt::help::search "$title")
        if [[ $idx -eq $ZETOPT_IDX_NOT_FOUND || -z "${_ZETOPT_HELPS[$idx]-}" ]]; then
            continue
        fi

        # Default NAME
        if [[ $idx == $idx_name && ! $_ZETOPT_HELPS_CUSTOM =~ :${idx_name}: ]]; then
            body="$_DECO_BOLD$ZETOPT_CALLER_NAME$_DECO_END"
            _zetopt::help::general "$title" "$body"

        # Default SYNOPSIS
        elif [[ $idx == $idx_synopsis && ! $_ZETOPT_HELPS_CUSTOM =~ :${idx_synopsis}: ]]; then
            _zetopt::help::synopsis "$title"
        
        # Default OPTIONS
        elif [[ $idx == $idx_options && ! $_ZETOPT_HELPS_CUSTOM =~ :${idx_options}: ]]; then
            _zetopt::help::fmtcmdopt "$title" --options
        
        # Default COMMANDS
        elif [[ $idx == $idx_commands && ! $_ZETOPT_HELPS_CUSTOM =~ :${idx_commands}: ]]; then
            _zetopt::help::fmtcmdopt "$title" --commands

        # User Customized Helps
        else
            body="${_ZETOPT_HELPS[$idx]}"
            _zetopt::help::general "$title" "$body"
        fi
    done
}

_zetopt::help::general()
{
    local title="${1-}"
    local body="${2-}"
    printf -- "$(_zetopt::help::indent)%b\n" "$_DECO_BOLD$title$_DECO_END"
    _INDENT_LEVEL+=1
    declare -i indent_cnt=$((_BASE_COLS + _INDENT_STEP * _INDENT_LEVEL))
    declare -i cols=$_MAX_COLS-$indent_cnt
    printf -- "%b\n" "$body" | _zetopt::utils::fold --width $cols --indent $indent_cnt --lang "$_HELP_LANG"
    _INDENT_LEVEL=$_INDENT_LEVEL-1
    echo " "
}

_zetopt::help::indent()
{
    local additional_cols=0
    if [[ ! -z ${1-} ]]; then
        additional_cols=$1
    fi
    declare -i count=$((_BASE_COLS + _INDENT_STEP * _INDENT_LEVEL + additional_cols))
    printf -- "%${count}s" ""
}

_zetopt::help::synopsis()
{
    local title="${1-}"
    local IFS=$_LF app="$ZETOPT_CALLER_NAME"
    local ns cmd has_arg has_arg_req has_opt has_sub line args bodyarr
    declare -i idx loop cmdcol
    local did_output=false
    local nslist
    nslist=($(_zetopt::def::namespaces))
    if [[ ${#nslist} -eq 0 ]]; then
        return 0
    fi

    printf -- "$(_zetopt::help::indent)%b\n" "$_DECO_BOLD$title$_DECO_END"
    _INDENT_LEVEL+=1

    for ns in ${nslist[@]}
    do
        line= has_arg=false has_arg_req=false has_opt=false has_sub=false args=
        cmd="$app"
        if [[ $ns != / ]]; then
            cmd="$cmd${ns//[\/]/ }"
            cmd=${cmd% }
        fi
        
        # has option
        if _zetopt::def::has_options $ns; then
            has_opt=true
            line="$line $(_zetopt::help::synopsis_options $ns)"
        fi

        # has arguments
        if _zetopt::def::has_arguments $ns; then
            has_arg=true
            args=$(_zetopt::help::format --synopsis "$(_zetopt::def::field "$ns")")
            line="${line%%\ } ${args#\ }"
        fi

        if [[ $has_opt == false && $has_arg == false ]]; then
            continue
        fi
        did_output=true

        # has sub-command
        if _zetopt::def::has_subcmd $ns; then
            has_sub=true
        fi

        cmdcol=${#cmd}+1
        if [[ $_DECORATION == true ]]; then
            cmd=$(IFS=" "; printf -- "$_DECO_BOLD%s$_DECO_END " $cmd)
        fi
        cmd=${cmd% }
        
        loop=1
        if [[ $ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR == false && $has_arg == true && $has_sub == true ]]; then
            if [[ $has_opt == false ]]; then
                line="--$line"
            else
                loop=2
            fi
        fi
        
        local base_indent=$(_zetopt::help::indent)
        local cmd_indent=$(_zetopt::help::indent $cmdcol)
        declare -i cols=$((_MAX_COLS - _BASE_COLS - _INDENT_STEP * _INDENT_LEVEL - cmdcol))
        for ((idx=0; idx<$loop; idx++))
        do
            bodyarr=($(printf -- "%b" "$line" | _zetopt::utils::fold --width $cols --lang "$_HELP_LANG"))
            printf -- "$base_indent%b\n" "$cmd ${bodyarr[0]# *}"
            if [[ ${#bodyarr[@]} -gt 1 ]]; then
                if [[ $ZETOPT_OLDBASH == true ]]; then
                    unset bodyarr[0]
                    printf -- "$cmd_indent%b\n" "${bodyarr[@]}"
                else
                    printf -- "$cmd_indent%b\n" "${bodyarr[@]:1}"
                fi
            fi
            line="--$args"
        done | _zetopt::help::decorate --synopsis
    done

    if [[ $did_output == false ]]; then
        printf -- "$(_zetopt::help::indent)%b\n" "$_DECO_BOLD$app$_DECO_END"
    fi
    _INDENT_LEVEL=$_INDENT_LEVEL-1
    echo " "
}

_zetopt::help::decorate()
{
    if [[ $_DECORATION == false ]]; then
        \cat -- -
        return 0
    fi

    if [[ ${1-} == "--synopsis" ]]; then
        \sed < /dev/stdin \
            -e 's/\([\[\|]\)\(-\{1,2\}[a-zA-Z0-9_-]\{1,\}\)/\1'$'\e[1m''\2'$'\e[m''/g'
            #-e 's/<\([^>]\{1,\}\)>/<'$'\e[3m''\1'$'\e[m''>/g'

    elif [[ ${1-} == "--options" ]]; then
        \sed < /dev/stdin \
            -e 's/^\( *\)\(-\{1,2\}[a-zA-Z0-9_-]\{1,\}\), \(--[a-zA-Z0-9_-]\{1,\}\)/\1\2, '$'\e[1m''\3'$'\e[m''/g' \
            -e 's/^\( *\)\(-\{1,2\}[a-zA-Z0-9_-]\{1,\}\)/\1'$'\e[1m''\2'$'\e[m''/g'
            #-e 's/<\([^>]\{1,\}\)>/<'$'\e[3m''\1'$'\e[m''>/g'
    else
        \cat -- -
    fi
}

_zetopt::help::synopsis_options()
{
    local IFS=$_LF ns="${1-}" line
    for line in $(_zetopt::def::options "$ns")
    do
        printf -- "[%s] " "$(_zetopt::help::format --synopsis "$line")"
    done
}

_zetopt::help::fmtcmdopt()
{
    local title="${1-}"
    local subcmd_mode=$([[ ${2-} == "--commands" ]] && echo true || echo false)
    local id tmp desc optarg cmd helpidx cmdhelpidx arghelpidx optlen subcmd_title
    local nslist ns prev_ns=/
    local incremented=false did_output=false
    local IFS=$_LF indent
    declare -i cols max_cols indent_cnt 

    local sub_title_deco= sub_deco=
    if [[ $_DECORATION == true ]]; then
        sub_title_deco="\e[4;1m"
        sub_deco="\e[1m"
    fi

    [[ $subcmd_mode == true ]] \
    && nslist=$(_zetopt::def::namespaces) \
    || nslist=/

    for ns in ${nslist[@]}
    do
        if [[ $subcmd_mode == true && $ns == / ]]; then
            continue
        fi
        for line in $(_zetopt::def::field $ns) $(_zetopt::def::options $ns)
        do
            id=${line%%:*} cmd= cmdcol=0
            if [[ "$id" == / ]]; then
                prev_ns=$ns
                continue
            fi

            if [[ $did_output == false ]]; then
                did_output=true
                printf -- "$(_zetopt::help::indent)%b\n" "$_DECO_BOLD$title$_DECO_END"
                _INDENT_LEVEL+=1
            fi

            helpidx=${line##*:}
            cmdhelpidx=0
            arghelpidx=0

            # sub-command
            if [[ $helpidx =~ [0-9]+\ [0-9]+ ]]; then
                cmdhelpidx=${helpidx% *}
                arghelpidx=${helpidx#* }
                helpidx=$arghelpidx
                cmd="${id:1:$((${#id}-1))}"
                cmd="${cmd//\// }"
                cmdcol=$((${#cmd} + 1))
            fi

            if [[ $subcmd_mode == true && $ns != $prev_ns && $incremented == true ]]; then
                _INDENT_LEVEL=$_INDENT_LEVEL-1
                incremented=false
            fi

            optarg=$(_zetopt::help::format "$line")
            optlen=$((${#optarg} + $cmdcol))

            if [[ $prev_ns != $ns ]]; then 
                subcmd_title=$(IFS=" "; printf -- "$sub_title_deco%s$_DECO_END " $cmd)
                printf -- "$(_zetopt::help::indent)%b\n" "$subcmd_title"
                _INDENT_LEVEL+=1
                prev_ns=$ns
                incremented=true

                if [[ $cmdhelpidx -ne 0 ]]; then
                    # calc rest cols
                    indent_cnt=$((_BASE_COLS + _INDENT_STEP * _INDENT_LEVEL))
                    cols=$_MAX_COLS-$indent_cnt
                    printf -- "%b\n" "$(<<<"${_ZETOPT_OPTHELPS[$cmdhelpidx]}" _zetopt::utils::fold --width $cols --indent $indent_cnt --lang "$_HELP_LANG")"
                    printf -- "%s\n" " "
                fi

                # no arg: sub-command itself
                if [[ $optlen == $cmdcol ]]; then
                    continue
                fi
                cmd=$(IFS=" "; printf -- "$sub_deco%s$_DECO_END " $cmd)
            fi

            optarg="$cmd${optarg# }"

            # calc rest cols
            indent_count=$((_BASE_COLS + _OPT_COLS + _OPT_DESC_MARGIN + _INDENT_STEP * _INDENT_LEVEL))
            indent=$(printf -- "%${indent_count}s" "")
            cols=$(($_MAX_COLS - $indent_count))
            desc=("")
            if [[ $helpidx -ne 0 ]]; then
                desc=($(printf -- "%b" "${_ZETOPT_OPTHELPS[$helpidx]}" | _zetopt::utils::fold --width $cols --lang "$_HELP_LANG"))
            fi
            if [[ $optlen -le $(($_OPT_COLS)) ]]; then
                printf -- "$(_zetopt::help::indent)%-$(($_OPT_COLS + $_OPT_DESC_MARGIN))s%s\n" "$optarg" "${desc[0]}"
                if [[ ${#desc[@]} -gt 1 ]]; then
                    if [[ $ZETOPT_OLDBASH == true ]]; then
                        unset desc[0]
                        printf -- "$indent%s\n" "${desc[@]}"
                    else
                        printf -- "$indent%s\n" "${desc[@]:1}"
                    fi
                fi
            else
                printf -- "$(_zetopt::help::indent)%s\n" "$optarg"
                if [[ -n "${desc[@]}" ]]; then
                    printf -- "$indent%s\n" "${desc[@]}"
                fi
            fi
            printf -- "%s\n" " "
        done
    done | _zetopt::help::decorate --options

    if [[ $incremented == true ]]; then
        _INDENT_LEVEL=$_INDENT_LEVEL-1
    fi

    if [[ $did_output == true ]]; then
        echo " "
        _INDENT_LEVEL=$_INDENT_LEVEL-1
    fi
}

_zetopt::help::format()
{
    local id deftype short long args dummy opt optargs default_argname
    local sep=", " synopsis=false
    if [[ ${1-} == "--synopsis" ]]; then
        synopsis=true
        sep="|"
        shift
    fi
    local IFS=:
    set -- ${1-}
    id=${1-}
    deftype=${2-}
    short=${3-}
    long=${4-}
    args=${5-}
    IFS=$_LF
    
    if [[ $deftype == c ]]; then
        default_argname=ARG_
    else
        default_argname=OPTARG_
        if [[ -n $short ]]; then
            opt="-$short"
            if [[ -n $long ]]; then
                opt="$opt$sep--$long"
            fi
        elif [[ -n $long ]]; then
            opt="--$long"
        fi
    fi

    optargs=${opt-}

    if [[ -n $args ]]; then
        args=${args//-/}
        IFS=" "
        declare -i cnt=1
        local arg param default_idx default_value=
        for arg in $args
        do
            param=${arg%%.*}
            default_idx=${arg#*=}
            default_value=
            if [[ $default_idx -ne 0 ]]; then
                default_value="=${_ZETOPT_DATA[$default_idx]}"
            fi
            if [[ $param == @ ]]; then
                optargs+=" <$default_argname$cnt>"
            elif [[ $param == % ]]; then
                optargs+=" [<$default_argname$cnt$default_value>]"
            elif [[ ${param:0:1} == @ ]]; then
                optargs+=" <${param:1}>"
            elif [[ ${param:0:1} == % ]]; then
                optargs+=" [<${param:1}$default_value>]"
            fi
            cnt+=1
        done
        # variable length
        if [[ $arg =~ ([.]{3,3}[0-9]*)= ]]; then
            optargs="${optargs:0:$((${#optargs} - 1))}${BASH_REMATCH[1]}]"
        fi
        IFS=$_LF
    fi
    printf -- "%b" "$optargs"
}
