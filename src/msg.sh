#------------------------------------------------------------
# _zetopt::msg
#------------------------------------------------------------

# user_error(): Print error message for user
# def.) _zetopt::msg::user_error {TITLE} {VALUE} [MESSAGE]
# e.g.) _zetopt::msg::user_error ERROR foo "Invalid Data"
# STDOUT: NONE
_zetopt::msg::user_error()
{
    if [[ $ZETOPT_CFG_ERRMSG_USER_ERROR != true ]]; then
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

# def_error(): Print definition-error message for script programmer
# def.) _zetopt::msg::def_error {TITLE} {VALUE} [MESSAGE]
# e.g.) _zetopt::msg::def_error ERROR foo "Invalid Data"
# STDOUT: NONE
_zetopt::msg::def_error()
{
    _ZETOPT_DEF_ERROR=true
    _zetopt::msg::debug "$@"
}

# debug(): Print definition-error message for script programmer
# def.) _zetopt::msg::debug {MESSAGE} {VALUE}
# e.g.) _zetopt::msg::debug "Undefined Sub-Command:" "$subcmd"
# STDOUT: NONE
_zetopt::msg::debug()
{
    if [[ $ZETOPT_CFG_ERRMSG_SCRIPT_ERROR != true ]]; then
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
    local IFS=$LF
    if [[ $ZETOPT_CFG_ERRMSG_STACKTRACE == true ]]; then
        local stack=($(_zetopt::utils::stack_trace))
        local caller_info="${stack[$((${#stack[@]} -1 + $INIT_IDX))]}"
        [[ $caller_info =~ \(([0-9]+)\).?$ ]] \
        && local caller_lineno=${BASH_REMATCH[$((1 + $INIT_IDX))]} \
        || local caller_lineno=0
    fi
    {
        \printf "\e[${col}m%b\e[0m\n" "$appname: $title: $filename: $funcname ($src_lineno)"
        \printf -- " %b %b\n" "$text" "$value"
        if [[ $ZETOPT_CFG_ERRMSG_STACKTRACE == true ]]; then
            \printf -- "\n\e[1;${col}mStack Trace:\e[m\n"
            \printf -- " -> %b\n" ${stack[@]}
            _zetopt::utils::viewfile "$ZETOPT_CALLER_FILE_PATH" -B $before -A $after -L $caller_lineno \
                | \sed -e 's/^\(0*'$caller_lineno'.*\)/'$'\e['${col}'m\1'$'\e[m/' -e 's/^/    /'
        fi
    } >&2
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
