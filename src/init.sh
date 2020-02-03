#------------------------------------------------------------
# _zetopt::init
#------------------------------------------------------------
# Global Constant Variables
# bash
if [[ -n ${BASH_VERSION-} ]]; then
    readonly ZETOPT_SOURCE_FILE_PATH="${BASH_SOURCE:-$0}"
    readonly ZETOPT_ROOT="$(builtin cd "$(dirname "$ZETOPT_SOURCE_FILE_PATH")" && pwd)"
    readonly ZETOPT_CALLER_FILE_PATH="$0"
    readonly ZETOPT_CALLER_NAME="${ZETOPT_CALLER_FILE_PATH##*/}"
    readonly ZETOPT_OLDBASH="$([[ ${BASH_VERSION:0:1} -le 3 ]] && \echo true || \echo false)"
    readonly ZETOPT_ARRAY_INITIAL_IDX=0
# zsh
elif [[ -n ${ZSH_VERSION-} ]]; then
    readonly ZETOPT_SOURCE_FILE_PATH="$0"
    readonly ZETOPT_ROOT="${${(%):-%x}:A:h}"
    readonly ZETOPT_CALLER_FILE_PATH="${funcfiletrace%:*}"
    readonly ZETOPT_CALLER_NAME="${ZETOPT_CALLER_FILE_PATH##*/}"
    readonly ZETOPT_OLDBASH=false
    readonly ZETOPT_ARRAY_INITIAL_IDX="$([[ $'\n'$(\setopt) =~ $'\n'ksharrays ]] && \echo 0 || \echo 1)"
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
readonly ZETOPT_FIELD_DATA_ARGV=2
readonly ZETOPT_FIELD_DATA_ARGC=3
readonly ZETOPT_FIELD_DATA_TYPE=4
readonly ZETOPT_FIELD_DATA_PSEUDO=5
readonly ZETOPT_FIELD_DATA_STATUS=6
readonly ZETOPT_FIELD_DATA_COUNT=7
readonly ZETOPT_FIELD_DATA_EXTRA_ARGV=8

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


# init(): initialize all variables
# def.) _zetopt::init::init
# e.g.) _zetopt::init::init
# STDOUT: NONE
_zetopt::init::init()
{
    _ZETOPT_DEF_ERROR=false
    _ZETOPT_DEFINED=
    _ZETOPT_OPTHELPS=()
    _ZETOPT_HELPS_IDX=()
    _ZETOPT_HELPS=()
    _ZETOPT_HELPS_CUSTOM=
    _ZETOPT_DEFAULTS=()
    _ZETOPT_VALIDATOR_KEYS=
    _ZETOPT_VALIDATOR_DATA=
    _ZETOPT_VALIDATOR_ERRMSG=
    _ZETOPT_PARSED=
    _ZETOPT_DATA=()
    ZETOPT_ARGS=()
    ZETOPT_EXTRA_ARGV=()

    ZETOPT_PARSE_ERRORS=$ZETOPT_STATUS_NORMAL
    ZETOPT_OPTERR_INVALID=()
    ZETOPT_OPTERR_UNDEFINED=()
    ZETOPT_OPTERR_MISSING_REQUIRED=()
    ZETOPT_OPTERR_MISSING_OPTIONAL=()

    ZETOPT_LAST_COMMAND=/
    _zetopt::init::init_config
}

# init_config(): initialize config variables
# def.) _zetopt::init::init_config
# e.g.) _zetopt::init::init_config
# STDOUT: NONE
_zetopt::init::init_config()
{
    ZETOPT_CFG_VARIABLE_PREFIX=zv_
    ZETOPT_CFG_VARIABLE_DEFAULT=_NULL
    ZETOPT_CFG_VALUE_IFS=" "
    ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN=false
    ZETOPT_CFG_SINGLE_PREFIX_LONG=false
    ZETOPT_CFG_PSEUDO_OPTION=false
    ZETOPT_CFG_CONCATENATED_OPTARG=true
    ZETOPT_CFG_ABBREVIATED_LONG=true
    ZETOPT_CFG_IGNORE_BLANK_STRING=false
    ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR=false
    ZETOPT_CFG_OPTTYPE_PLUS=false
    ZETOPT_CFG_FLAGVAL_TRUE=true
    ZETOPT_CFG_FLAGVAL_FALSE=false
    ZETOPT_CFG_ERRMSG_USER_ERROR=true
    ZETOPT_CFG_ERRMSG_SCRIPT_ERROR=true
    ZETOPT_CFG_ERRMSG_STACKTRACE=true
    ZETOPT_CFG_ERRMSG_APPNAME=$ZETOPT_CALLER_NAME
    ZETOPT_CFG_ERRMSG_COL_MODE=auto
    ZETOPT_CFG_ERRMSG_COL_DEFAULT="0;0;39"
    ZETOPT_CFG_ERRMSG_COL_ERROR="0;1;31"
    ZETOPT_CFG_ERRMSG_COL_WARNING="0;0;33"
    ZETOPT_CFG_ERRMSG_COL_SCRIPTERR="0;1;31"
}

# reset(): reset parse data only
# def.) _zetopt::init::reset
# e.g.) _zetopt::init::reset
# STDOUT: NONE
_zetopt::init::reset()
{
    _zetopt::parser::init
    _zetopt::data::init
}

# Call init when sourcing
_zetopt::init::init
