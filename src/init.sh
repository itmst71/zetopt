#------------------------------------------------------------
# _zetopt::init
#------------------------------------------------------------
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
    _ZETOPT_OPTVALS=()
    ZETOPT_ARGS=()

    ZETOPT_PARSE_ERRORS=$ZETOPT_STATUS_NORMAL
    ZETOPT_OPTERR_INVALID=()
    ZETOPT_OPTERR_UNDEFINED=()
    ZETOPT_OPTERR_MISSING_REQUIRED=()
    ZETOPT_OPTERR_MISSING_OPTIONAL=()

    ZETOPT_LAST_COMMAND=/
    _zetopt::init::init_config
}

# config
_zetopt::init::init_config()
{
    ZETOPT_CFG_VALUE_IFS=" "
    ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN=false
    ZETOPT_CFG_CLUSTERED_AS_LONG=false
    ZETOPT_CFG_IGNORE_BLANK_STRING=false
    ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR=false
    ZETOPT_CFG_OPTTYPE_PLUS=false
    ZETOPT_CFG_FLAGVAL_TRUE=true
    ZETOPT_CFG_FLAGVAL_FALSE=false
    ZETOPT_CFG_ERRMSG=true
    ZETOPT_CFG_ERRMSG_APPNAME="$ZETOPT_CALLER_NAME"
    ZETOPT_CFG_ERRMSG_COL_MODE=auto
    ZETOPT_CFG_ERRMSG_COL_DEFAULT="0;0;39"
    ZETOPT_CFG_ERRMSG_COL_ERROR="0;1;31"
    ZETOPT_CFG_ERRMSG_COL_WARNING="0;0;33"
    ZETOPT_CFG_ERRMSG_COL_SCRIPTERR="0;1;31"
    ZETOPT_CFG_DEBUG=true
}
