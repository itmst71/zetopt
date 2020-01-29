#------------------------------------------------------------
# _zetopt::msg
#------------------------------------------------------------
_zetopt::msg::user_error()
{
    if [[ $ZETOPT_CFG_ERRMSG != true ]]; then
        return 0
    fi

    local title="${1-}" text="${2-}" value="${3-}" col=

    # plain text message
    if ! _zetopt::msg::should_decorate $FD_STDERR; then
        \printf >&2 "%b\n" "$ZETOPT_APPNAME: $title: $text$value"
        return 0
    fi

    # color message
    case "$(<<< "$title" \tr "[:upper:]" "[:lower:]")" in
        warning|warn)       col=${ZETOPT_CFG_ERRMSG_COL_WARNING:-"0;0;33"};;
        error)              col=${ZETOPT_CFG_ERRMSG_COL_ERROR:-"0;1;31"};;
        *)                  col="0;1;31";;
    esac
    local textcol="${ZETOPT_CFG_ERRMSG_COL_DEFAULT:-"0;0;39"}"
    local appname="${ZETOPT_CFG_ERRMSG_APPNAME-$ZETOPT_APPNAME}"
    \printf >&2 "\e[${col}m%b\e[0m \e[${textcol}m%b\e[0m \e[${col}m%b\e[0m\n" "$appname: $title:" "$text" "$value"
}

_zetopt::msg::def_error()
{
    _ZETOPT_DEF_ERROR=true
    _zetopt::msg::debug "$@"
}

_zetopt::msg::debug()
{
    if [[ $ZETOPT_CFG_DEBUG != true ]]; then
        return 0
    fi
    local text="${1-}" value="${2-}"
    local src_lineno=${BASH_LINENO-${funcfiletrace[$((0 + $INIT_IDX))]##*:}}
    local appname="${ZETOPT_CFG_ERRMSG_APPNAME-$ZETOPT_APPNAME}"
    local filename="${ZETOPT_SOURCE_FILE_PATH##*/}"
    local title="Script Error"
    local funcname="$(_zetopt::utils::funcname 1)"
    local col="${ZETOPT_CFG_ERRMSG_COL_SCRIPTERR:-"0;1;31"}"
    local textcol="${ZETOPT_CFG_ERRMSG_COL_DEFAULT:-"0;0;39"}"
    local before=2 after=2
    local IFS=$LF stack
    stack=($(_zetopt::utils::stack_trace))
    local caller_info="${stack[$((${#stack[@]} -1 + $INIT_IDX))]}"
    [[ $caller_info =~ \(([0-9]+)\).?$ ]] \
    && local caller_lineno=${BASH_REMATCH[$((1 + $INIT_IDX))]} \
    || local caller_lineno=0
    {
        \printf "\e[${col}m%b\e[0m\n" "$appname: $title: $filename: $funcname ($src_lineno)"
        \printf -- " %b %b\n" "$text" "$value"
        \printf -- "\n\e[1;${col}mStack Trace:\e[m\n"
        \printf -- " -> %b\n" ${stack[@]}
        _zetopt::msg::viewfile "$ZETOPT_CALLER_FILE_PATH" -B $before -A $after -L $caller_lineno \
            | \sed -e 's/^\(0*'$caller_lineno'.*\)/'$'\e['${col}'m\1'$'\e[m/' -e 's/^/    /'
    } >&2
}

_zetopt::msg::viewfile()
{
    local lineno=1 before=2 after=2 filepath=

    while [[ ! $# -eq 0 ]]
    do
        case $1 in
            -L|--line) shift; lineno=${1-}; shift;;
            -B|--before) shift; before=${1-}; shift;;
            -A|--after) shift; after=${1-}; shift;;
            --) shift; filepath=${1-}; shift;;
            *) filepath=${1-}; shift;;
        esac
    done
    if [[ ! -f $filepath ]]; then
        return 1
    fi
    if [[ ! $lineno$before$after =~ ^[0-9]+$ ]]; then
        return 1
    fi
    local lines="$(grep -c "" "$filepath")"
    if [[ $lineno -le 0 || $lineno -gt $lines ]]; then
        return 1
    fi
    if [[ $((lineno - before)) -le 0 ]]; then
        before=$((lineno - 1))
    fi
    if [[ $((lineno + after)) -gt $lines ]]; then
        after=$((lines - lineno))
    fi
    local lastline=$((lineno + after))
    local digits=${#lastline}

    \head -n $((lineno + after)) "$filepath" \
        | \tail -n $((before + after + 1)) \
        | \nl -n rz -w $digits -b a -v $((lineno - before))
}

_zetopt::msg::output()
{
    local fd="${1:-1}"
    if ! zetopt::utils::should_decorate $fd; then
        _zetopt::utils::undecorate
    else
        \cat -- -
    fi
}

_zetopt::msg::should_decorate()
{
    local fd="${1-}"
    local colmode="${ZETOPT_CFG_ERRMSG_COL_MODE:-auto}"
    return $(
        [[ -n ${ZSH_VERSION-} ]] \
        && \setopt localoptions NOCASEMATCH \
        || \shopt -s nocasematch
        if [[ $colmode == auto ]]; then
            if [[ $fd == $FD_STDOUT ]]; then
                echo $TTY_STDOUT
            elif [[ $fd == $FD_STDERR ]]; then
                echo $TTY_STDERR
            else
                echo 1
            fi
        elif [[ $colmode == always ]]; then
            echo 0
        else #never and the others
            echo 1
        fi
    )
}
