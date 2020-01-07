#------------------------------------------------------------
# Global Constant Variables
#------------------------------------------------------------
# bash
if [[ -n ${BASH_VERSION-} ]]; then
    readonly ZETOPT_SOURCE_FILE_PATH="${BASH_SOURCE:-$0}"
    readonly ZETOPT_ROOT="$(builtin cd "$(dirname "$ZETOPT_SOURCE_FILE_PATH")" && pwd)"
    readonly ZETOPT_CALLER_FILE_PATH="$0"
    readonly ZETOPT_CALLER_NAME="${ZETOPT_CALLER_FILE_PATH##*/}"
    readonly ZETOPT_OLDBASH="$([[ ${BASH_VERSION:0:1} -le 3 ]] && \echo true || \echo false)"
    readonly ZETOPT_IDX_OFFSET=0
# zsh
elif [[ -n ${ZSH_VERSION-} ]]; then
    readonly ZETOPT_SOURCE_FILE_PATH="$0"
    readonly ZETOPT_ROOT="${${(%):-%x}:A:h}"
    readonly ZETOPT_CALLER_FILE_PATH="${funcfiletrace%:*}"
    readonly ZETOPT_CALLER_NAME="${ZETOPT_CALLER_FILE_PATH##*/}"
    readonly ZETOPT_OLDBASH=false
    readonly ZETOPT_IDX_OFFSET=$([[ $'\n'$(\setopt) =~ $'\n'ksharrays ]] && \echo 0 || \echo 1)
else
    echo >&2 "zetopt: Fatal Error: Bash 3.2+ / Zsh 5.0+ Required"
    return 1
fi

# field numbers for definition
readonly ZETOPT_FIELD_DEF_ALL=0
readonly ZETOPT_FIELD_DEF_ID=1
readonly ZETOPT_FIELD_DEF_SHORT=2
readonly ZETOPT_FIELD_DEF_LONG=3
readonly ZETOPT_FIELD_DEF_ARG=4
readonly ZETOPT_FIELD_DEF_HELP=5

# field numbers for parsed data
readonly ZETOPT_FIELD_DATA_ALL=0
readonly ZETOPT_FIELD_DATA_ID=1
readonly ZETOPT_FIELD_DATA_ARG=2
readonly ZETOPT_FIELD_DATA_TYPE=3
readonly ZETOPT_FIELD_DATA_STATUS=4
readonly ZETOPT_FIELD_DATA_COUNT=5

# types
readonly ZETOPT_TYPE_CMD=0
readonly ZETOPT_TYPE_SHORT=1
readonly ZETOPT_TYPE_LONG=2
readonly ZETOPT_TYPE_PLUS=3

# parse status
readonly ZETOPT_STATUS_NORMAL=0
readonly ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS=$((1 << 0))
readonly ZETOPT_STATUS_MISSING_OPTIONAL_ARGS=$((1 << 1))
readonly ZETOPT_STATUS_VALIDATOR_FAILED=$((1 << 2))
readonly ZETOPT_STATUS_TOO_MATCH_ARGS=$((1 << 3))
readonly ZETOPT_STATUS_MISSING_REQUIRED_OPTARGS=$((1 << 4))
readonly ZETOPT_STATUS_MISSING_REQUIRED_ARGS=$((1 << 5))
readonly ZETOPT_STATUS_UNDEFINED_OPTION=$((1 << 6))
readonly ZETOPT_STATUS_UNDEFINED_SUBCMD=$((1 << 7))
readonly ZETOPT_STATUS_INVALID_OPTFORMAT=$((1 << 8))
readonly ZETOPT_STATUS_ERROR_THRESHOLD=$((ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS | ZETOPT_STATUS_MISSING_OPTIONAL_ARGS))

# misc
readonly ZETOPT_IDX_NOT_FOUND=-1


#------------------------------------------------------------
# Main
#------------------------------------------------------------
# zetopt {SUB-COMMAND} [ARGS]
# STDOUT: depending on each sub-commands
zetopt()
{
    declare -r _PATH=$PATH
    local PATH="/usr/bin:/bin"
    local IFS=$' \t\n'
    local _LC_ALL="${LC_ALL-}" _LANG="${LANG-}"
    local LC_ALL=C LANG=C

    # setup for zsh
    if [[ -n ${ZSH_VERSION-} ]]; then
        \setopt localoptions SH_WORD_SPLIT
        \setopt localoptions BSD_ECHO
        \setopt localoptions NO_NOMATCH
        \setopt localoptions NO_GLOB_SUBST
        \setopt localoptions NO_EXTENDED_GLOB
        \setopt localoptions BASH_REMATCH
    fi

    # save whether the stdin/out/err of the main function is TTY or not.
    [[ -t 0 ]] \
    && declare -r TTY_STDIN=0 \
    || declare -r TTY_STDIN=1

    [[ -t 1 ]] \
    && declare -r TTY_STDOUT=0 \
    || declare -r TTY_STDOUT=1

    [[ -t 2 ]] \
    && declare -r TTY_STDERR=0 \
    || declare -r TTY_STDERR=1

    declare -r FD_STDOUT=1
    declare -r FD_STDERR=2

    # show help if subcommand not given
    if [[ $# -eq 0 ]]; then
        _zetopt::man::show short
        return 1
    fi

    local subcmd="$1"
    shift

    case "$subcmd" in
        -v | --version)
            \echo $ZETOPT_APPNAME $ZETOPT_VERSION;;
        -h | --help)
            _zetopt::man::show;;
        init)
            _zetopt::init::init;;
        reset)
            _zetopt::parser::init
            _zetopt::data::init
            ;;
        define | def)
            _zetopt::def::define "${@-}";;
        def-validator | define-validator)
            _zetopt::def::def_validator "${@-}";;
        parse)
            # for supporting blank string argument
            [[ $# -eq 0 ]] \
            && _zetopt::parser::parse \
            || _zetopt::parser::parse "${@-}";;
        define-help | def-help)
            _zetopt::help::define "${@-}";;
        show-help)
            _zetopt::help::show "${@-}";;
        isset)
            _zetopt::data::isset "${@-}";;
        isvalid | isok)
            _zetopt::data::isvalid "${@-}";;
        count | cnt)
            _zetopt::data::count "${@-}";;
        status | stat)
            _zetopt::data::status "${@-}";;
        setids)
            _zetopt::data::setids;;
        index | idx)
            _zetopt::data::argidx "${@-}";;
        type)
            _zetopt::data::type "${@-}";;
        paramidx | pidx)
            _zetopt::def::paramidx "${@-}";;
        paramlen | plen)
            _zetopt::def::paramlen "${@-}";;
        hasval)
            _zetopt::data::hasvalue "${@-}";;
        value | val)
            _zetopt::data::argvalue "${@-}";;
        length | len)
            _zetopt::data::arglength "${@-}";;
        default)
            _zetopt::def::default "${@-}";;
        defined)
            _zetopt::def::defined "${@-}";;
        parsed)
            _zetopt::data::parsed "${@-}";;
        *)
            _zetopt::msg::script_error "Undefined Sub-Command:" "$subcmd"
            return 1;;
    esac
}

