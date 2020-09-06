#------------------------------------------------------------
# _zetopt::init
#------------------------------------------------------------
# Global Constant Variables
# bash
if [ -n "${BASH_VERSION-}" ]; then
    readonly ZETOPT_SOURCE_FILE_PATH="${BASH_SOURCE:-$0}"
    readonly ZETOPT_ROOT="$(builtin cd "$(dirname "$ZETOPT_SOURCE_FILE_PATH")" && pwd)"
    readonly ZETOPT_CALLER_FILE_PATH="$0"
    readonly ZETOPT_CALLER_NAME="${ZETOPT_CALLER_FILE_PATH##*/}"
    readonly ZETOPT_BASH=true
    readonly ZETOPT_ZSH=false
    readonly ZETOPT_OLDBASH="$([[ ${BASH_VERSION:0:1} -le 3 ]] && echo true || echo false)"
# zsh
elif [ -n "${ZSH_VERSION-}" ]; then
    if [[ ! $'\n'$(setopt) =~ $'\n'ksharrays ]]; then
        setopt KSH_ARRAYS
        echo >&2 "zetopt: Warning: KSH_ARRAYS has been enabled automatically."
    fi
    readonly ZETOPT_SOURCE_FILE_PATH="$0"
    readonly ZETOPT_ROOT="${${(%):-%x}:A:h}"
    readonly ZETOPT_CALLER_FILE_PATH="${funcfiletrace%:*}"
    readonly ZETOPT_CALLER_NAME="${ZETOPT_CALLER_FILE_PATH##*/}"
    readonly ZETOPT_BASH=false
    readonly ZETOPT_ZSH=true
    readonly ZETOPT_OLDBASH=false
else
    echo >&2 "zetopt: Fatal Error: Bash 3.2+ / Zsh 5.0+ Required"
    return 1
fi

# field numbers for defined data
readonly ZETOPT_DEFID_ALL=0
readonly ZETOPT_DEFID_ID=1
readonly ZETOPT_DEFID_TYPE=2
readonly ZETOPT_DEFID_SHORT=3
readonly ZETOPT_DEFID_LONG=4
readonly ZETOPT_DEFID_ARG=5
readonly ZETOPT_DEFID_VARNAME=6
readonly ZETOPT_DEFID_FLAGS=7
readonly ZETOPT_DEFID_HELP=8

# field numbers for parsed data
readonly ZETOPT_DATAID_ALL=0
readonly ZETOPT_DATAID_ID=1
readonly ZETOPT_DATAID_ARGV=2
readonly ZETOPT_DATAID_ARGC=3
readonly ZETOPT_DATAID_TYPE=4
readonly ZETOPT_DATAID_PSEUDO=5
readonly ZETOPT_DATAID_STATUS=6
readonly ZETOPT_DATAID_COUNT=7
readonly ZETOPT_DATAID_EXTRA_ARGV=8
readonly ZETOPT_DATAID_DEFAULT=9

# types
readonly ZETOPT_TYPE_CMD=0
readonly ZETOPT_TYPE_SHORT=1
readonly ZETOPT_TYPE_LONG=2
readonly ZETOPT_TYPE_PLUS=3

# parse status
readonly ZETOPT_STATUS_NORMAL=0
readonly ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS=$((1 << 0))
readonly ZETOPT_STATUS_MISSING_OPTIONAL_ARGS=$((1 << 1))
readonly ZETOPT_STATUS_EXTRA_ARGS=$((1 << 2))
readonly ZETOPT_STATUS_VALIDATOR_FAILED=$((1 << 3))
readonly ZETOPT_STATUS_MISSING_REQUIRED_OPTARGS=$((1 << 4))
readonly ZETOPT_STATUS_MISSING_REQUIRED_ARGS=$((1 << 5))
readonly ZETOPT_STATUS_UNDEFINED_OPTION=$((1 << 6))
readonly ZETOPT_STATUS_UNDEFINED_SUBCMD=$((1 << 7))
readonly ZETOPT_STATUS_INVALID_OPTFORMAT=$((1 << 8))
readonly ZETOPT_STATUS_ERROR_THRESHOLD=$ZETOPT_STATUS_EXTRA_ARGS

# misc
readonly ZETOPT_IDX_NOT_FOUND=-1
readonly ZETOPT_IDX_DEFAULT_VALUE=0
readonly ZETOPT_IDX_FLAG_DEFAULT=1
readonly ZETOPT_IDX_FLAG_TRUE=2
readonly ZETOPT_IDX_FLAG_FALSE=3

# __NULL is default value for auto-defined variable
__NULL(){ return 1; }

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
    _ZETOPT_VALIDATOR_KEYS=
    _ZETOPT_VALIDATOR_DATA=()
    _ZETOPT_VALIDATOR_ERRMSG=()
    _ZETOPT_PARSED=
    _ZETOPT_DATA=()
    _ZETOPT_DEFAULTS=()
    _ZETOPT_TEMP_ARGV=()
    _ZETOPT_EXTRA_ARGV=()

    _zetopt::init::unset_user_vars
    _ZETOPT_VARIABLE_NAMES=()

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
    # Autovar related configs: Set before "def"
    ZETOPT_CFG_AUTOVAR=true
    ZETOPT_CFG_AUTOVAR_PREFIX=zv_
    ZETOPT_CFG_ARG_DEFAULT=__NULL
    ZETOPT_CFG_FLAG_DEFAULT=__NULL
    ZETOPT_CFG_FLAG_TRUE=true
    ZETOPT_CFG_FLAG_FALSE=false

    # Parser related configs: Set before "parse"
    ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN=false
    ZETOPT_CFG_SINGLE_PREFIX_LONG=false
    ZETOPT_CFG_PSEUDO_OPTION=false
    ZETOPT_CFG_CONCATENATED_OPTARG=true
    ZETOPT_CFG_ABBREVIATED_LONG=true
    ZETOPT_CFG_IGNORE_BLANK_STRING=false
    ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR=false
    ZETOPT_CFG_PREFIX_PLUS=false

    # Parsed data related configs: Set before refering parsed data
    ZETOPT_CFG_VALUE_IFS=" "

    # Warning/Error message related configs: Set right after .(source)
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

# unset_user_vars(): unset all of auto-defined variables
# def.) _zetopt::init::unset_user_vars
# e.g.) _zetopt::init::unset_user_vars
# STDOUT: NONE
_zetopt::init::unset_user_vars()
{
    if [[ -z ${_ZETOPT_VARIABLE_NAMES[@]-} ]]; then
        return 0
    fi
    unset "${_ZETOPT_VARIABLE_NAMES[@]}" ||:
}

# reset(): reset parse data only
# def.) _zetopt::init::reset
# e.g.) _zetopt::init::reset
# STDOUT: NONE
_zetopt::init::reset()
{
    _zetopt::def::reset
    _zetopt::parser::init
    _zetopt::data::init
}

# Call init when sourcing
_zetopt::init::init
