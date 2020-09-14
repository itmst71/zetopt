#------------------------------------------------------------
# Name        : zetopt -- An option parser for shell scripts
# Version     : 2.0.0-dev202009140900
# Required    : Bash 3.2+ / Zsh 5.0+, Some POSIX commands
# License     : MIT License
# Author      : itmst71@gmail.com
# URL         : https://github.com/itmst71/zetopt
#------------------------------------------------------------

# MIT License
# 
# Copyright (c) 2017-2020 itmst71
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# app info
readonly ZETOPT_APPNAME="zetopt"
readonly ZETOPT_VERSION="2.0.0-dev202009140900"


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
readonly ZETOPT_DEFID_SETTINGS=7
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
    ZETOPT_CFG_AUTOVAR_CASE=lower
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


#------------------------------------------------------------
# Main
#------------------------------------------------------------
# zetopt(): Interface for shell script programmer
# def.) zetopt {SUB-COMMAND} [ARGS]
# e.g.) zetopt def ver:v,version
# STDOUT: depending on each sub-commands
zetopt()
{
    local _PATH=$PATH
    local PATH="/usr/bin:/bin"
    local _LC_ALL="${LC_ALL-}"
    local LC_ALL=C
    local _LANG="${LANG-}"
    local LANG=C
    local _IFS_DEFAULT=$' \t\n'
    local IFS=$_IFS_DEFAULT
    local _LF=$'\n'
    local _REG_VARNAME='[a-zA-Z_][a-zA-Z0-9_]*'

    # setup for zsh
    if [[ -n ${ZSH_VERSION-} ]]; then
        setopt localoptions SH_WORD_SPLIT
        setopt localoptions BSD_ECHO
        setopt localoptions NO_NOMATCH
        setopt localoptions NO_GLOB_SUBST
        setopt localoptions NO_EXTENDED_GLOB
        setopt localoptions BASH_REMATCH
    fi

    # save whether the stdin/out/err of the main function is TTY or not.
    [[ -t 0 ]] \
    && local _TTY_STDIN=0 \
    || local _TTY_STDIN=1

    [[ -t 1 ]] \
    && local _TTY_STDOUT=0 \
    || local _TTY_STDOUT=1

    [[ -t 2 ]] \
    && local _TTY_STDERR=0 \
    || local _TTY_STDERR=1

    local _FD_STDOUT=1
    local _FD_STDERR=2

    # show help if subcommand not given
    if [[ $# -eq 0 ]]; then
        _zetopt::man::show short
        return 1
    fi

    local subcmd="$1"
    shift

    # sub-commands
    case "$subcmd" in
        # options
        -v | --version)
            echo $ZETOPT_APPNAME $ZETOPT_VERSION;;
        -h | --help)
            _zetopt::man::show;;

        # init
        init)
            _zetopt::init::init;;
        reset)
            _zetopt::init::reset;;

        # def
        define | def)
            _zetopt::def::define "$@";;
        paramidx | pidx)
            _zetopt::def::paramidx "$@";;
        paramlen | plen)
            _zetopt::def::paramlen "$@";;
        defined)
            _zetopt::def::defined "$@";;

        # validator
        validator)
            _zetopt::validator::def "$@";;

        # parser
        parse)
            _zetopt::parser::parse "$@";;

        # data
        isset)
            _zetopt::data::isset "$@";;
        setids)
            _zetopt::data::setids;;
        argv | value | val)
            _zetopt::data::output $ZETOPT_DATAID_ARGV "$@";;
        argc | length | len)
            _zetopt::data::output $ZETOPT_DATAID_ARGC "$@";;
        type)
            _zetopt::data::output $ZETOPT_DATAID_TYPE "$@";;
        pseudo)
            _zetopt::data::output $ZETOPT_DATAID_PSEUDO "$@";;
        status)
            _zetopt::data::output $ZETOPT_DATAID_STATUS "$@";;
        count)
            _zetopt::data::output $ZETOPT_DATAID_COUNT "$@";;
        default)
            _zetopt::data::output $ZETOPT_DATAID_DEFAULT "$@";;
        hasarg | hasval)
            _zetopt::data::hasarg "$@";;
        isvalid | isok)
            _zetopt::data::isvalid "$@";;
        parsed)
            _zetopt::data::parsed "$@";;
        iterate)
            _zetopt::data::iterate "$@";;

        # utils
        utils)
            _zetopt::utils::interface "$@";;
            
        # help
        help)
            case ${1-} in
                def|define)
                    shift
                    _zetopt::help::define "$@";;
                show)
                    shift
                    _zetopt::help::show "$@";;
                *)
                    _zetopt::msg::script_error "Undefined Sub-Command:" "help ${1-}"
                    return 1;;
            esac
            ;;

        *)
            _zetopt::msg::script_error "Undefined Sub-Command:" "$subcmd"
            return 1;;
    esac
}



#------------------------------------------------------------
# _zetopt::def
#------------------------------------------------------------
# reset(): Reset auto-defined variables to their defaults
# ** Must be executed in the current shell **
# def.) _zetopt::def::reset
# e.g.) _zetopt::def::reset
# STDOUT: NONE
_zetopt::def::reset()
{
    if [[ -z ${_ZETOPT_DEFINED:-} ]]; then
        return 0
    fi

    local lines line id args arg vars var settings dfnum df
    declare -i idx
    args=()
    vars=()
    local IFS=$'\n'
    lines=($_ZETOPT_DEFINED)
    IFS=$_IFS_DEFAULT

    for line in "${lines[@]}"
    do
        if [[ $line =~ ^([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*)$ ]]; then
            id=${BASH_REMATCH[$ZETOPT_DEFID_ID]}
            args=(${BASH_REMATCH[$ZETOPT_DEFID_ARG]})
            vars=(${BASH_REMATCH[$ZETOPT_DEFID_VARNAME]})
            settings=" ${BASH_REMATCH[$ZETOPT_DEFID_SETTINGS]} "
            for ((idx=0; idx<${#vars[@]}; idx++ ))
            do
                var=${vars[idx]}
                if [[ $idx -eq 0 ]]; then
                    if [[ $settings =~ \ d=([0-9]+)\  ]]; then
                        dfnum=${BASH_REMATCH[1]}
                        df=${_ZETOPT_DEFAULTS[dfnum]}
                        eval $var'=$df'
                    fi
                    continue
                fi

                arg=${args[idx-1]}
                [[ $arg =~ \=([1-9][0-9]*) ]] \
                    && dfnum=${BASH_REMATCH[1]} \
                    || dfnum=0
                
                df=${_ZETOPT_DEFAULTS[dfnum]}
                [[ $arg =~ [.]{3,3} ]] \
                    && eval $var'=("$df")' \
                    || eval $var'=$df'
            done
        fi
    done
}

# define(): Define options.
# ** Must be executed in the current shell **
# def.) _zetopt::def::define {DEFINITION-STRING}
# e.g.) _zetopt::def::define "ver:v:version"
# STDOUT: NONE
_zetopt::def::define()
{
    if $ZETOPT_CFG_AUTOVAR; then
        if [[ -z $ZETOPT_CFG_AUTOVAR_PREFIX || ! $ZETOPT_CFG_AUTOVAR_PREFIX =~ ^$_REG_VARNAME$ || $ZETOPT_CFG_AUTOVAR_PREFIX == _ ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Invalid Variable Name Prefix:" "ZETOPT_CFG_AUTOVAR_PREFIX=$ZETOPT_CFG_AUTOVAR_PREFIX"
            return 1
        fi
    fi

    if [[ -z ${_ZETOPT_DEFINED:-} ]]; then
        _ZETOPT_DEFINED="/:c:::%.0~0...=0:::0 0$_LF"
        _ZETOPT_OPTHELPS=("")
        _ZETOPT_DEFAULTS=("$ZETOPT_CFG_ARG_DEFAULT" "$ZETOPT_CFG_FLAG_DEFAULT" "$ZETOPT_CFG_FLAG_TRUE" "$ZETOPT_CFG_FLAG_FALSE")
    fi

    if [[ -z $@ ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "No Definition Given"
        return 1
    fi

    local IFS=$_IFS_DEFAULT args
    declare -i arglen=$#
    args=("$@")
    declare -i idx=0 maxloop=$arglen
    local namespace= id= short= long= namedef= deftype=o helpdef= global= helpidx=0 helpidx_cmd=0 flags=
    local help_only=false has_param=false
    local settings=

    local arg="${args[$idx]}"
    if [[ $arglen -eq 1 ]]; then
        # param only
        if [[ $arg =~ ^-{0,2}[@%] ]]; then
            namedef=/
            has_param=true
        # help only
        elif [[ $arg =~ ^\# ]]; then
            namedef=/
            helpdef=${arg###}
            help_only=true
        # id only
        else
            namedef=$arg
            idx+=1
        fi
    else
        if [[ $arg =~ ^-{0,2}[@%] ]]; then
            namedef=/
            has_param=true
        elif [[ $arg =~ ^\# ]]; then
            namedef=/
            IFS=
            helpdef="${args[*]}"
            IFS=$_IFS_DEFAULT
            helpdef=${helpdef###}
            help_only=true
        else
            namedef=$arg
            idx+=1
            arg=${args[$idx]}
            if [[ $arg =~ ^-{0,2}[@%] ]]; then
                has_param=true
            elif [[ $arg =~ ^\# ]]; then
                help_only=true
            fi
        fi
    fi

    # exclusive flag
    local caret="\^"
    if [[ $namedef =~ ^$caret(.*)$ ]]; then
        namedef=${BASH_REMATCH[1]}
        flags+="x"
    fi

    # add an omittable root /
    if [[ ! $namedef =~ ^/ ]]; then
        namedef="/$namedef"
    fi

    # regard as a subcommand
    if [[ ! $namedef =~ : ]]; then
        [[ ! $namedef =~ /$ ]] && namedef="$namedef/" ||:
        deftype=c
    fi

    IFS=:
    \set -- $namedef
    IFS=$_IFS_DEFAULT
    if [[ $# -gt 3 ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "Invalid Definition"
        return 1
    fi

    id=${1-}
    namespace=${id%/*}/
    [[ $id != / ]] && id=${id%/} ||:

    # global flag
    if [[ $id =~ [+]$ ]]; then
        flags+="g"
        id=${id//+/}
    fi

    settings=flags=$flags

    # can not determine whether it is a subcommand or an option
    if [[ $namedef =~ : && $id =~ /$ ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "Invalid Definition"
        return 1
    fi

    if [[ ! $id =~ ^(/|/[a-zA-Z_][a-zA-Z0-9_]*((-[a-zA-Z0-9_]+)*(/[a-zA-Z_][a-zA-Z0-9_]*(-[a-zA-Z0-9_]+)*)*)?)$ ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "Invalid Identifier:" "$id"
        return 1
    fi
    
    # namespace(subcommand) definition
    if [[ $deftype == c ]]; then
        if [[ $flags =~ g ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Command Difinition with Global Option Flag +"
            return 1
        fi

        if [[ $flags =~ x ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Command Difinition with Exclusive Flag ^"
            return 1
        fi

        # command has two help indexes for itself and its argument
        helpidx="0 0"

        if [[ $_ZETOPT_DEFINED =~ (^|.*$_LF)((${id}:c:[^$_LF]+:)([0-9]+)\ ([0-9]+)$_LF)(.*) ]]; then
            local head_lines="${BASH_REMATCH[1]}"
            local tmp_line="${BASH_REMATCH[2]}"
            local tmp_line_nohelp="${BASH_REMATCH[3]}"
            helpidx_cmd="${BASH_REMATCH[4]}"
            local helpidx_cmdarg="${BASH_REMATCH[5]}"
            local tail_lines="${BASH_REMATCH[6]}"

            # remove auto defined namespace
            if [[ $tmp_line == "${id}:c:::%.0~0...=0:::0 0$_LF" ]]; then
                if [[ $has_param == false && $help_only == false ]]; then
                    return 0
                fi
                _ZETOPT_DEFINED="$head_lines$tail_lines"
            
            elif [[ $has_param == true && $tmp_line =~ [@%] ]] || [[ $help_only == true && $tmp_line =~ :[1-9][0-9]*\ [0-9]+$_LF$ ]]; then
                _ZETOPT_DEF_ERROR=true
                _zetopt::msg::script_error "Already Defined:" "$id"
                return 1

            # help only definition: rewrite help reference number part of existing definition
            elif [[ $help_only == true && $tmp_line =~ :0\ ([0-9]+)$_LF$ ]]; then
                _ZETOPT_OPTHELPS+=("$helpdef")
                helpidx=$((${#_ZETOPT_OPTHELPS[@]} - 1))
                _ZETOPT_DEFINED="$head_lines$tmp_line_nohelp$helpidx $helpidx_cmdarg$_LF$tail_lines"
                return 0

            # remove help only definition and continue parsing
            else
                _ZETOPT_DEFINED="$head_lines$tail_lines"
            fi
        fi
    fi
    
    if [[ $_LF$_ZETOPT_DEFINED =~ $_LF${id}: ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "Duplicate Identifier:" "$id"
        return 1
    fi

    # options
    if [[ $namedef =~ : ]]; then
        shift
        IFS=,
        \set -- $*
        local optname
        while [[ $# -ne 0 ]]
        do
            if [[ -z $1 ]]; then
                shift
                continue
            fi
            optname=$1
            if [[ $optname =~ ^-*(.*) ]]; then
                optname=${BASH_REMATCH[1]}
            fi

            # short option
            if [[ ${#optname} -eq 1 ]]; then
                if [[ -n $short ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "2 Short Options at once:" "$optname"
                    return 1
                fi

                if [[ ! $optname =~ ^[a-zA-Z0-9_]$ ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Invalid Short Option Name:" "$optname"
                    return 1
                fi
                
                # subcommand scope option
                if [[ $_LF$_ZETOPT_DEFINED =~ $_LF${namespace}[a-zA-Z0-9_]*:o:$optname: ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Already Defined:" "-$optname"
                    return 1
                fi
                short=$optname

            # long option
            else
                if [[ -n $long ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "2 Long Options at once:" "$optname"
                    return 1
                fi

                if [[ ! $optname =~ ^[a-zA-Z0-9_]+(-[a-zA-Z0-9_]*)*$ ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Invalid Long Option Name:" "$optname"
                    return 1
                fi

                # subcommand scope option
                if [[ $_LF$_ZETOPT_DEFINED =~ $_LF${namespace}[a-zA-Z0-9_]*:o:[^:]?:$optname: ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Already Defined:" "--$optname"
                    return 1
                fi
                long=$optname
            fi
            shift
        done

        # Not short option nor long option
        if [[ -z $short$long ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Invalid Definition"
            return 1
        fi
    fi
    
    # build base name of variable to store the last value
    local var_name var_name_list=
    local var_base_name=${ZETOPT_CFG_AUTOVAR_PREFIX}${id:1}
    var_base_name=${var_base_name//[\/\-]/_}
    if [[ -z $var_base_name ]]; then
        var_base_name=_
    fi

    # parameters
    local param_def=
    if [[ $has_param == true ]]; then
        local param_optional=false param params default_is_set=false
        declare -i param_idx=0 param_default_idx
        local param_validator_idxs param_validator_separator param_validator= param_validator_name=
        local param_hyphens param_type param_name param_varlen param_varlen_max param_default param_has_default param_names=
        local var_param_name var_param_default
        params=()
        for ((; idx<maxloop; idx++))
        do
            arg=${args[$idx]}
            if [[ ! $arg =~ ^(-{0,2})([@%])($_REG_VARNAME)?(([~]$_REG_VARNAME(,$_REG_VARNAME)*)|([\[]=[~]$_REG_VARNAME(,$_REG_VARNAME)*[\]])|([~]))?([.]{3,3}([1-9][0-9]*)?)?(=.*)?$ ]]; then
                _ZETOPT_DEF_ERROR=true
                _zetopt::msg::script_error "Invalid Parameter Definition:" "$arg"
                return 1
            fi
            
            param_default_idx=0
            param_hyphens=${BASH_REMATCH[1]}
            param_type=${BASH_REMATCH[2]}
            param_name=${BASH_REMATCH[3]}
            param_validator=${BASH_REMATCH[4]}
            param_varlen=${BASH_REMATCH[10]}
            param_varlen_max=${BASH_REMATCH[11]}
            param_default=${BASH_REMATCH[12]}

            if [[ $param_type == @ ]]; then
                if [[ $param_optional == true ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Required Parameter after Optional"
                    return 1
                fi
            else
                param_optional=true
            fi

            if [[ -n $param_varlen && ($((idx + 1)) -ne $maxloop && ${args[$(($idx + 1))]} =~ ^-{0,2}[@%] ) ]]; then
                _ZETOPT_DEF_ERROR=true
                _zetopt::msg::script_error "Variable-length parameter must be the last parameter"
                return 1
            fi

            # check if parameter names are duplicated
            var_param_name=$param_idx
            if [[ -n $param_name ]]; then
                if [[ $param_names =~ \ $param_name\  ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Duplicate Parameter Name:" "$param_name"
                    return 1
                fi
                param_names+=" $param_name "
                var_param_name=$param_name
            fi

            # define choice-validator automatically
            if [[ $param_validator == '~' ]]; then
                local choice_note="Note: If a validator is specified with \"~\" and no name is given like \"~vldt_name\", then comma-separated words after \"=\" are used as choices. However, if there is only one choice, it is treated as an array variable containing the choices. The first choice is used as the default value."
                if [[ -z $param_default ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "No Choice Defined:" "$param\n $choice_note"
                    return 1
                fi

                param_validator="__AUTO_VLDT_${#_ZETOPT_VALIDATOR_DATA[*]}"
                local choice_str=${param_default#*=} choice_help choice_arr
                IFS=,
                choice_arr=($choice_str)
                if [[ ${#choice_arr[*]} -ge 2 ]]; then
                    param_default=${choice_arr[0]} #the first choice is the default value
                    choice_help="#Choose from: [$(IFS=\| && echo "${choice_arr[*]}")]"
                    _zetopt::validator::def -c "$param_validator" "$choice_str" "$choice_help"
                else
                    if [[ ! ${choice_arr[0]} =~ ^$_REG_VARNAME$ || -z $(eval 'echo ${'${choice_arr[0]}'+x}') ]]; then
                        _ZETOPT_DEF_ERROR=true
                        _zetopt::msg::script_error "\"${choice_arr[0]}\" is not an array variable.\n $choice_note"
                        return 1
                    fi
                    eval 'param_default=${'${choice_arr[0]}'[0]}' #the first choice is the default value
                    eval 'choice_help="#Choose from: [$(IFS=\| && echo "${'${choice_arr[0]}'[*]}")]"'
                    _zetopt::validator::def -a "$param_validator" "$choice_str" "$choice_help"
                fi
            fi

            # translate validator name to indexes
            param_validator_idxs=0
            if [[ $param_validator =~ ($_REG_VARNAME(,$_REG_VARNAME)*) ]]; then
                param_validator_separator=
                param_validator_idxs=
                IFS=,
                set -- ${BASH_REMATCH[1]}
                while [[ $# -ne 0 ]]
                do
                    param_validator_name=$1
                    # check the validator exists
                    if [[ ! $_LF${_ZETOPT_VALIDATOR_KEYS-} =~ $_LF$param_validator_name:([0-9]+)$_LF ]]; then
                        # define validator with blank data
                        if ! _zetopt::validator::def "$param_validator_name"; then
                            _ZETOPT_DEF_ERROR=true
                            return 1
                        fi
                        # re-matching to get the reference number of the validator just defined with blank data
                        [[ $_LF${_ZETOPT_VALIDATOR_KEYS-} =~ $_LF$param_validator_name:([0-9]+)$_LF ]]
                    fi
                    param_validator_idxs="$param_validator_idxs$param_validator_separator${BASH_REMATCH[1]}"
                    param_validator_separator=,
                    shift 1
                done
            fi

            # save default value
            var_param_default=$ZETOPT_CFG_ARG_DEFAULT
            if [[ -n $param_default ]]; then
                var_param_default=${param_default#*=}
                _ZETOPT_DEFAULTS+=("$var_param_default")
                param_default_idx=$((${#_ZETOPT_DEFAULTS[@]} - 1))
                default_is_set=true
            elif [[ $default_is_set == true ]]; then
                _ZETOPT_DEF_ERROR=true
                _zetopt::msg::script_error "Non-default Argument Following Default Argument:" "$param_name"
                return 1
            fi
            params+=("$param_hyphens$param_type$param_name.$param_idx~$param_validator_idxs$param_varlen=$param_default_idx")
            param_idx+=1

            # autovar
            if $ZETOPT_CFG_AUTOVAR; then
                # build variable name
                [[ $deftype == c ]] \
                    && var_name=${var_base_name}$([[ $id != / ]] && echo _||:)$var_param_name \
                    || var_name=${var_base_name}_$var_param_name
                var_name=$(_zetopt::def::apply_case_config "$var_name")
                
                # check variable name conflict
                if [[ -n $(eval 'echo ${'$var_name'+x}') ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Variable name \"$var_name\" is already in use"
                    return 1
                fi
                _ZETOPT_VARIABLE_NAMES+=($var_name)

                # subsititue default value to variable
                [[ -n $param_varlen ]] \
                && eval $var_name'=("$var_param_default")' \
                || eval $var_name'=$var_param_default'
                var_name_list+="$var_name "
            fi

            # no more parameter
            if [[ $((idx + 1)) -ne $maxloop && ! ${args[$(($idx + 1))]} =~ ^-{0,2}[@%] ]]; then
                : $((idx++))
                break
            fi
        done
        IFS=" "
        param_def="${params[*]}"
    fi
    IFS=$_IFS_DEFAULT

    # settings
    local flag_default=$ZETOPT_CFG_FLAG_DEFAULT
    local flag_default_idx=$ZETOPT_IDX_FLAG_DEFAULT
    local flag_true_idx=$ZETOPT_IDX_FLAG_TRUE
    local flag_false_idx=$ZETOPT_IDX_FLAG_FALSE
    for ((; idx<maxloop; idx++))
    do
        arg=${args[$idx]}
        
        # no more settings
        if [[ $arg =~ ^\# ]]; then
            break
        fi

        if [[ ! $arg =~ ^-{0,2}(d|default|t|true|f|false)=(.*)$ ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Invalid Definition"
            return 1
        fi

        _ZETOPT_DEFAULTS+=("${BASH_REMATCH[2]}")
        case ${BASH_REMATCH[1]} in
            d | default)
                flag_default=${BASH_REMATCH[2]}
                flag_default_idx=$((${#_ZETOPT_DEFAULTS[@]} - 1));;
            t | true)
                flag_true_idx=$((${#_ZETOPT_DEFAULTS[@]} - 1));;
            f | false)
                flag_false_idx=$((${#_ZETOPT_DEFAULTS[@]} - 1));;
        esac
    done
    settings+=" d=$flag_default_idx t=$flag_true_idx f=$flag_false_idx"

    # autovar
    if $ZETOPT_CFG_AUTOVAR; then
        var_name=$(_zetopt::def::apply_case_config "$var_base_name")

        # check variable name conflict
        if [[ -n $(eval 'echo ${'$var_name'+x}') ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Variable name \"$var_name\" is already in use"
            return 1
        fi
        _ZETOPT_VARIABLE_NAMES+=($var_name)
        eval $var_name'=$flag_default'
        var_name_list=$(echo $var_name $var_name_list) #trim spaces
    fi

    divided_help=false
    for ((; idx<maxloop; idx++))
    do
        arg=${args[$idx]}
        if [[ $divided_help == false && $arg =~ ^\# ]]; then
            divided_help=true
            helpdef=$arg
            helpdef=${helpdef###}
            continue
        fi
        if $divided_help; then
            helpdef+=$arg
            continue
        fi
    done

    if [[ -n "$helpdef" ]]; then
        _ZETOPT_OPTHELPS+=("$helpdef")
        helpidx=$((${#_ZETOPT_OPTHELPS[@]} - 1))
        if [[ $deftype == c ]]; then
            [[ $has_param == true ]] \
            && helpidx="$helpidx_cmd $helpidx" \
            || helpidx+=" 0"
        fi
    fi

    # store definition data as a string line
    _ZETOPT_DEFINED+="$id:$deftype:$short:$long:$param_def:$var_name_list:$settings:$helpidx$_LF"

    # defines parent subcommands automatically
    IFS=" "
    local ns= curr_ns=
    for ns in ${namespace//\// }
    do
        curr_ns="${curr_ns%*/}/$ns"
        [[ $_LF$_ZETOPT_DEFINED =~ $_LF${curr_ns}:c: ]] && return 0
        _ZETOPT_DEFINED+="${curr_ns}:c:::%.0~0...=0:::0 0$_LF"
    done
}

# Change the case of variable name accroding to ZETOPT_CFG_AUTOVAR_CASE
# def.) _zetopt::def::apply_case_config {AUTOVAR_NAME}
# e.g.) _zetopt::def::apply_case_config zv_foo
# STDOUT: string of case changed variable name
_zetopt::def::apply_case_config()
{
    local name=${1-}
    case $ZETOPT_CFG_AUTOVAR_CASE in
        none) :;;
        lower) [[ $name =~ [A-Z] ]] && name=$(_zetopt::utils::lowercase "$name") ||:;;
        upper) [[ $name =~ [a-z] ]] && name=$(_zetopt::utils::uppercase "$name") ||:;;
    esac
    echo "$name"
}

# prepare_parse(): Is definition data ready for parse?
# def.) _zetopt::def::prepare_parse
# e.g.) _zetopt::def::prepare_parse
# STDOUT: NONE
_zetopt::def::prepare_parse()
{
    _zetopt::validator::is_ready || return 1

    if [[ $_ZETOPT_DEF_ERROR == true ]]; then
        _zetopt::msg::script_error "Invalid Definition Data:" "Fix definition error before parse"
        return 1
    fi
    
    if [[ -z ${_ZETOPT_DEFINED:-} ]]; then
        _ZETOPT_DEFINED="/:c:::%.0~0...=0:::0 0$_LF"
    fi
    return 0
}

# defined(): Print the defined data. Print all if ID not given.
# def.) _zetopt::def::defined [ID]
# e.g.) _zetopt::def::defined /foo
# STDOUT: strings separated with $'\n'
_zetopt::def::defined()
{
    if [[ -z ${_ZETOPT_DEFINED-} ]]; then
        _ZETOPT_DEFINED="/:c:::%.0~0...=0::0 0$_LF"
    fi
    if [[ -z ${1-} ]]; then
        printf -- "%s" "$_ZETOPT_DEFINED"
        return 0
    fi
    _zetopt::def::field "$1" $ZETOPT_DEFID_ALL
}

# field(): Search and print the definition.
# def.) _zetopt::def::field {ID} [FIELD-DEF-NUMBER-TO-PRINT]
# e.g.) _zetopt::def::field /foo $ZETOPT_DEFID_ARG
# STDOUT: string
_zetopt::def::field()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if [[ ! $_LF$_ZETOPT_DEFINED$_LF =~ .*$_LF(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))$_LF.* ]]; then
        return 1
    fi
    local field="${2:-$ZETOPT_DEFID_ALL}"
    case "$field" in
        $ZETOPT_DEFID_ALL)      printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_ALL))]}";;
        $ZETOPT_DEFID_ID)       printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_ID))]}";;
        $ZETOPT_DEFID_TYPE)     printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_TYPE))]}";;
        $ZETOPT_DEFID_SHORT)    printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_SHORT))]}";;
        $ZETOPT_DEFID_LONG)     printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_LONG))]}";;
        $ZETOPT_DEFID_ARG)      printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_ARG))]}";;
        $ZETOPT_DEFID_VARNAME)  printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_VARNAME))]}";;
        $ZETOPT_DEFID_SETTINGS)    printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_SETTINGS))]}";;
        $ZETOPT_DEFID_HELP)     printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_HELP))]}";;
        *) return 1;;
    esac
}

# exists(): Check if the ID exists
# def.) _zetopt::def::exists {ID}
# e.g.) _zetopt::def::exists /foo
# STDOUT: NONE
_zetopt::def::exists()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1"
    [[ ! $id =~ ^/ ]] && id=/$id ||:
    [[ $_LF$_ZETOPT_DEFINED =~ $_LF${id}: ]]
}

# has_subcmd(): Check if the current namespace has subcommands
# def.) _zetopt::def::has_subcmd {NAMESPACE}
# e.g.) _zetopt::def::has_subcmd /sub
# STDOUT: NONE
_zetopt::def::has_subcmd()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1"
    [[ ! $ns =~ ^/ ]] && ns=/$ns ||:
    [[ ! $ns =~ /$ ]] && ns=$ns/ ||:
    [[ $_LF$_ZETOPT_DEFINED =~ $_LF${ns}[a-zA-Z0-9_-]+:c: ]]
}

# has_options(): Check if the current namespace has options
# def.) _zetopt::def::has_options {NAMESPACE}
# e.g.) _zetopt::def::has_options /sub
# STDOUT: NONE
_zetopt::def::has_options()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1"
    [[ ! $ns =~ ^/ ]] && ns=/$ns ||:
    [[ ! $ns =~ /$ ]] && ns=$ns/ ||:
    [[ $_LF$_ZETOPT_DEFINED =~ $_LF${ns}[a-zA-Z0-9_]+:o: ]]
}

# has_arguments(): Check if the current namespace has arguments
# def.) _zetopt::def::has_arguments {NAMESPACE}
# e.g.) _zetopt::def::has_arguments /sub
# STDOUT: NONE
_zetopt::def::has_arguments()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1"
    [[ ! $ns =~ ^/ ]] && ns=/$ns ||:
    [[ $ns != / ]] && ns=${ns%/} ||:
    [[ $_LF$_ZETOPT_DEFINED =~ $_LF${ns}:c:::-?[@%] ]]
}

# options(): Print option definition
# def.) _zetopt::def::options {NS}
# e.g.) _zetopt::def::options /foo/bar
# STDOUT: option definition
_zetopt::def::options()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1"
    [[ ! $ns =~ ^/ ]] && ns=/$ns ||:
    [[ ! $ns =~ /$ ]] && ns=$ns/ ||:
    local lines=$_ZETOPT_DEFINED
    while :
    do
        if [[ $_LF$lines =~ $_LF(${ns}[a-zA-Z0-9_]+:o:[^$_LF]+$_LF)(.*) ]]; then
            printf -- "%s" "${BASH_REMATCH[1]}"
            lines=${BASH_REMATCH[2]}
        else
            break
        fi
    done
}

# is_cmd(): Check if ID is command
# def.) _zetopt::def::is_cmd {ID}
# e.g.) _zetopt::def::is_cmd /sub
# STDOUT: NONE
_zetopt::def::is_cmd()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1"
    [[ ! $ns =~ ^/ ]] && ns=/$ns ||:
    [[ $ns != / ]] && ns=${ns%/} ||:
    [[ $_LF$_ZETOPT_DEFINED =~ $_LF${ns}:c: ]]
}

# namespaces(): Print namespace definition
# def.) _zetopt::def::namespaces
# e.g.) _zetopt::def::namespaces
# STDOUT: namespace definition
_zetopt::def::namespaces()
{
    local lines="$_ZETOPT_DEFINED"
    while :
    do
        if [[ $_LF$lines =~ $_LF([^:]+):c:[^$_LF]+$_LF(.*) ]]; then
            printf -- "%s\n" "${BASH_REMATCH[1]}"
            lines=${BASH_REMATCH[2]}
        else
            break
        fi
    done
}

# opt2id(): Print the identifier by searching with a namespace and a option name.
# If not found in the current namespace, search a global option in parent namespaces.
# def.) _zetopt::def::opt2id {NAMESPACE} {OPTION-NAME} {IS_SHORT}
# e.g.) _zetopt::def::opt2id /remote/add version
# STDOUT: an identifier
# RETURN: 0:No Error, 1:Not Found, 2:Ambiguous Name
_zetopt::def::opt2id()
{
    local ns="${1-}" opt="${2-}" is_short=${3-}
    if [[ -z $ns || -z $opt || -z $is_short ]]; then
        return 1
    fi

    [[ $ns != / && ! $ns =~ /$ ]] && ns=$ns/ ||:

    local regex= flags='[^:]*' tmpid=
    while :
    do
        # short
        if [[ $is_short == true ]]; then
            if [[ $_LF$_ZETOPT_DEFINED =~ $_LF(${ns}[a-zA-Z0-9_]+):o:$opt:[^:]*:[^:]*:[^:]*:${flags}: ]]; then
                printf -- "%s" "${BASH_REMATCH[1]}"
                return 0
            fi
        
        # long
        else
            if [[ $ZETOPT_CFG_ABBREVIATED_LONG == true ]]; then
                if [[ $_LF$_ZETOPT_DEFINED =~ $_LF(${ns}[a-zA-Z0-9_]+):o:[^:]?:${opt}[^:]*:[^:]*:[^:]*:${flags}:[^$_LF]+$_LF(.*) ]]; then
                    tmpid=${BASH_REMATCH[1]}

                    # reject ambiguous name
                    if [[ $_LF${BASH_REMATCH[2]} =~ $_LF(${ns}[a-zA-Z0-9_]+):o:[^:]?:${opt}[^:]*:[^:]*:[^:]*:${flags}: ]]; then
                        return 2
                    fi
                    printf -- "%s" "$tmpid"
                    return 0
                fi
            else
                if [[ $_LF$_ZETOPT_DEFINED =~ $_LF(${ns}[a-zA-Z0-9_]+):o:[^:]?:${opt}:[^:]*:[^:]*:${flags}: ]]; then
                    printf -- "%s" "${BASH_REMATCH[1]}"
                    return 0
                fi
            fi
        fi

        if [[ $ns == / ]]; then
            return 1
        fi
        ns=${ns%/*}  # remove the last /
        ns=${ns%/*}/ # parent ns
        flags="[^g:]*g[^g:]*"
    done
    return 1
}

# paramidx(): Print the index of the specified parameter name
# def.) _zetopt::def::paramidx {ID} {PARAM-NAME}
# e.g.) _zetopt::def::paramidx /foo name
# STDOUT: an integer
_zetopt::def::paramidx()
{
    if [[ $# -lt 2 ]]; then
        return 1
    fi
    if [[ ! $2 =~ ^$_REG_VARNAME$ ]]; then
        return 1
    fi
    local id="$1"
    [[ ! $id =~ ^/ ]] && id="/$id" ||:
    local def_str="$(_zetopt::def::field "$id" $ZETOPT_DEFID_ARG)"
    if [[ $def_str =~ [@%]${2}[.]([0-9]+) ]]; then
        printf -- "%s" ${BASH_REMATCH[1]}
        return 0
    fi
    return 1
}

# keyparams2idx(): translate parameter names to index numbers
# def.) _zetopt::def::keyparams2idx {ID} {KEYS}
# e.g.) _zetopt::def::keyparams2idx /foo FOO,BAR $,BAZ
# STDOUT: string of translated keys
_zetopt::def::keyparams2idx()
{
    if [[ ! $# -eq 2 ]]; then
        return 1
    fi
    local id="$1"
    [[ ! $id =~ ^/ ]] && id="/$id" ||:
    local key="$2" head tail name
    local def_args="$(_zetopt::def::field "$id" $ZETOPT_DEFID_ARG)"
    if [[ $def_args =~ [@%] ]]; then
        while true
        do
            if [[ $key =~ ^([0-9\^\$@,\ \-:]*)($_REG_VARNAME)(.*)$ ]]; then
                head=${BASH_REMATCH[1]}
                name=${BASH_REMATCH[2]}
                tail=${BASH_REMATCH[3]}
                if [[ ! $def_args =~ [@%]${name}[.]([0-9]+) ]]; then
                    _zetopt::msg::script_error "Parameter Name Not Found:" "$name"
                    return 1
                fi
                key=$head${BASH_REMATCH[1]}$tail
            else
                break
            fi
        done
    fi
    printf -- "%s" "$key"
}

# paramlen(): Print the length of parameters
# def.) _zetopt::def::paramlen {ID} [all | required | @ | optional | % | max]
# e.g.) _zetopt::def::paramlen /foo required
# STDOUT: an integer
_zetopt::def::paramlen()
{
    local id="$1"
    [[ ! $id =~ ^/ ]] && id="/$id" ||:
    if ! _zetopt::def::exists "$id"; then
        echo 0; return 1
    fi
    local def="$(_zetopt::def::field "$id" $ZETOPT_DEFID_ARG)"
    if [[ ! $def =~ [@%] ]]; then
        echo 0; return 0
    fi

    declare -i reqcnt optcnt out
    local tmp=${def//[!@]/}
    reqcnt=${#tmp} 
    tmp=${def//[!%]/}
    optcnt=${#tmp}

    case ${2-} in
        required | @) out=$reqcnt;;
        optional | %) out=$optcnt;;
        max)
            [[ $def =~ ([.]{3,3}([1-9][0-9]*)?)?=[0-9]+$ ]] ||:
            if [[ -n ${BASH_REMATCH[1]} ]]; then
                [[ -n ${BASH_REMATCH[2]} ]] \
                && out=$reqcnt+$optcnt+${BASH_REMATCH[2]}-1 \
                || out=$((1<<31)) #2147483648
            else
                out=$reqcnt+$optcnt
            fi
            ;;
        "" | all) out=$reqcnt+$optcnt;;
        *)        out=$reqcnt+$optcnt;;
    esac
    echo $out
}

# default(): Print default values
# def.) _zetopt::def::default {ID}
# e.g.) _zetopt::def::default /foo
# STDOUT: default ref numbers separated with space
_zetopt::def::default()
{
    if [[ -z ${_ZETOPT_DEFINED:-} || -z ${1-} ]]; then
        _zetopt::msg::script_error "Syntax Error"
        return 1
    fi

    local id="$1"
    [[ ! $id =~ ^/ ]] && id="/$id" ||:
    if ! _zetopt::def::exists "$id"; then
        _zetopt::msg::script_error "No Such Indentifier:" "${1-}"
        return 1
    fi
    shift

    local IFS=' ' params output_list
    output_list=()
    local def_args="$(_zetopt::def::field "$id" $ZETOPT_DEFID_ARG)"
    params=($def_args)
    if [[ ${#params[@]} -eq 0 ]]; then
        printf -- "%s\n" 0
        return 0
    elif [[ ! $def_args =~ [%@] ]]; then
        printf -- "%s\n" "${params[0]#d=}"
        return 0
    fi
    local defaults_idx_string="$(printf -- " %s " "${params[@]#*=}")"
    echo $defaults_idx_string
}


#------------------------------------------------------------
# _zetopt::validator
#------------------------------------------------------------

# def(): Define validator
# ** Must be executed in the current shell **
# def.) _zetopt::validator::def [-f | --function] [-i | --ignore-case] [-n | --not] {<NAME> <REGEXP | FUNCNAME> [#<ERROR_MESSAGE>]}
# e.g.) _zetopt::validator::def is_number '^[1-9][0-9]*$' "#Input Number"
# STDOUT: NONE
_zetopt::validator::def()
{
    if [[ -z ${_ZETOPT_VALIDATOR_KEYS:-} ]]; then
        _ZETOPT_VALIDATOR_KEYS=
        _ZETOPT_VALIDATOR_DATA=("")
        _ZETOPT_VALIDATOR_ERRMSG=("")
    fi

    declare -i validator_idx=0 msg_idx=0
    local IFS=$_IFS_DEFAULT name= validator= type=r errmsg= flags= error=false
    while [[ $# -ne 0 ]]
    do
        case "$1" in
            -f | --function)
                type=f; shift;;
            -r | --regexp)
                type=r; shift;;
            -c | --choice)
                type=c; shift;;
            -a | --array)
                type=a; shift;;
            -i | --ignore-case)
                flags+=i; shift;;
            -n | --not)
                flags+=n; shift;;
            --*)
                error=true; break;;
            -*)
                if [[ ! $1 =~ ^-[cfinr]+$ ]]; then
                    error=true; break
                fi
                [[ $1 =~ f ]] && type=f
                [[ $1 =~ r ]] && type=r
                [[ $1 =~ c ]] && type=c
                [[ $1 =~ a ]] && type=a
                [[ $1 =~ i ]] && flags+=i
                [[ $1 =~ n ]] && flags+=n
                shift;;
            *)
                if [[ -z $name ]]; then
                    name=$1; shift; continue
                elif [[ -z $validator ]]; then
                    validator=$1; shift; continue
                elif [[ -z $errmsg ]]; then
                    errmsg=$1; shift; continue
                fi
                error=true
                break;;
        esac
    done

    # check errors
    if [[ $error == true ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "zetopt def-validator [-r | --regexp] [-f | --function] [-c | --choice] [-a | --array] [-i | --ignore-case] [-n | --not] {<NAME> <REGEXP | FUNCNAME> [#<ERROR_MESSAGE>]}"
        return 1
    fi
    if [[ ! $name =~ ^$_REG_VARNAME$ ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "Invalid Validator Name:" "$name"
        return 1
    fi
    
    if [[ -n $errmsg && $errmsg =~ ^[^\#] ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "Help message should start with \"#\""
        return 1
    fi

    # save validator
    if [[ -n $errmsg ]]; then
        _ZETOPT_VALIDATOR_ERRMSG+=("${errmsg:1}")
        msg_idx=$((${#_ZETOPT_VALIDATOR_ERRMSG[@]} - 1))
    fi
    
    # update: already defined
    if [[ $_LF$_ZETOPT_VALIDATOR_KEYS =~ $_LF${name}:([0-9]+)$_LF ]]; then
        validator_idx=${BASH_REMATCH[1]}
        _ZETOPT_VALIDATOR_DATA[$validator_idx]="$name:$type:$flags:$msg_idx:$validator"
    # new
    else
        _ZETOPT_VALIDATOR_DATA+=("$name:$type:$flags:$msg_idx:$validator")
        validator_idx=$((${#_ZETOPT_VALIDATOR_DATA[@]} - 1))
        _ZETOPT_VALIDATOR_KEYS+=$name:$validator_idx$_LF
    fi
}

# validate(): Validate value
# ** Must be executed in the current shell **
# def.) _zetopt::validator::validate {ARG-DEFINITION} {VALUE-TO_VALIDATE}
# e.g.) _zetopt::validator::validate @FOO~1 123
# STDOUT: NONE
_zetopt::validator::validate()
{
    local param_def="${1-}" arg="${2-}"

    # no validator
    if [[ ! $param_def =~ [~]([1-9][0-9]*(,[1-9][0-9]*)*) ]]; then
        return 0
    fi

    local IFS=,
    set -- ${BASH_REMATCH[1]}
    IFS=$_IFS_DEFAULT

    while [[ $# -ne 0 ]]
    do
        declare -i validator_idx=$1
        shift 1

        if [[ ! ${_ZETOPT_VALIDATOR_DATA[$validator_idx]} =~ ^([^:]+):([acrf]):([in]*):([0-9]+):(.*)$ ]]; then
            _zetopt::msg::script_error "Internal Error:" "Validator Broken"
            return 1
        fi
        local validator_name="${BASH_REMATCH[1]}"
        local validator_type="${BASH_REMATCH[2]}"
        local validator_flags="${BASH_REMATCH[3]}"
        declare -i validator_msgidx="${BASH_REMATCH[4]}"
        local validator="${BASH_REMATCH[5]}"

        local result=$(
            # set ignore case option temporally
            if [[ $validator_flags =~ i ]]; then
                [[ -n ${ZSH_VERSION-} ]] \
                && setopt localoptions NOCASEMATCH \
                || shopt -s nocasematch
            fi

            # r: regexp
            if [[ $validator_type == r ]]; then
                if [[ ! $validator_flags =~ n ]]; then
                    [[ $arg =~ $validator ]] && printf -- "%s" true: || printf -- "%s" false:
                else
                    [[ $arg =~ $validator ]] && printf -- "%s" false: || printf -- "%s" true:
                fi
            # f: function
            elif [[ $validator_type == f ]]; then
                local PATH=$_PATH LC_ALL=$_LC_ALL LANG=$_LANG
                if [[ ! $validator_flags =~ n ]]; then
                    printf -- "%s" "$(out=$("$validator" "$arg" 2>&1) && printf -- "%s" "true:" || printf -- "%s" "false:$out")"
                else
                    printf -- "%s" "$(out=$("$validator" "$arg" 2>&1) && printf -- "%s" "false:$out" || printf -- "%s" "true:")"
                fi

            # c: choice
            elif [[ $validator_type == c ]]; then
                local IFS=, arr valid=false
                arr=($validator)
                IFS=$_IFS_DEFAULT
                for (( i=0; i<${#arr[*]}; i++ ))
                do
                    if [[ "${arr[$i]}" == "$arg" ]]; then
                        valid=true
                        break
                    fi
                done
                if [[ $validator_flags =~ n ]]; then
                    $valid && valid=false || valid=true
                fi
                printf -- "%s" "$valid:"
            
            # a: array
            elif [[ $validator_type == a ]]; then
                local arr valid=false
                eval 'arr=("${'$validator'[@]}")'
                for (( i=0; i<${#arr[*]}; i++ ))
                do
                    if [[ "${arr[$i]}" == "$arg" ]]; then
                        valid=true
                        break
                    fi
                done
                if [[ $validator_flags =~ n ]]; then
                    $valid && valid=false || valid=true
                fi
                printf -- "%s" "$valid:"
            fi
        )

        if [[ ${result%%:*} == false ]]; then
            # overwrite default error message with output of validator function
            local errmsg=${result#*:}
            if [[ -z $errmsg && $validator_msgidx -ne 0 ]]; then
                errmsg="${_ZETOPT_VALIDATOR_ERRMSG[validator_msgidx]}"
            fi

            if [[ -n $errmsg ]]; then
                _zetopt::msg::user_error Error "$arg:" "$errmsg"
            fi
            return 1
        fi
    done
    return 0
}

# is_ready(): Is validator ready for parse?
# def.) _zetopt::validator::is_ready
# e.g.) _zetopt::validator::is_ready
# STDOUT: NONE
_zetopt::validator::is_ready()
{
    local len=${#_ZETOPT_VALIDATOR_DATA[@]}
    if [[ $len -eq 0 ]]; then
        return 0
    fi

    local validator_name validator_type validator
    declare -i i=0 max_idx=$(($len - 1))
    for (( ; i<=max_idx; i++ ))
    do
        if [[ "${_ZETOPT_VALIDATOR_DATA[$i]}" =~ ^([^:]+):([acrf]):[in]*:[0-9]+:(.*)$ ]]; then
            validator_name="${BASH_REMATCH[1]}"
            validator_type="${BASH_REMATCH[2]}"
            validator="${BASH_REMATCH[3]}"
            if [[ -z $validator ]]; then
                _zetopt::msg::script_error "Undefined Validator:" "$validator_name"
                return 1
            fi
            if [[ $validator_type == f ]]; then
                [[ -n ${ZSH_VERSION-} ]] \
                && local _type=$(whence -w "$validator") \
                || local _type=$(type -t "$validator")
                if [[ ! ${_type#*:} =~ function ]]; then
                    _zetopt::msg::script_error "No Such Shell Function:" "$validator"
                    return 1
                fi
            fi
        fi
    done
}


#------------------------------------------------------------
# _zetopt::parser
#------------------------------------------------------------

# init(): Initialize variables concerned with the parser. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::init
# e.g.) _zetopt::parser::init
# STDOUT: NONE
_zetopt::parser::init()
{
    ZETOPT_OPTERR_INVALID=()
    ZETOPT_OPTERR_MISSING_REQUIRED=()
    ZETOPT_OPTERR_UNDEFINED=()
    ZETOPT_OPTERR_MISSING_OPTIONAL=()
    ZETOPT_PARSE_ERRORS=$ZETOPT_STATUS_NORMAL
    ZETOPT_LAST_COMMAND=/
    ZETOPT_EXCLUSIVE_OPTION_ID=
}

# parse(): Parse arguments. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::parse {ARGUMENTS}
# e.g.) _zetopt::parser::parse "$@"
# STDOUT: NONE
_zetopt::parser::parse()
{
    _zetopt::def::prepare_parse || return 1
    _zetopt::parser::init || return 1
    _zetopt::data::init || return 1
    
    local optname= optnames_len= optarg= idx= opt_prefix= pseudoname=
    local additional_args_count=0 consumed_args_count= args
    local namespace=/ ns=/ check_subcmd=true error_subcmd_name=
    
    # internal global variables
    declare -i _CONSUMED_ARGS_COUNT=0

    args=()
    while [[ $# -ne 0 ]]
    do
        _CONSUMED_ARGS_COUNT=0
        
        # Double Hyphen Only
        if [[ $1 == -- ]]; then
            if [[ $ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN != true ]]; then
                shift
                _ZETOPT_TEMP_ARGV+=("$@")
                break
            else
                _ZETOPT_TEMP_ARGV+=("$1")
                shift
            fi
            check_subcmd=false

        # Single Prefix Only
        elif [[ $1 =~ ^[-+]$ ]]; then
            _ZETOPT_TEMP_ARGV+=("$1")
            shift
            check_subcmd=false

        # Blank String
        elif [[ $1 == "" ]]; then
            if [[ $ZETOPT_CFG_IGNORE_BLANK_STRING == true ]]; then
                shift
                continue
            fi
            _ZETOPT_TEMP_ARGV+=("$1")
            shift
            check_subcmd=false

        # Long option
        elif [[ $1 =~ ^--[^-]
                || ($ZETOPT_CFG_SINGLE_PREFIX_LONG == true && $1 =~ ^-[^-] )
                || ($ZETOPT_CFG_PREFIX_PLUS == true && (($1 =~ ^[+][+][^+] ) || ($ZETOPT_CFG_SINGLE_PREFIX_LONG == true && $1 =~ ^[+][^+] )))
            ]]; then
            if [[ ! $1 =~ ^([-+]{1,2})([a-zA-Z0-9_]+(-[a-zA-Z0-9_]+)*)((:[a-zA-Z0-9_]+)*)(=(.*$))?$ ]]; then
                ZETOPT_OPTERR_INVALID+=("$1")
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_INVALID_OPTFORMAT))
                shift
                check_subcmd=false
                continue
            fi
            opt_prefix=${BASH_REMATCH[1]}
            optname=${BASH_REMATCH[2]}
            pseudoname=${BASH_REMATCH[4]/:/}
            optarg=${BASH_REMATCH[7]}
            shift
            if [[ -n $optarg ]]; then
                additional_args_count=1
                _zetopt::parser::setopt $namespace $opt_prefix $optname "$pseudoname" "$optarg" "$@" ||:
            else
                _zetopt::parser::setopt $namespace $opt_prefix $optname "$pseudoname" "$@" ||:
            fi
            [[ -n $ZETOPT_EXCLUSIVE_OPTION_ID ]] && return 0 ||:
            check_subcmd=false

        # short option(s)
        elif [[ $1 =~ ^(-)([^-].*)$ || ($ZETOPT_CFG_PREFIX_PLUS == true && $1 =~ ^([+])([^+].*)$) ]]; then
            opt_prefix=${BASH_REMATCH[1]}
            optnames=${BASH_REMATCH[2]}
            optnames_len=${#optnames}
            shift
            
            consumed_args_count=$_CONSUMED_ARGS_COUNT
            for ((idx=0; idx<$optnames_len; idx++))
            do
                optname=${optnames:$idx:1}
                if [[ $((idx + 1)) -lt $optnames_len ]]; then
                    if [[ $ZETOPT_CFG_PSEUDO_OPTION == true && ${optnames:$((idx+1)):1} == : ]]; then
                        pseudoname=${optnames:$((idx+2)):$(($optnames_len - $idx - 1))}
                        _zetopt::parser::setopt $namespace $opt_prefix $optname "$pseudoname" "$@" ||:
                        [[ -n $ZETOPT_EXCLUSIVE_OPTION_ID ]] && return 0 ||:
                        break
                    else
                        if [[ $ZETOPT_CFG_CONCATENATED_OPTARG == true ]]; then
                            _zetopt::parser::setopt $namespace $opt_prefix $optname "" "${optnames:$((idx+1)):$(($optnames_len - $idx - 1))}" "$@" ||:
                            [[ -n $ZETOPT_EXCLUSIVE_OPTION_ID ]] && return 0 ||:
                            if [[ $consumed_args_count -ne $_CONSUMED_ARGS_COUNT ]]; then
                                additional_args_count=1
                                break
                            fi
                        else
                            _zetopt::parser::setopt $namespace $opt_prefix $optname "" "$@" ||:
                            [[ -n $ZETOPT_EXCLUSIVE_OPTION_ID ]] && return 0 ||:
                        fi
                    fi
                else
                    _zetopt::parser::setopt $namespace $opt_prefix $optname "" "$@" ||:
                    [[ -n $ZETOPT_EXCLUSIVE_OPTION_ID ]] && return 0 ||:
                fi
            done
            check_subcmd=false

        # Positional Arguments or Subcommand
        else
            # Subcommand
            if [[ $check_subcmd == true ]] && _zetopt::def::has_subcmd "$namespace"; then
                ns="${namespace%/}/$1"
                if ! _zetopt::def::exists "$ns"; then
                    check_subcmd=false
                    if [[ $ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR == true ]]; then
                        _ZETOPT_TEMP_ARGV+=("$1")
                        shift
                        continue
                    fi
                    error_subcmd_name="${ns//\// }"
                    _zetopt::msg::user_error Error "Undefined Sub-Command:" "$error_subcmd_name"
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_SUBCMD))
                    break
                fi

                # Change namespace
                namespace=$ns
                ZETOPT_LAST_COMMAND=$namespace

                shift
                continue
            fi

            # Positional Arguments
            _ZETOPT_TEMP_ARGV+=("$1")
            shift
        fi

        # shift
        if [[ $(($_CONSUMED_ARGS_COUNT - $additional_args_count)) -gt 0 ]]; then
            shift $(($_CONSUMED_ARGS_COUNT - $additional_args_count))
        fi
    done

    # update command count
    _zetopt::parser::setcmd $ZETOPT_LAST_COMMAND ||:

    # assign positional args
    if [[ $ZETOPT_PARSE_ERRORS -le $ZETOPT_STATUS_ERROR_THRESHOLD ]]; then
        _zetopt::parser::assign_args "$namespace" ||:
    fi
    
    # show errors
    if [[ $ZETOPT_CFG_ERRMSG_USER_ERROR == true && $ZETOPT_PARSE_ERRORS -ne 0 ]]; then
        IFS=$_IFS_DEFAULT
        local subcmdstr="$ZETOPT_CALLER_NAME${namespace//\// }" msg=
        subcmdstr=${subcmdstr% }

        # Undefined Options
        if [[ $(($ZETOPT_PARSE_ERRORS & $ZETOPT_STATUS_UNDEFINED_OPTION)) -ne 0 ]]; then
            msg=($subcmdstr $(<<< "${ZETOPT_OPTERR_UNDEFINED[*]}" \tr " " "\n" | \sort | \uniq))
            _zetopt::msg::user_error Warning "Undefined Option(s):" "${msg[*]}"
        fi

        # Invalid Format Options
        if [[ $(($ZETOPT_PARSE_ERRORS & $ZETOPT_STATUS_INVALID_OPTFORMAT)) -ne 0 ]]; then
            msg=($subcmdstr $(<<< "${ZETOPT_OPTERR_INVALID[*]}" \tr " " "\n" | \sort | \uniq))
            _zetopt::msg::user_error Error "Invalid Format Option(s):" "${msg[*]}"
        fi

        # Missing Required Option Arguments
        if [[ $(($ZETOPT_PARSE_ERRORS & $ZETOPT_STATUS_MISSING_REQUIRED_OPTARGS)) -ne 0 ]]; then
            msg=($subcmdstr $(<<< "${ZETOPT_OPTERR_MISSING_REQUIRED[*]}" \tr " " "\n" | \sort | \uniq))
            _zetopt::msg::user_error Error "Missing Required Option Argument(s):" "${msg[*]}"
        fi

        # Missing Required Positional Arguments
        if [[ $(($ZETOPT_PARSE_ERRORS & $ZETOPT_STATUS_MISSING_REQUIRED_ARGS)) -ne 0 ]]; then
            msg=($subcmdstr "$(_zetopt::def::paramlen $namespace required) Argument(s) Required")
            _zetopt::msg::user_error Error "Missing Required Argument(s):" "${msg[*]}"
        fi

        # Too Match Positional Arguments
        if [[ $(($ZETOPT_PARSE_ERRORS & $ZETOPT_STATUS_EXTRA_ARGS)) -ne 0 ]]; then
            msg=("\"$subcmdstr\" can take up to $(_zetopt::def::paramlen $namespace max) arguments. But ${#_ZETOPT_TEMP_ARGV[@]} were given.")
            _zetopt::msg::user_error Warning "Too Match Arguments:" "${msg[*]}"
        fi
    fi

    [[ $ZETOPT_PARSE_ERRORS -le $ZETOPT_STATUS_ERROR_THRESHOLD ]]
}

# setcmd(): Increment the set count of a sub-command. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::setcmd {NAMESPACE}
# e.g.) _zetopt::parser::setcmd /sub
# STDOUT: NONE
_zetopt::parser::setcmd()
{
    local id=${1-}
    if [[ ! $_LF$_ZETOPT_PARSED =~ (.*$_LF)(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))($_LF.*) ]]; then
        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_SUBCMD))
        return 1
    fi

    local head_lines="${BASH_REMATCH[1]:1}"
    local tail_lines="${BASH_REMATCH[10]}"
    local offset=2

    local IFS=:
    set -- ${BASH_REMATCH[$(($offset + $ZETOPT_DATAID_ALL))]}
    local cnt=$(($7 + 1))
    local pseudoidx=0
    _ZETOPT_PARSED=$head_lines$1:$2:$3:$ZETOPT_TYPE_CMD:$pseudoidx:$ZETOPT_STATUS_NORMAL:$cnt$tail_lines
}

# setopt(): Set option data. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::setopt {NAMESPACE} {PREFIX} {OPTNAME} {PSEUDO} [ARGUMENTS]
# e.g.) _zetopt::parser::setopt /sub/cmd - version "$@"
# STDOUT: NONE
_zetopt::parser::setopt()
{
    local namespace="${1-}" opt_prefix="${2-}" opt="${3-}" pseudoname="${4-}" args
    shift 4
    args=("$@")
    local is_short=$( [[ ${#opt_prefix} -eq 1 && $ZETOPT_CFG_SINGLE_PREFIX_LONG != true ]] && echo true || echo false)
    local id="$(_zetopt::def::opt2id "$namespace" "$opt" "$is_short" || echo ERROR:$?)"
    if [[ $id =~ ^ERROR:[0-9]+$ ]]; then
        ZETOPT_OPTERR_UNDEFINED+=("$opt_prefix$opt")
        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_OPTION))
        return 1
    fi

    # exclusive option
    local settings=$(_zetopt::def::field "$id" $ZETOPT_DEFID_SETTINGS)
    if [[ " $settings " =~ \ flags=[^\ ]*x[^\ ]*\  ]]; then
        local lc=$ZETOPT_LAST_COMMAND
        _zetopt::def::reset
        _zetopt::data::init
        _zetopt::parser::init
        ZETOPT_LAST_COMMAND=$lc
        ZETOPT_EXCLUSIVE_OPTION_ID=$id
    fi

    if [[ ! $_LF$_ZETOPT_PARSED =~ (.*$_LF)(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))($_LF.*) ]]; then
        return 1
    fi
    local head_lines="${BASH_REMATCH[1]:1}"
    local tail_lines="${BASH_REMATCH[10]}"
    local IFS=:
    set -- ${BASH_REMATCH[$((2 + $ZETOPT_DATAID_ALL))]}
    local id="$1" refs_str="$2" argcs="$3" types="$4" pseudo_idexs="$5" stat="$6" cnt="$7"
    local curr_stat=$ZETOPT_STATUS_NORMAL

    local ref_arr paramdef_str="$(_zetopt::def::field "$id" $ZETOPT_DEFID_ARG)"
    declare -i optarg_idx=${#_ZETOPT_DATA[@]}
    declare -i arg_cnt=0
    ref_arr=()

    [[ " $settings " =~ \ t=([0-9]+)\ f=([0-9]+)\  ]]
    local val=
    case $opt_prefix in
        -*) val=${_ZETOPT_DEFAULTS[${BASH_REMATCH[1]}]};;
        +*) val=${_ZETOPT_DEFAULTS[${BASH_REMATCH[2]}]};;
    esac

    # autovar
    if $ZETOPT_CFG_AUTOVAR; then
        local var_name var_names var_names_str="$(_zetopt::def::field "$id" $ZETOPT_DEFID_VARNAME)"
        IFS=" "
        var_names=($var_names_str)
        var_name=${var_names[0]}
        eval $var_name'=$val'
    fi

    # no argument required
    if [[ -z $paramdef_str ]]; then
        _ZETOPT_DATA+=("$val")
        ref_arr=($optarg_idx)
    
    # argument required
    else
        local arg def def_arr varlen_mode=false no_avail_args=false
        IFS=" "
        def_arr=($paramdef_str)
        declare -i def_len=${#def_arr[@]} def_idx=0
        declare -i arg_def_max arg_idx=0 arg_max_idx=${#args[@]}

        while [[ $def_idx -lt $def_len ]]
        do
            def=${def_arr[$def_idx]}

            # autovar
            if $ZETOPT_CFG_AUTOVAR; then
                var_name=${var_names[def_idx+1]}
            fi

            # there are available args
            if [[ $arg_idx -ge $arg_max_idx ]]; then
                no_avail_args=true
                break
            fi
            arg="${args[$arg_idx]}"

            # ignore blank string
            if [[ -z $arg && $ZETOPT_CFG_IGNORE_BLANK_STRING == true ]]; then
                arg_idx+=1
                continue
            fi

            # check arg format
            if [[ ! (
                    $arg =~ ^[^-+]
                || $arg =~ ^[-+]$
                || $arg == ""
                || ($arg =~ ^-[^-] && $def =~ ^-[^-])
                || ($arg =~ ^--.+ && $def =~ ^--)
                || ($ZETOPT_CFG_PREFIX_PLUS == true
                    && (   ($arg =~ ^[+][^+] && $def =~ ^-[^-])
                        || ($arg =~ ^[+][+].+ && $def =~ ^--)
                    ))
                || ($arg == "--" && $ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN == true)
            ) ]]; then
                no_avail_args=true
                break
            fi

            # validate
            if ! _zetopt::validator::validate "$def" "$arg"; then
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_VALIDATOR_FAILED))
                return 1
            fi

            if [[ $varlen_mode == false && $def =~ [.]{3,3} ]]; then
                varlen_mode=true
                arg_def_max=$(_zetopt::def::paramlen $id max)

                # autovar
                if $ZETOPT_CFG_AUTOVAR; then
                    eval $var_name'=()' # array
                fi
            fi

            _ZETOPT_DATA+=("$arg")

            # autovar
            if $ZETOPT_CFG_AUTOVAR; then
                [[ $varlen_mode == true ]] \
                && eval $var_name'+=("$arg")' \
                || eval $var_name'=$arg'
            fi

            ref_arr+=($optarg_idx)
            arg_cnt+=1
            _CONSUMED_ARGS_COUNT+=1

            arg_idx+=1
            optarg_idx+=1

            # increment def_idx if def is not a variable-length argument
            if [[ $varlen_mode == false ]]; then
                def_idx+=1
            elif [[ $arg_cnt -ge $arg_def_max ]]; then
                break
            fi
        done

        # arg length not enough
        if [[ $no_avail_args == true && $varlen_mode == false ]]; then
            # required
            if [[ $def =~ @ ]]; then
                curr_stat=$ZETOPT_STATUS_MISSING_REQUIRED_OPTARGS
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | curr_stat))
                ZETOPT_OPTERR_MISSING_REQUIRED+=("$opt_prefix$opt")
            
            # optional
            else
                curr_stat=$ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | curr_stat))
                ZETOPT_OPTERR_MISSING_OPTIONAL+=("$opt_prefix$opt")

                while [[ $def_idx -lt $def_len ]]
                do
                    def=${def_arr[$def_idx]}

                    # has default value
                    if [[ $def =~ ([.]{3,3}([1-9][0-9]*)?)?=([1-9][0-9]*) ]]; then
                        arg=${_ZETOPT_DATA[${BASH_REMATCH[3]}]}
                        #ref_arr+=(${BASH_REMATCH[3]})
                    else
                        arg=${_ZETOPT_DATA[0]}
                        #ref_arr+=(0)
                    fi

                    # autovar
                    if $ZETOPT_CFG_AUTOVAR; then
                        var_name=${var_names[def_idx+1]}
                        eval $var_name'=$arg'
                    fi
                    def_idx+=1
                done
            fi
        fi
    fi

    local type=$ZETOPT_TYPE_CMD
    case $opt_prefix in
        -)  type=$ZETOPT_TYPE_SHORT;;
        --) type=$ZETOPT_TYPE_LONG;;
        +)  type=$ZETOPT_TYPE_PLUS;;
        ++) type=$ZETOPT_TYPE_PLUS;;
    esac

    _ZETOPT_DATA+=("$pseudoname")
    local pseudoidx=$((${#_ZETOPT_DATA[@]} - 1))

    IFS=" "
    if [[ $cnt -eq 0 ]]; then
        stat="$curr_stat"
        refs_str="${ref_arr[*]-}"
        argcs="$arg_cnt"
        types="$type"
        pseudo_idexs="$pseudoidx"
    else
        stat="$stat $curr_stat"
        refs_str="$refs_str,${ref_arr[*]-}"
        argcs="$argcs $arg_cnt"
        types="$types $type"
        pseudo_idexs="$pseudo_idexs $pseudoidx"
    fi
    cnt=$(($cnt + 1))

    _ZETOPT_PARSED="$head_lines$id:$refs_str:$argcs:$types:$pseudo_idexs:$stat:$cnt$tail_lines"
    [[ $curr_stat -le $ZETOPT_STATUS_ERROR_THRESHOLD ]]
}


# assign_args(): Assign indexes to subcommand parameters. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::assign_args {NAMESPACE}
# e.g.) _zetopt::parser::assign_args /sub/cmd/
# STDOUT: NONE
_zetopt::parser::assign_args()
{
    local id="${1-}"
    declare -i def_max_len=$(_zetopt::def::paramlen "$id" max)
    if [[ $def_max_len -eq 0 ]]; then
        return 0
    fi
    local arg def_arr def ref_arr
    local IFS=' '
    def_arr=($(_zetopt::def::field "$id" $ZETOPT_DEFID_ARG))
    ref_arr=()
    declare -i def_len=${#def_arr[@]} arg_len=${#_ZETOPT_TEMP_ARGV[@]} rtn=$ZETOPT_STATUS_NORMAL idx maxloop
    local var_name var_names var_names_str="$(_zetopt::def::field "$id" $ZETOPT_DEFID_VARNAME)"
    if [[ -z $var_names_str ]]; then
        var_names_str=${ZETOPT_CFG_AUTOVAR_PREFIX}${ZETOPT_LAST_COMMAND:1}
        var_names_str=${var_names_str//[\/\-]/_}0
    fi
    var_names=($var_names_str)

    # enough
    if [[ $arg_len -ge $def_max_len ]]; then
        ref_arr=($(eval "echo {0..$((def_max_len - 1))}"))
        maxloop=$def_len

        # explicit defined arguments
        for ((idx=0; idx<maxloop; idx++))
        do
            def=${def_arr[idx]}
            arg=${_ZETOPT_TEMP_ARGV[ref_arr[idx]]}
            
            # validate
            if ! _zetopt::validator::validate "$def" "$arg"; then
                rtn=$((rtn | ZETOPT_STATUS_VALIDATOR_FAILED))
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                continue
            fi
            _ZETOPT_DATA+=("$arg")
            ref_arr[$idx]=$((${#_ZETOPT_DATA[@]} - 1))
            
            # autovar
            if $ZETOPT_CFG_AUTOVAR; then
                var_name=${var_names[idx+1]}
                if [[ $def =~ [.]{3,3} ]]; then
                    eval $var_name'=("$arg")'
                else
                    eval $var_name'=$arg'
                fi
            fi
        done
        
        # variable length arguments
        for ((; idx<def_max_len; idx++))
        do
            arg=${_ZETOPT_TEMP_ARGV[ref_arr[idx]]}
            _ZETOPT_DATA+=("$arg")
            ref_arr[$idx]=$((${#_ZETOPT_DATA[@]} - 1))

            # autovar
            if $ZETOPT_CFG_AUTOVAR; then
                eval $var_name'+=("$arg")'
            fi
        done

        # too match arguments
        if [[ $arg_len -gt $def_max_len ]]; then
            local start_idx=$((${#_ZETOPT_DATA[@]} - 1 + 1))
            _ZETOPT_DATA+=("${_ZETOPT_TEMP_ARGV[@]:$def_max_len}")
            local end_idx=$((${#_ZETOPT_DATA[@]} - 1))
            _ZETOPT_EXTRA_ARGV=($(eval 'echo {'$start_idx'..'$end_idx'}'))
            rtn=$((rtn | ZETOPT_STATUS_EXTRA_ARGS))
            ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
        fi

    # not enough
    else
        # has some args
        declare -i ref_idx=0
        local varlen_mode=false
        if [[ $arg_len -ne 0 ]]; then
            ref_idx=$arg_len-1
            ref_arr=($(eval "echo {0..$ref_idx}"))
            ref_idx+=1

            maxloop=$arg_len
            local def=
            for ((idx=0; idx<maxloop; idx++))
            do
                if [[ $idx -lt ${#def_arr[@]} ]]; then
                    def=${def_arr[idx]}

                    # autovar
                    if $ZETOPT_CFG_AUTOVAR; then
                        var_name=${var_names[idx+1]}
                    fi
                else
                    def=${def_arr[$((${#def_arr[@]} - 1))]}

                    # autovar
                    if $ZETOPT_CFG_AUTOVAR; then
                        var_name=${var_names[$((${#def_arr[@]} - 1 + 1))]}
                    fi
                fi
                arg=${_ZETOPT_TEMP_ARGV[ref_arr[idx]]}
                
                # validate
                if ! _zetopt::validator::validate "$def" "$arg"; then
                    rtn=$((rtn | ZETOPT_STATUS_VALIDATOR_FAILED))
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                fi

                _ZETOPT_DATA+=("$arg")
                ref_arr[$idx]=$((${#_ZETOPT_DATA[@]} - 1))

                if [[ $varlen_mode == false && $def =~ [.]{3,3} ]]; then
                    varlen_mode=true

                    # autovar
                    if $ZETOPT_CFG_AUTOVAR; then
                        eval $var_name'=()'
                    fi
                fi

                # autovar
                if $ZETOPT_CFG_AUTOVAR; then
                    if [[ $def =~ [.]{3,3} ]]; then
                        eval $var_name'+=("$arg")'
                    else
                        eval $var_name'=$arg'
                    fi
                fi
            done
        fi

        maxloop=$def_len
        declare -i default_idx
        for ((; ref_idx<maxloop; ref_idx++))
        do
            # missing required
            if [[ ${def_arr[ref_idx]} =~ @ ]]; then
                rtn=$((rtn | ZETOPT_STATUS_MISSING_REQUIRED_ARGS))
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                break
            fi
            if [[ ! ${def_arr[ref_idx]} =~ \=([1-9][0-9]*)$ ]]; then
                rtn=$((rtn | ZETOPT_STATUS_MISSING_OPTIONAL_ARGS))
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                break
            fi
            arg=${_ZETOPT_DATA[${BASH_REMATCH[1]}]}
            _ZETOPT_DATA+=("$arg")
            ref_arr+=($((${#_ZETOPT_DATA[@]} - 1)))
        done
    fi

    # update parsed data
    if [[ ! $_LF$_ZETOPT_PARSED =~ (.*$_LF)(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))($_LF.*) ]]; then
        return 1
    fi
    local head_lines="${BASH_REMATCH[1]:1}"
    local tail_lines="${BASH_REMATCH[10]}"
    local offset=2
    local line="${BASH_REMATCH[$((offset + ZETOPT_DATAID_ALL))]}"
    local id="${BASH_REMATCH[$((offset + ZETOPT_DATAID_ID))]}"
    local type="${BASH_REMATCH[$((offset + ZETOPT_DATAID_TYPE))]}"
    local pseudoname="${BASH_REMATCH[$((offset + ZETOPT_DATAID_PSEUDO))]}"
    local count="${BASH_REMATCH[$((offset + ZETOPT_DATAID_COUNT))]}"
    IFS=' '
    local refs_str="${ref_arr[*]-}"
    local argcs=${#ref_arr[@]}
    _ZETOPT_PARSED="$head_lines$id:$refs_str:$argcs:$type:$pseudoname:$rtn:$count$tail_lines"
    return $rtn
}


#------------------------------------------------------------
# _zetopt::data
#------------------------------------------------------------

# init(): Initialize variables concerned with the parsed data. 
# ** Must be executed in the current shell **
# def.) _zetopt::data::init
# e.g.) _zetopt::data::init
# STDOUT: NONE
_zetopt::data::init()
{
    _ZETOPT_PARSED=
    local IFS=$_LF line=
    for line in ${_ZETOPT_DEFINED//+/} # remove global signs
    do
        IFS=:
        set -- $line
        _ZETOPT_PARSED+="$1::::::0$_LF"
    done
    _ZETOPT_DATA=("${_ZETOPT_DEFAULTS[@]}")
    _ZETOPT_TEMP_ARGV=()
    _ZETOPT_EXTRA_ARGV=()
}

# parsed(): Print the parsed data. Print all if ID not given
# def.) _zetopt::data::parsed [ID]
# e.g.) _zetopt::data::parsed foo
# STDOUT: strings separated with $'\n'
_zetopt::data::parsed()
{
    if [[ -z ${1-} ]]; then
        echo "${_ZETOPT_PARSED-}"
        return 0
    fi
    _zetopt::data::field "$1" $ZETOPT_DATAID_ALL
}

# field(): Search and print the parsed data
# def.) _zetopt::data::field {ID} [FILED-DATA-NUMBER]
# e.g.) _zetopt::data::field /foo $ZETOPT_DATAID_ARGV
# STDOUT: string
_zetopt::data::field()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id" ||:
    local field="${2:-$ZETOPT_DATAID_ALL}"

    if [[ $field == $ZETOPT_DATAID_DEFAULT ]]; then
        if ! _zetopt::def::exists $id; then
            return 1
        fi
        printf -- "%s\n" "$(_zetopt::def::default $id)"
        return 0
    fi

    if [[ ! $_LF${_ZETOPT_PARSED-}$_LF =~ .*$_LF((${id}[+/]?):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))$_LF.* ]]; then
        return 1
    fi
    case "$field" in
        $ZETOPT_DATAID_ALL)    printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DATAID_ALL))]}";;
        $ZETOPT_DATAID_ID)     printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DATAID_ID))]}";;
        $ZETOPT_DATAID_ARGV)   printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DATAID_ARGV))]}";;
        $ZETOPT_DATAID_ARGC)   printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DATAID_ARGC))]}";;
        $ZETOPT_DATAID_TYPE)   printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DATAID_TYPE))]}";;
        $ZETOPT_DATAID_PSEUDO) printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DATAID_PSEUDO))]}";;
        $ZETOPT_DATAID_STATUS) printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DATAID_STATUS))]}";;
        $ZETOPT_DATAID_COUNT)  printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DATAID_COUNT))]}";;
        $ZETOPT_DATAID_EXTRA_ARGV) printf -- "%s\n" "$(_zetopt::data::extra_field $id)";;
        *) return 1;;
    esac
}

_zetopt::data::extra_field()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1"
    [[ ! $id =~ ^/ ]] && id=/$id ||:
    [[ ! $id =~ /$ ]] && id=$id/ ||:
    
    if [[ $ZETOPT_LAST_COMMAND == $id ]]; then
        echo "${_ZETOPT_EXTRA_ARGV[@]-}"
    fi
}

# isset(): Check if the option is set
# def.) _zetopt::data::isset {ID}
# e.g.) _zetopt::data::isset /foo
# STDOUT: NONE
_zetopt::data::isset()
{
    [[ $# -eq 0 ]] && return 1 ||:

    local id
    for id in "$@"
    do
        [[ -z $id ]] && return 1 ||:
        [[ ! $id =~ ^/ ]] && id="/$id" ||:
        [[ $_LF${_ZETOPT_PARSED-} =~ $_LF$id && ! $_LF${_ZETOPT_PARSED-} =~ $_LF${id}[+/]?:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:0 ]] && continue ||:
        return 1
    done
    return 0
}

# isvalid(): Check if the option is set and its status is OK
# def.) _zetopt::data::isvalid {ID} [1D-KEY...]
# e.g.) _zetopt::data::isvalid /foo @
# STDOUT: NONE
_zetopt::data::isvalid()
{
    if [[ -z ${_ZETOPT_PARSED:-} || -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id" ||:
    if ! _zetopt::def::exists "$id"; then
        return 1
    fi
    if [[ $_LF$_ZETOPT_PARSED =~ $_LF${id}[+/]?:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:0 ]]; then
        return 1
    fi

    shift
    local status_list="$(_zetopt::data::output $ZETOPT_DATAID_STATUS "$id" "$@")"
    if [[ -z $status_list ]]; then
        return 1
    fi
    [[ ! $status_list =~ [^$ZETOPT_STATUS_NORMAL$ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS$ZETOPT_STATUS_MISSING_OPTIONAL_ARGS\ ] ]]
}

# pickup(): Pick up from space/comma separated values with 1D/2D-key
# def.) _zetopt::data::pickup {SPACE/COMMA-SEPARATED-VALUES} [1D/2D-KEY...]
# e.g.) _zetopt::data::pickup "0 1 2 3, 4 5 6" 0 @ 0:1 0:@ 1:@ 0:1,-1
# STDOUT: integers separated with spaces
_zetopt::data::pickup()
{
    local IFS=, lists
    lists=(${1-})
    if [[ ${#lists[@]} -eq 0 ]]; then
        return 1
    fi
    shift 1
    
    local output_list
    output_list=()
    local lists_last_idx="$((${#lists[@]} - 1))"
    
    IFS=' '
    if [[ $# -eq 0 ]]; then
        output_list=(${lists[$lists_last_idx]})
    else
        local list_last_vals
        list_last_vals=(${lists[$lists_last_idx]})
        local val_lastlist_lastidx=$((${#list_last_vals[@]} - 1))

        local input_idx= tmp_list
        for input_idx in "$@"
        do
            if [[ ! $input_idx =~ ^(@|([$\^0]|-?[1-9][0-9]*)?(,([$\^0]|-?[1-9][0-9]*)?)?)?(:?(@|(([$\^0]|-?[1-9][0-9]*)?(,([$\^0]|-?[1-9][0-9]*)?)?)?)?)?$ ]]; then
                _zetopt::msg::script_error "Bad Key:" "$input_idx"
                return 1
            fi

            # shortcuts for improving performance
            # @ / 0,$ / ^,$
            if [[ $input_idx =~ ^(@|[0\^],[\$${val_lastlist_lastidx}])$ ]]; then
                output_list+=(${list_last_vals[@]})
                continue
            # @:@ / ^,$:@ / 0,$:@ / @:^,$ / @:0,$ / 0,$:0,$ / 0,$:^,$
            elif [[ $input_idx =~ ^(@|\^,\$|0,\$):(@|\^,\$|0,\$)$ ]]; then
                output_list+=(${lists[*]})
                continue
            fi

            # split the two-dimensional key string
            local tmp_list_idx= tmp_val_idx=
            if [[ $input_idx =~ : ]]; then
                tmp_list_idx="${input_idx%%:*}"
                tmp_val_idx="${input_idx#*:}"
            else
                tmp_list_idx=$lists_last_idx
                tmp_val_idx=$input_idx
            fi

            # split the list key range string
            local tmp_list_start_idx= tmp_list_end_idx=
            if [[ $tmp_list_idx =~ , ]]; then
                tmp_list_start_idx="${tmp_list_idx%%,*}"
                tmp_list_end_idx="${tmp_list_idx#*,}"
                tmp_list_start_idx=${tmp_list_start_idx:-^}
                tmp_list_end_idx="${tmp_list_end_idx:-$}"
            else
                tmp_list_start_idx=$tmp_list_idx
                tmp_list_end_idx=$tmp_list_idx
            fi

            # determine the list start/end index
            local list_start_idx= list_end_idx=
            case "$tmp_list_start_idx" in
                @)      list_start_idx=0;;
                ^)      list_start_idx=0;;
                $|"")   list_start_idx=$lists_last_idx;;
                *)      list_start_idx=$tmp_list_start_idx;;
            esac
            case "$tmp_list_end_idx" in
                @)      list_end_idx=$lists_last_idx;;
                ^)      list_end_idx=0;;
                $|"")   list_end_idx=$lists_last_idx;;
                *)      list_end_idx=$tmp_list_end_idx
            esac

            # convert negative indexes to positive ones
            if [[ $list_start_idx =~ ^- ]]; then
                list_start_idx=$((lists_last_idx - (list_start_idx * -1 - 1)))
            fi
            if [[ $list_end_idx =~ ^- ]]; then
                list_end_idx=$((lists_last_idx - (list_end_idx * -1 - 1)))
            fi
            
            # check the range
            if [[ $list_start_idx -lt 0 || $list_end_idx -gt $lists_last_idx
                || $list_end_idx -lt 0 || $list_start_idx -gt $lists_last_idx
            ]]; then
                [[ $list_start_idx == $list_end_idx ]] \
                && local translated_idx=$list_start_idx \
                || local translated_idx=$list_start_idx~$list_end_idx
                _zetopt::msg::script_error "List Index Out of Range (0~$lists_last_idx)" "Translate \"$tmp_list_idx\" -> $translated_idx"
                return 1
            fi

            # split the value index range string
            local tmp_val_start_idx= tmp_val_end_idx=
            if [[ $tmp_val_idx =~ , ]]; then
                tmp_val_start_idx="${tmp_val_idx%%,*}"
                tmp_val_end_idx="${tmp_val_idx#*,}"
                tmp_val_start_idx="${tmp_val_start_idx:-^}"
                tmp_val_end_idx="${tmp_val_end_idx:-$}"
            else
                tmp_val_start_idx=$tmp_val_idx
                tmp_val_end_idx=$tmp_val_idx
            fi

            case "$tmp_val_start_idx" in
                @)      tmp_val_start_idx=0;;
                ^)      tmp_val_start_idx=0;;
                $|"")   tmp_val_start_idx=$;; # the last index will be determined later
                *)      tmp_val_start_idx=$tmp_val_start_idx;;
            esac
            case "$tmp_val_end_idx" in
                @)      tmp_val_end_idx=$;; # the last index will be determined later
                ^)      tmp_val_end_idx=0;;
                $|"")   tmp_val_end_idx=$;; # the last index will be determined later
                *)      tmp_val_end_idx=$tmp_val_end_idx
            esac

            local list_idx= val_idx= maxidx= val_start_idx= val_end_idx=
            tmp_list=()
            for list_idx in $(eval "echo {$list_start_idx..$list_end_idx}")
            do 
                tmp_list=(${lists[$list_idx]})
                if [[ ${#tmp_list[@]} -eq 0 ]]; then
                    continue
                fi
                
                # determine the value start/end index
                maxidx=$((${#tmp_list[@]} - 1))
                if [[ $tmp_val_start_idx == $ ]]; then
                    val_start_idx=$maxidx  # set the last index
                else
                    val_start_idx=$tmp_val_start_idx
                fi
                if [[ $tmp_val_end_idx == $ ]]; then
                    val_end_idx=$maxidx    # set the last index
                else
                    val_end_idx=$tmp_val_end_idx
                fi

                # convert negative indexes to positive
                if [[ $val_start_idx =~ ^- ]]; then
                    val_start_idx=$((maxidx - (val_start_idx * -1 - 1)))
                fi
                if [[ $val_end_idx =~ ^- ]]; then
                    val_end_idx=$((maxidx - (val_end_idx * -1 - 1)))
                fi

                # check the range
                if [[ $val_start_idx -lt 0 || $val_end_idx -gt $maxidx
                    || $val_end_idx -lt 0 || $val_start_idx -gt $maxidx
                ]]; then
                    [[ $val_start_idx == $val_end_idx ]] \
                    && local translated_idx=$val_start_idx \
                    || local translated_idx=$val_start_idx~$val_end_idx
                    _zetopt::msg::script_error "Value Index Out of Range (0~$maxidx):" "Translate \"$tmp_val_idx\" -> $translated_idx"
                    return 1
                fi

                for val_idx in $(eval "echo {$val_start_idx..$val_end_idx}")
                do
                    output_list+=(${tmp_list[$val_idx]})
                done
            done
        done
    fi
    printf -- "%s\n" "${output_list[*]}"
}


# hasarg(): Check if the target has arg
# def.) _zetopt::data:hasarg {ID} [1D-KEY...]
# e.g.) _zetopt::data::hasarg /foo 0
# STDOUT: NONE
_zetopt::data::hasarg()
{
    local argc_str="$(_zetopt::data::output $ZETOPT_DATAID_ARGC "$@")"
    [[ -n "$argc_str" && ! "$argc_str" =~ ^[0\ ]+$ ]]
}


# print(): Print field data with keys.
# -a/-v enables to store data in user specified array/variable.
# def.) _zetopt::data::output {FIELD_NUMBER} {ID} [1D/2D-KEY...] [-a,--array <ARRAY_NAME> | -v,--variable <VARIABLE_NAME>] [-I,--IFS <IFS_VALUE>]
# e.g.) _zetopt::data::output $ZETOPT_DATAID_ARGV /foo @:@ --array myarr
# STDOUT: data option names separated with $ZETOPT_CFG_VALUE_IFS or --IFS value
_zetopt::data::output()
{
    if [[ $# -eq 0 ]]; then
        return 1
    fi
    local IFS=' '
    local __dataid__=$1
    shift
    local __out_mode__=stdout __usrvar_name__= __newline__=$_LF __fallback__=true
    local __args__ __ifs__=${ZETOPT_CFG_VALUE_IFS- }
    __args__=()

    while [[ $# -ne 0 ]]
    do
        case "$1" in
            -a | --array)
                __out_mode__=array
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-a, --array <ARRAY_NAME>"
                    return 1
                fi
                __usrvar_name__=$1
                shift
                ;;
            -v | --variable)
                __out_mode__=variable
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-v, --variable <VARIABLE_NAME>"
                    return 1
                fi
                __usrvar_name__=$1
                shift
                ;;
            -I | --IFS)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-I, --IFS <IFS_VALUE>"
                    return 1
                fi
                __ifs__=$1
                shift
                ;;
            -E | --extra) __dataid__=$ZETOPT_DATAID_EXTRA_ARGV; shift;;
            -N | --no-fallback) __fallback__=false; shift;;
            -n | --no-newline) __newline__=; shift;;
            --) shift; __args__+=("$@"); break;;
            --*|-[a-zA-Z])
                _zetopt::msg::script_error "Undefined Option:" "$1"
                return 1;;
            *)  __args__+=("$1"); shift;;
        esac
    done

    # check the user defined variable name before eval to avoid invalid characters and overwriting local variables
    local __usrvar_names__=
    __usrvar_names__=()
    if [[ $__out_mode__ =~ ^(array|variable)$ ]]; then
        IFS=,
        set -- $__usrvar_name__
        IFS=' '
        if [[ $__out_mode__ == array && $# -gt 1 ]]; then
            _zetopt::msg::script_error "Multiple variables cannot be given in array mode:" "$__usrvar_name__"
            return 1
        fi

        local __tmp_varname__
        for __tmp_varname__ in $@
        do
            [[ -z $__tmp_varname__ ]] && continue ||:
            if [[ ! $__tmp_varname__ =~ ^$_REG_VARNAME$ ]] || [[ $__tmp_varname__ =~ ((^_$)|(^__[a-zA-Z0-9][a-zA-Z0-9_]*__$)) ]]; then
                _zetopt::msg::script_error "Invalid Variable Name:" "$__tmp_varname__"
                return 1
            fi
        done
        __usrvar_names__=($@)
    fi

    local __id__="${__args__[0]=$ZETOPT_LAST_COMMAND}"
    if ! _zetopt::def::exists "$__id__"; then
        # complement ID if the first arg looks a key
        if [[ ! $__id__ =~ ^(/([a-zA-Z0-9_]+)?|^(/[a-zA-Z0-9_]+(-[a-zA-Z0-9_]+)*)+/([a-zA-Z0-9_]+)?)$ && $__id__ =~ [@,\^\$\-\:] ]]; then
            __id__=$ZETOPT_LAST_COMMAND
        else
            _zetopt::msg::script_error "No Such ID:" "$__id__" 
            return 1
        fi
    fi
    [[ ! $__id__ =~ ^/ ]] && __id__="/$__id__" ||:

    if [[ ! $__dataid__ =~ ^[$ZETOPT_DATAID_ARGV-$ZETOPT_DATAID_DEFAULT]$ ]]; then
        _zetopt::msg::script_error "Invalid Data ID:" "$__dataid__" 
        return 1
    fi

    local __data__
    __data__=($(_zetopt::data::field "$__id__" $__dataid__))

    # argv fallback default
    if [[ $__dataid__ == $ZETOPT_DATAID_ARGV && $__fallback__ == true ]]; then
        local __default_data__
        __default_data__=($(_zetopt::def::default $__id__))

        # merge parsed data with default data if parsed is short
        local __data_len__=${#__data__[@]}
        if [[ $__data_len__ -lt ${#__default_data__[@]} ]]; then
            if [[ $__data_len__ -ne 0 ]]; then
                __data__=($(echo "${__data__[@]}" "${__default_data__[@]:$__data_len__:$((${#__default_data__[@]} - $__data_len__))}"))
            else
                __data__=($(echo "${__default_data__[@]}"))
            fi
        fi
    fi

    if [[ -z ${__data__[*]-} ]]; then
        _zetopt::msg::script_error "No Data"
        return 1
    fi

    # complement pickup-key
    local __keys__="${__args__[@]:1}"
    if [[ -z $__keys__ ]]; then
        [[ $__dataid__ =~ ^($ZETOPT_DATAID_ARGV|$ZETOPT_DATAID_EXTRA_ARGV|$ZETOPT_DATAID_DEFAULT)$ ]] \
        && __keys__=@ \
        || __keys__=$
    fi

    # translate param names in key to the numeric index
    __keys__=$(_zetopt::def::keyparams2idx $__id__ "$__keys__")

    # pickup data with pickup-keys
    local __list_str__="$(_zetopt::data::pickup "${__data__[*]}" $__keys__)"
    if [[ -z "$__list_str__" ]]; then
        return 1
    fi

    # output
    IFS=' '
    set -- $__list_str__
    declare -i __idx__= __i__=0 __max__=$(($# - 1))
    declare -i __vi__=0 __vmax__=$((${#__usrvar_names__[@]} - 1))
    local __varname__= __nl__=

    if [[ $__out_mode__ == array ]]; then
        __varname__=${__usrvar_names__[0]}
        eval "$__varname__=()"
    fi

    # indexes to refer target data in array
    local __refmode__=$([[ $__dataid__ =~ ^($ZETOPT_DATAID_ARGV|$ZETOPT_DATAID_PSEUDO|$ZETOPT_DATAID_EXTRA_ARGV|$ZETOPT_DATAID_DEFAULT)$ ]] && echo true || echo false)
    for __idx__ in "$@"
    do
        case $__out_mode__ in
        stdout)
            if [[ $__i__ -eq $__max__ ]]; then
                __ifs__= __nl__=$__newline__
            fi
            [[ $__refmode__ == true ]] \
            && printf -- "%s$__ifs__$__nl__" "${_ZETOPT_DATA[$__idx__]}" \
            || printf -- "%s$__ifs__$__nl__" "$__idx__"
            ;;
        array)
            [[ $__refmode__ == true ]] \
            && eval $__varname__'[$__i__]=${_ZETOPT_DATA[$__idx__]}' \
            || eval $__varname__'[$__i__]=$__idx__'
            ;;
        variable)
            if [[ $__vmax__ -ge $__i__ ]]; then
                __varname__=${__usrvar_names__[$__vi__]}
                __vi__+=1
                [[ $__refmode__ == true ]] \
                && eval $__varname__'=${_ZETOPT_DATA[$__idx__]}' \
                || eval $__varname__'=$__idx__'
            else
                [[ $__refmode__ == true ]] \
                && eval $__varname__'+=$__ifs__${_ZETOPT_DATA[$__idx__]}' \
                || eval $__varname__'+=$__ifs__$__idx__'
            fi
            ;;
        esac
        __i__+=1
    done
    if [[ $__out_mode__ == variable ]]; then
        for (( ; $__vmax__ >= $__vi__; __vi__++ ))
        do
            __varname__=${__usrvar_names__[$__vi__]}
            eval $__varname__'=$ZETOPT_CFG_ARG_DEFAULT'
        done
    fi
}


_zetopt::data::iterate()
{
    local __args__ __action__=next __dataid__=$ZETOPT_DATAID_ARGV
    local __usrvar_value__= __usrvar_index__= __usrvar_last_index__= __usrvar_array__= __usrvar_count__=
    local __itr_id__= __null_value__=NULL __null_index__=NULL __user_array__= __no_fallback_option__=
    __args__=()
    while [[ $# -ne 0 ]]
    do
        case "$1" in
            -v | --value)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-v, --value <VARIABLE_NAME_FOR_VALUE,...>"
                    return 1
                fi
                __usrvar_value__=$1
                shift;;
            -i | --index)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-i, --index <VARIABLE_NAME_FOR_KEY,...>"
                    return 1
                fi
                __usrvar_index__=$1
                shift;;
            -l | --last-index)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-l, --last-index <VARIABLE_NAME_FOR_LAST_KEY>"
                    return 1
                fi
                __usrvar_last_index__=$1
                shift;;
            -a | --array)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-a, --array <VARIABLE_NAME_FOR_ARRAY>"
                    return 1
                fi
                __usrvar_array__=$1
                shift;;
            -c | --count)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-c, --count <VARIABLE_NAME_FOR_COUNT>"
                    return 1
                fi
                __usrvar_count__=$1
                shift;;
            --nv | --null-value)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-nv, --null-value <NULL_VALUE>"
                    return 1
                fi
                __null_value__=$1
                shift;;
            --ni | --null-index)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "--ni, --null-index <NULL_INDEX>"
                    return 1
                fi
                __null_index__=$1
                shift;;
            -A | --with-array)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-A, --with-array <ARRAY_NAME>"
                    return 1
                fi
                __user_array__=$1
                shift;;
            --id)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "--id <ITERATOR_ID>"
                    return 1
                fi
                __itr_id__=_$1
                shift;;
            --init | --reset | --unset | --has-next)
                __action__=${1#--}
                shift;;
            -E | --extra | --extra-argv)
                __dataid__=$ZETOPT_DATAID_EXTRA_ARGV
                shift;;
            -N | --no-fallback) __no_fallback_option__=--no-fallback
                shift;;
            --* | -[a-zA-Z])
                _zetopt::msg::script_error "Undefined Option:" "$1"
                return 1;;
            --) shift; __args__+=("$@"); break;;
            *)  __args__+=("$1"); shift;;
        esac
    done

    local __id__= __complemented_id__=

    # ID for user specified array
    if [[ -n $__user_array__ ]]; then
        if [[ ! $__user_array__ =~ $_REG_VARNAME ]]; then
            _zetopt::msg::script_error "Invalid Variable Name:" "$__user_array__"
            return 1
        fi
        if [[ ! -n $(eval 'echo ${'$__user_array__'+x}') ]]; then
            _zetopt::msg::script_error "No Such Variable:" "$__user_array__"
            return 1
        fi
        __id__=$__user_array__

    # ID for getting parsed data array
    else
        __id__="${__args__[0]=${ZETOPT_LAST_COMMAND}}"
        if ! _zetopt::def::exists "$__id__"; then
            # complement ID if the first arg looks a key
            if [[ ! $__id__ =~ ^(/([a-zA-Z0-9_]+)?|^(/[a-zA-Z0-9_]+(-[a-zA-Z0-9_]+)*)+/([a-zA-Z0-9_]+)?)$ && $__id__ =~ [@,\^\$\-\:] ]]; then
                __id__=$ZETOPT_LAST_COMMAND
                __complemented_id__=$ZETOPT_LAST_COMMAND
            else
                _zetopt::msg::script_error "No Such ID:" "$__id__" 
                return 1
            fi
        fi
        [[ ! $__id__ =~ ^/ ]] && __id__="/$__id__" ||:
    fi

    # build variable names based on ID, KEY or --id <ITERATOR_ID>
    local __var_id_suffix__
    if [[ -n $__itr_id__ ]]; then
        if [[ ! $__itr_id__ =~ ^[a-zA-Z0-9_]+$ ]]; then
            _zetopt::msg::script_error "Invalid Iterator ID:" "$__itr_id__"
            return 1
        fi
        __var_id_suffix__=$__itr_id__
    else
        # replace invalid chars for variable name
        __var_id_suffix__="$__id__${__args__[@]}"
        __var_id_suffix__=${__var_id_suffix__//\ /_20}
        __var_id_suffix__=${__var_id_suffix__//\$/_24}
        __var_id_suffix__=${__var_id_suffix__//\,/_2C}
        __var_id_suffix__=${__var_id_suffix__//\:/_3A}
        __var_id_suffix__=${__var_id_suffix__//\@/_40}
        __var_id_suffix__=${__var_id_suffix__//\^/_5E}
    fi
    __var_id_suffix__=${__var_id_suffix__//[\/\-]/_}
    __var_id_suffix__=${__var_id_suffix__//[!a-zA-Z0-9_]/}
    local __intlvar_array__=_zetopt_iterator_array_$__var_id_suffix__
    local __intlvar_index__=_zetopt_iterator_index_$__var_id_suffix__
    local __intlvar_iterated__=_zetopt_iterator_iterated_$__var_id_suffix__

    # already exists ?
    local __intlvar_exists__="$( [[ -n $(eval 'echo ${'$__intlvar_array__'+x}') || -n $(eval 'echo ${'$__intlvar_index__'+x}') ]] && echo true || echo false)"

    case $__action__ in
        # --reset resets index
        reset)
            if [[ $__intlvar_exists__ == true ]]; then
                eval $__intlvar_index__'=0'
                eval $__intlvar_iterated__'=false'
                return 0
            fi
            return 1;;

        # --unset unsets array and index
        unset)
            unset $__intlvar_array__ ||:
            unset $__intlvar_index__ ||:
            unset $__intlvar_iterated__ ||:
            return 0;;

        # --has-next checks next item existence
        has-next)
            if [[ $__intlvar_exists__ == false ]]; then
                return 1
            fi
            local __increment__="$([[ $(eval 'echo $'$__intlvar_iterated__) == true ]] && echo 1 || echo 0)"
            local __max_idx__="$(eval 'echo $((${#'$__intlvar_array__'[@]} - 1))')"
            if [[ $(($(eval 'echo $'$__intlvar_index__) + $__increment__)) -gt $__max_idx__ ]]; then
                return 1
            else
                return 0
            fi
            ;;
    esac
    
    # check the user defined variable name before eval to avoid invalid characters and overwriting local variables
    local IFS=,
    set -- $__usrvar_value__ $__usrvar_index__ $__usrvar_last_index__ $__usrvar_array__ $__usrvar_count__
    for __tmp_varname__ in $@
    do
        [[ -z $__tmp_varname__ ]] && continue ||:
        if [[ ! $__tmp_varname__ =~ ^$_REG_VARNAME$ ]] || [[ $__tmp_varname__ =~ ((^_$)|(^__[a-zA-Z0-9][a-zA-Z0-9_]*__$)|(^IFS$)) ]]; then
            _zetopt::msg::script_error "Invalid Variable Name:" "$__tmp_varname__"
            return 1
        fi
    done
    local __usrvar_value_names__ __usrvar_index_names__
    __usrvar_value_names__=($__usrvar_value__)
    __usrvar_index_names__=($__usrvar_index__)
    if [[ (-n $__usrvar_value__ && -n $__usrvar_index__) && (${#__usrvar_value_names__[@]} -ne ${#__usrvar_index_names__[@]}) ]]; then
        _zetopt::msg::script_error "Number of Variables Mismatch:" "--value=$__usrvar_value__ --index=$__usrvar_index__"
        return 1
    fi
    IFS=' '

    # initialize
    if [[ $__intlvar_exists__ == false || $__action__ == init ]]; then
        # use user specified array
        if [[ -n $__user_array__ ]]; then
            if [[ -n ${__args__[@]-} && ! "${__args__[*]}" =~ [0-9,:$^\ ] ]]; then
                _zetopt::msg::script_error "Invalid Access Key:" "${__args__[*]}"
                return 1
            fi
            local __end__=$(($(eval 'echo ${#'$__user_array__'[@]}') - 1))
            local __list_str__="$(_zetopt::data::pickup "$(eval 'echo {0..'$__end__'}')" "${__args__[@]}")"
            if [[ -z "$__list_str__" ]]; then
                return 1
            fi
            declare -i __idx__= __i__=0
            eval $__intlvar_index__'=0'
            eval $__intlvar_array__'=()'
            eval $__intlvar_iterated__'=false'
            set -- $__list_str__
            for __idx__ in "$@"
            do
                eval $__intlvar_array__'[$__i__]=${'$__user_array__'[$__idx__]}'
                __i__+=1
            done

        # use parsed data array
        else
            if _zetopt::data::output $__dataid__ $__complemented_id__ "${__args__[@]}" -a $__intlvar_array__ $__no_fallback_option__; then
                eval $__intlvar_index__'=0'
                eval $__intlvar_iterated__'=false'

            # unset and return error if failed
            else
                unset $__intlvar_array__ ||:
                unset $__intlvar_index__ ||:
                unset $__intlvar_iterated__ ||:
                return 1
            fi
        fi

        # init returns at this point
        if [[ $__action__ == init ]]; then
            return 0
        fi
    fi
    
    # has no next
    local __iterated__="$(eval 'echo $'$__intlvar_iterated__)"
    local __increment__="$([[ $__iterated__ == true ]] && echo 1 || echo 0)"
    local __max_intlvar_idx__=$(eval 'echo $((${#'$__intlvar_array__'[@]} - 1))')
    if [[ -n $__usrvar_value__ && $(($(eval 'echo $'$__intlvar_index__) + $__increment__)) -gt $__max_intlvar_idx__ ]]; then
        unset $__intlvar_array__ ||:
        unset $__intlvar_index__ ||:
        unset $__intlvar_iterated__ ||:
        return 1
    fi

    # last-index / array / count
    [[ -n $__usrvar_last_index__ ]] && eval $__usrvar_last_index__'=$((${#'$__intlvar_array__'[@]} - 1))' ||:
    [[ -n $__usrvar_array__ ]] && eval $__usrvar_array__'=("${'$__intlvar_array__'[@]}")' ||:
    [[ -n $__usrvar_count__ ]] && eval $__usrvar_count__'=${#'$__intlvar_array__'[@]}' ||:

    # value / index : Iterate with multiple values/indexs
    if [[ -n $__usrvar_value__ || -n $__usrvar_index__ ]]; then
        local __idx__= __max_idx__=$([[ -n $__usrvar_value__ ]] && echo ${#__usrvar_value_names__[@]} || echo ${#__usrvar_index_names__[@]})
        for (( __idx__=0; __idx__<__max_idx__; __idx__++ ))
        do
            # value
            if [[ -n $__usrvar_value__ ]]; then
                # increment index only if -v option specified
                if [[ $__iterated__ == true ]]; then
                    eval $__intlvar_index__'=$(($'$__intlvar_index__' + 1))'
                    if [[ $(eval 'echo $'$__intlvar_index__) -gt $__max_intlvar_idx__ ]]; then
                        return 1
                    fi
                else
                    eval $__intlvar_iterated__'=true'
                    __iterated__=true
                fi
                eval ${__usrvar_value_names__[$__idx__]}'="${'$__intlvar_array__'[$'$__intlvar_index__']}"'
            fi

            # index
            if [[ -n $__usrvar_index__ ]]; then
                eval ${__usrvar_index_names__[$__idx__]}'=$'$__intlvar_index__
            fi

        done

        # substitute NULL_VALUE/NULL_KEY if breaking the previous loop because of __intlvar_array__ being short
        for (( __idx__++; __idx__<__max_idx__; __idx__++ ))
        do
            # value
            if [[ -n $__usrvar_value__ ]]; then
                eval ${__usrvar_value_names__[$__idx__]}'=$__null_value__'
            fi

            # key
            if [[ -n $__usrvar_index__ ]]; then
                eval ${__usrvar_index_names__[$__idx__]}'=$__null_index__'
            fi
        done
    fi
    return 0
}

# setids(): Print the list of IDs set
# def.) _zetopt::data::setids
# e.g.) _zetopt::data::setids
# STDOUT: ID string separated with \n
_zetopt::data::setids()
{
    local lines="$_ZETOPT_PARSED"
    while [[ $_LF$lines =~ $_LF([^:]+):[^$_LF]+:[1-9][0-9]*$_LF(.*) ]]
    do
        printf -- "%s\n" "${BASH_REMATCH[1]}"
        lines=${BASH_REMATCH[2]}
    done
}

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
    if ! _zetopt::msg::should_decorate $_FD_STDERR; then
        printf >&2 "%b\n" "$ZETOPT_APPNAME: $title: $text$value"
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
    printf >&2 "\e[${col}m%b\e[0m \e[${textcol}m%b\e[0m \e[${col}m%b\e[0m\n" "$appname: $title:" "$text" "$value"
}

# debug(): Print definition-error message for script programmer
# def.) _zetopt::msg::script_error {MESSAGE} {VALUE}
# e.g.) _zetopt::msg::script_error "Undefined Sub-Command:" "$subcmd"
# STDOUT: NONE
_zetopt::msg::script_error()
{
    if [[ $ZETOPT_CFG_ERRMSG_SCRIPT_ERROR != true ]]; then
        return 0
    fi
    local text="${1-}" value="${2-}"
    local src_lineno=${BASH_LINENO-${funcfiletrace[0]##*:}}
    local appname="${ZETOPT_CFG_ERRMSG_APPNAME-$ZETOPT_APPNAME}"
    local filename="${ZETOPT_SOURCE_FILE_PATH##*/}"
    local title="Script Error"
    local funcname="$(_zetopt::utils::funcname 1)"
    local col="${ZETOPT_CFG_ERRMSG_COL_SCRIPTERR:-"0;1;31"}"
    local textcol="${ZETOPT_CFG_ERRMSG_COL_DEFAULT:-"0;0;39"}"
    local before=2 after=2
    local IFS=$_LF
    if [[ $ZETOPT_CFG_ERRMSG_STACKTRACE == true ]]; then
        local stack=($(_zetopt::utils::stack_trace))
        local caller_info="${stack[$((${#stack[@]} - 1))]}"
        [[ $caller_info =~ \(([0-9]+)\).?$ ]] \
        && local caller_lineno=${BASH_REMATCH[1]} \
        || local caller_lineno=0
    fi
    {
        printf "\e[${col}m%b\e[0m\n" "$appname: $title: $filename: $funcname ($src_lineno)"
        printf -- " %b %b\n" "$text" "$value"
        if [[ $ZETOPT_CFG_ERRMSG_STACKTRACE == true ]]; then
            printf -- "\n\e[1;${col}mStack Trace:\e[m\n"
            printf -- " -> %b\n" ${stack[@]}
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
        && setopt localoptions NOCASEMATCH \
        || shopt -s nocasematch
        if [[ $colmode == auto ]]; then
            if [[ $fd == $_FD_STDOUT ]]; then
                echo $_TTY_STDOUT
            elif [[ $fd == $_FD_STDERR ]]; then
                echo $_TTY_STDERR
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


#------------------------------------------------------------
# _zetopt::utils
#------------------------------------------------------------
_zetopt::utils::interface()
{
    if [[ -z ${@-} ]]; then
        _zetopt::msg::script_error "No Argument:" "_zetopt::utils::interface <UTIL_NAME> [<ARGS>]"
        return 1
    fi
    local funcname=$1
    shift
    case $funcname in
        funcname)       _zetopt::utils::funcname "$@";;
        stack_trace)    _zetopt::utils::stack_trace "$@";;
        viewfile)       _zetopt::utils::viewfile "$@";;
        repeat)         _zetopt::utils::repeat "$@";;
        seq)            _zetopt::utils::seq "$@";;
        isLangCJK)      _zetopt::utils::isLangCJK "$@";;
        fold)           _zetopt::utils::fold "$@";;
        undecorate)     _zetopt::utils::undecorate "$@";;
        quote)          _zetopt::utils::quote "$@";;
        max)            _zetopt::utils::max "$@";;
        min)            _zetopt::utils::min "$@";;
        lowercase)      _zetopt::utils::lowercase "$@";;
        uppercase)      _zetopt::utils::uppercase "$@";;
        abspath)        _zetopt::utils::abspath "$@";;
        *)  _zetopt::msg::script_error "utils:" "funcname stack_trace viewfile repeat seq isLangCJK fold undecorate quote max min lowercase abspath"
            return 1;;
    esac
}

_zetopt::utils::funcname()
{
    local skip_stack_count=0
    if [[ -n ${1-} ]]; then
        skip_stack_count=$1
    fi

    if [[ -n ${BASH_VERSION-} ]]; then
        printf -- "%s" "${FUNCNAME[$((1 + $skip_stack_count))]}"
    elif [[ -n ${ZSH_VERSION-} ]]; then
        printf -- "%s" "${funcstack[$((1 + $skip_stack_count))]}"
    fi
}

_zetopt::utils::stack_trace()
{
    local IFS=" "
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
        setopt localoptions KSH_ARRAYS
        funcs=("${funcstack[@]:$funcs_start_idx}" "$ZETOPT_CALLER_NAME")
        lines=("${funcfiletrace[@]:$lines_start_idx}")
        lines=("${lines[@]##*:}")
    fi
    for ((i=0; i<${#funcs[@]}; i++))
    do
        printf -- "%s (%s)\n" "${funcs[$i]}" "${lines[$i]}"
    done
}

_zetopt::utils::viewfile()
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

_zetopt::utils::repeat()
{
    if [[ $# -ne 2 || ! $1 =~ ^[1-9][0-9]*$ ]]; then
        _zetopt::msg::script_error "Invalid Argument:" "_zetopt::utils::repeat <REPEAT_COUNT> <STRING>"
        return 1
    fi
    local IFS=" "
    local repstr="${2//\//\\/}"
    printf -- "%0*d" $1 | \sed -e "s/0/$repstr/g"
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
        _zetopt::msg::script_error "_zetopt::utils::seq <START> <END> [-d,--delimiter <DELIMITER>]"
        return 1
    fi

    if [[ ! $start =~ ^([a-zA-Z]|-?[0-9]+)$ ]] || [[ ! $end =~ ^([a-zA-Z]|-?[0-9]+)$ ]]; then
        _zetopt::msg::script_error "Accepts:" "^([a-zA-Z]|-?[0-9]+)$"
        return 1
    fi

    if [[ $custom_delim == true ]]; then
        eval "echo {$start..$end}" | \sed -e "s/ /$delim/g"
    else
        eval "echo {$start..$end}"
    fi
}

_zetopt::utils::isLangCJK()
{
    return $(
        [[ -n ${ZSH_VERSION-} ]] \
        && setopt localoptions NOCASEMATCH \
        || shopt -s nocasematch
        [[ ${1-} =~ ^(zh_|ja_|ko_) ]] && echo 0 || echo 1
    )
}

_zetopt::utils::fold()
{
    local lang="${_LC_ALL:-${_LANG:-en_US.UTF-8}}" indent_str=" "
    declare -i width=80 min_width=4 indent_cnt=0 tab_cnt=4
    local error=false tab_spaces= hyphenate=true
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
            --no-hyphenate)
                hyphenate=false
                shift;;
            --) shift; break;;
            *)  shift; error=true; break;;
        esac
    done
    if [[ $error == true ]]; then
        _zetopt::msg::script_error "Usage:" "echo \"\$str\" | _zetopt::utils::fold [-w|--width <WIDTH>] [-l|--lang <LANG>] [-i|--indent <INDENT_COUNT>] [--indent-string <INDENT_STRING>] [-t|--tab <SPACES_COUNT>]"
        return 1
    fi

    local LC_ALL=
    local LANG=en_US.UTF-8
    local isLangCJK=$(_zetopt::utils::isLangCJK "$lang" && echo true || echo false)
    declare -i wide_char_width=$($isLangCJK && echo 2 || echo 1)
    declare -i max_buff_size=$width-$($isLangCJK && echo 2 || echo 1) # take margin for smart-folding
    declare -i buff_size rest_buff_size curr mbcnt pointer=0 skip
    local IFS=$_LF
    local line tmp_buff buff indent= hyphen
    if [[ $indent_cnt -ne 0 ]]; then
        indent=$(_zetopt::utils::repeat $indent_cnt "$indent_str")
    fi

    tab_spaces=$(printf "%${tab_cnt}s" " ")

    while <&0 read -r line || [[ -n $line ]]
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
            rest_buff_size=$rest_buff_size-$mbcnt*$wide_char_width-${#ascii}
            pointer+=$curr_buff_size
            if [[ $pointer -le $line_len && $rest_buff_size -ge 2 ]]; then
                continue
            fi
            
            if $isLangCJK && [[ $rest_buff_size -le 1 ]]; then
                if [[ ${line:$pointer:$rest_buff_size+1} =~ ^[\ -\~]+$ ]]; then
                    pointer=$pointer+$rest_buff_size+1
                fi
            fi

            # smart-folding
            skip=0
            hyphen=
            if [[ $rest_buff_size -le 1 ]]; then
                if [[ ${line:$pointer:1} =~ [.,\ 。、，　\!-/:-@\[-\`\{-\~] ]]; then
                    pointer+=1
                elif [[ ${line:$pointer-2:1} =~ [.,\ 。　] ]]; then
                    pointer=$pointer-1
                elif [[ ${line:$pointer+1:1} =~ [.,\ 。　] ]]; then
                    pointer+=1
                    skip+=1
                elif [[ ${line:$pointer-1:1} =~ [.,\ 。　] ]]; then
                    pointer=$pointer-1
                    skip+=1
                elif [[ ${line:$pointer-1:2} =~ ^[a-zA-Z]{2,2}$ ]]; then
                    $hyphenate \
                        && hyphen=- \
                        || pointer+=1
                else
                    pointer+=1
                fi
            fi

            total_buff_size=$pointer-$curr
            buff=${line:$curr:$total_buff_size}
            printf -- "%s\n" "$indent$buff$hyphen"

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
    local IFS=" "
    printf -- "%s\n" "${arr[*]}"
}

_zetopt::utils::max()
{
    if [[ $# -ne 2 ]]; then
        return 1
    fi
    [[ $1 -ge $2 ]] \
    && printf -- "%s\n" "$1" \
    || printf -- "%s\n" "$2"
}

_zetopt::utils::min()
{
    if [[ $# -ne 2 ]]; then
        return 1
    fi
    [[ $1 -le $2 ]] \
    && printf -- "%s\n" "$1" \
    || printf -- "%s\n" "$2"
}

_zetopt::utils::lowercase()
{
    if [[ $# -eq 0 ]]; then
        return 0
    fi

    # bash4
    if $ZETOPT_BASH && ! $ZETOPT_OLDBASH; then
        printf -- "%s" "${1,,}"
        return 0
    fi
    
    # zsh
    if $ZETOPT_ZSH; then
        printf -- "%s" "${1:l}"
        return 0
    fi

    # bash3
    declare -i len=${#1}

    # use tr if it's long
    if [[ $len -ge 50 ]]; then
        <<< "$1" tr '[A-Z]' '[a-z]'
        return 0
    fi

    declare -i idx ascii_code
    local char
    for (( idx=0; idx<len; idx++ ))
    do
        char=${1:$idx:1}
        case "$char" in
            [A-Z])
                ascii_code=$(printf -- "%d" "'$char")
                ascii_code+=32
                printf -- "%b" "$(printf -- "\\%o" $ascii_code)"
                ;;
            *) printf -- "%s" "$char";;
        esac
    done
}

_zetopt::utils::uppercase()
{
    if [[ $# -eq 0 ]]; then
        return 0
    fi

    # bash4
    if $ZETOPT_BASH && ! $ZETOPT_OLDBASH; then
        printf -- "%s" "${1^^}"
        return 0
    fi
    
    # zsh
    if $ZETOPT_ZSH; then
        printf -- "%s" "${1:u}"
        return 0
    fi

    # bash3
    declare -i len=${#1}

    # use tr if it's long
    if [[ $len -ge 50 ]]; then
        <<< "$1" tr '[a-z]' '[A-Z]'
        return 0
    fi

    declare -i idx ascii_code
    local char
    for (( idx=0; idx<len; idx++ ))
    do
        char=${1:$idx:1}
        case "$char" in
            [a-z])
                ascii_code=$(printf -- "%d" "'$char")
                ascii_code=$((ascii_code - 32))
                printf -- "%b" $(printf -- "\\%o" $ascii_code)
                ;;
            *) printf -- "%s" "$char";;
        esac
    done
}

_zetopt::utils::abspath()
{
    [[ -z ${1-} ]] && return 1

    local abs_path="/" rel_path
    [[ "$1" =~ ^/ ]] && rel_path="$1" || rel_path="$PWD/$1"

    local IFS="/" comp
    for comp in $rel_path
    do
        case "$comp" in
            '.' | '') continue;;
            '..')     abs_path=$(\dirname -- "$abs_path");;
            *)        [[ $abs_path == / ]] && abs_path="/$comp" || abs_path="$abs_path/$comp";;
        esac
    done
    \printf -- "%s\n" "$abs_path"
}

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
    declare -i _MAX_COLS=$(tput cols)
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
            bodyarr=($(printf -- "%b" "$line" | _zetopt::utils::fold --width $cols --lang "$_HELP_LANG" --no-hyphenate))
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
            if [[ $default_idx -ne 0 && -n ${_ZETOPT_DATA[$default_idx]} ]]; then
                default_value="=${_ZETOPT_DATA[$default_idx]}"
            fi
            if [[ $param == @ ]]; then
                optargs+=" <$default_argname$cnt$default_value>"
            elif [[ $param == % ]]; then
                optargs+=" [<$default_argname$cnt$default_value>]"
            elif [[ ${param:0:1} == @ ]]; then
                optargs+=" <${param:1}$default_value>"
            elif [[ ${param:0:1} == % ]]; then
                optargs+=" [<${param:1}$default_value>]"
            fi
            cnt+=1
        done
        # variable length
        if [[ $arg =~ ([.]{3,3}[0-9]*)= ]]; then
            if [[ ${param:0:1} == % ]]; then
                optargs="${optargs:0:$((${#optargs} - 1))}${BASH_REMATCH[1]}]"
            else
                optargs="${optargs} [${BASH_REMATCH[1]}]"
            fi
        fi
        IFS=$_LF
    fi
    printf -- "%b" "$optargs"
}


#------------------------------------------------------------
# _zetopt::man
#------------------------------------------------------------
_zetopt::man::show()
{
    if [[ ${1-} == "short" ]]; then
<< __EOHELP__ \cat
NAME
    $ZETOPT_APPNAME -- An option parser for shell scripts
VERSION
    $ZETOPT_VERSION
USAGE
    zetopt {SUB-COMMAND} {ARGS}
OPTIONS
    -v, --version, -h, --help
SUB-COMMANDS
    def def-validator paramidx paramlen default defined
    parse isset setids argv argc type pseudo status count
    hasarg isvalid parsed def-help show-help

Type \`zetopt -h\` to show more help 
__EOHELP__
        return 0
    fi

<< __EOHELP__ \cat
-------------------------------------------------------------
Name        : $ZETOPT_APPNAME -- An option parser for shell scripts
Version     : $ZETOPT_VERSION
License     : MIT License
Author      : itmst71@gmail.com
URL         : https://github.com/itmst71/zetopt
Required    : Bash 3.2+ / Zsh 5.0+, Some POSIX commands
-------------------------------------------------------------
DESCRIPTION
    An option parser for Bash/Zsh scripts.

SYNOPSYS
    $ZETOPT_APPNAME {SUB-COMMAND} {ARGS}

SUB-COMMANDS
    init

    reset
    
    define, def

    def-validator, define-validator

    paramidx, pidx

    paramlen, plen

    parse

    isset

    setids

    argv, value, val

    argc, length, len
    
    type

    pseudo
    
    status

    count

    hasarg, hasval

    isvalid, isok
    
    parsed

    def-help, define-help

    show-help

__EOHELP__
}


