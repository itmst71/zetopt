#------------------------------------------------------------
# Name        : zetopt -- An option parser for shell scripts
# Version     : 1.2.0a (2020-02-04 07:00)
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
readonly ZETOPT_VERSION="1.2.0a (2020-02-04 07:00)"


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
    _ZETOPT_TEMP_ARGV=()
    _ZETOPT_EXTRA_ARGV=()

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


#------------------------------------------------------------
# Main
#------------------------------------------------------------
# zetopt(): Interface for shell script programmer
# def.) zetopt {SUB-COMMAND} [ARGS]
# e.g.) zetopt def ver:v,version
# STDOUT: depending on each sub-commands
zetopt()
{
    declare -r _PATH=$PATH
    declare -r _LC_ALL="${LC_ALL-}" _LANG="${LANG-}"
    local PATH="/usr/bin:/bin"
    local LC_ALL=C LANG=C
    local IFS=$' \t\n'
    declare -r LF=$'\n'
    declare -r INIT_IDX=$ZETOPT_ARRAY_INITIAL_IDX

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

    # sub-commands
    case "$subcmd" in
        # options
        -v | --version)
            \echo $ZETOPT_APPNAME $ZETOPT_VERSION;;
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
        def-validator | define-validator)
            _zetopt::validator::def "$@";;
        paramidx | pidx)
            _zetopt::def::paramidx "$@";;
        paramlen | plen)
            _zetopt::def::paramlen "$@";;
        default)
            _zetopt::def::default "$@";;
        defined)
            _zetopt::def::defined "$@";;

        # parser
        parse)
            _zetopt::parser::parse "$@";;

        # data
        isset)
            _zetopt::data::isset "$@";;
        setids)
            _zetopt::data::setids;;
        argv | value | val)
            _zetopt::data::print $ZETOPT_FIELD_DATA_ARGV "$@";;
        argc | length | len)
            _zetopt::data::print $ZETOPT_FIELD_DATA_ARGC "$@";;
        type)
            _zetopt::data::print $ZETOPT_FIELD_DATA_TYPE "$@";;
        pseudo)
            _zetopt::data::print $ZETOPT_FIELD_DATA_PSEUDO "$@";;
        status)
            _zetopt::data::print $ZETOPT_FIELD_DATA_STATUS "$@";;
        count)
            _zetopt::data::print $ZETOPT_FIELD_DATA_COUNT "$@";;
        hasarg | hasval)
            _zetopt::data::hasarg "$@";;
        isvalid | isok)
            _zetopt::data::isvalid "$@";;
        parsed)
            _zetopt::data::parsed "$@";;
        iterate)
            _zetopt::data::iterate "$@";;

        # help
        def-help | define-help)
            _zetopt::help::define "$@";;
        show-help)
            _zetopt::help::show "$@";;

        *)
            _zetopt::msg::debug "Undefined Sub-Command:" "$subcmd"
            return 1;;
    esac
}



#------------------------------------------------------------
# _zetopt::def
#------------------------------------------------------------

# define(): Define options. 
# ** Must be executed in the current shell **
# def.) _zetopt::def::define {DEFINITION-STRING}
# e.g.) _zetopt::def::define "ver:v:version"
# STDOUT: NONE
_zetopt::def::define()
{
    if [[ -z ${_ZETOPT_DEFINED:-} ]]; then
        _ZETOPT_DEFINED="/:::%.0~0...=0:0 0$LF"
        _ZETOPT_OPTHELPS=("")
        _ZETOPT_DEFAULTS=("")
    fi

    if [[ -z $@ ]]; then
        _zetopt::msg::def_error "No Definition Given"
        return 1
    fi

    if [[ -n $ZETOPT_CFG_VARIABLE_PREFIX && ! $ZETOPT_CFG_VARIABLE_PREFIX =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        _zetopt::msg::def_error "Invalid Variable Prefix:" "ZETOPT_CFG_VARIABLE_PREFIX=$ZETOPT_CFG_VARIABLE_PREFIX"
        return 1
    fi

    local IFS=$' \n\t' args
    declare -i arglen=$#
    args=("$@")
    declare -i idx=$INIT_IDX maxloop=$arglen+$INIT_IDX
    local namespace= id= short= long= namedef= cmdmode=false helpdef= global= helpidx=0 helpidx_cmd=0
    local help_only=false has_param=false

    local arg="${args[$idx]}"
    if [[ $arglen -eq 1 ]]; then
        # param only
        if [[ $arg =~ ^-{0,2}[@%] ]]; then
            namedef=/
            has_param=true
        # help only
        elif [[ $arg =~ ^\# ]]; then
            namedef=/
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
            _zetopt::msg::def_error "Help must be placed in the last argument"
            return 1
        else
            namedef=$arg
            idx+=1
            arg=${args[$idx]}
            if [[ $arg =~ ^-{0,2}[@%] ]]; then
                has_param=true
            elif [[ $arg =~ ^\# ]]; then
                help_only=true
            else
                _zetopt::msg::def_error "Invalid Definition"
                return 1
            fi
        fi
    fi

    arg=${args[$((arglen - 1 + INIT_IDX))]}
    if [[ $arg =~ ^\# ]]; then
        helpdef=${arg###}
        maxloop=$maxloop-1
    fi

    # add an omittable root /
    if [[ ! $namedef =~ ^/ ]]; then
        namedef="/$namedef"
    fi

    # regard as a subcommand
    if [[ ! $namedef =~ : && ! $namedef =~ /$ ]]; then
        namedef="$namedef/"
    fi

    IFS=:
    \set -- $namedef
    IFS=$' \t\n'
    if [[ $# -gt 3 ]]; then
        _zetopt::msg::def_error "Invalid Definition"
        return 1
    fi

    id=${1-}
    namespace=${id%/*}/

    if [[ $id =~ [+]$ ]]; then
        global=+
        id=${id//+/}
    fi

    # can not determine whether it is a subcommand or an option
    if [[ $namedef =~ : && $id =~ /$ ]]; then
        _zetopt::msg::def_error "Invalid Definition"
        return 1
    fi

    if [[ ! $id =~ ^(/([a-zA-Z0-9_]+)?|^(/[a-zA-Z0-9_]+(-[a-zA-Z0-9_]+)*)+/([a-zA-Z0-9_]+)?)$ ]]; then
        _zetopt::msg::def_error "Invalid Identifier:" "$id"
        return 1
    fi

    # define variable for storing the last value
    local var_name var_base_name=${ZETOPT_CFG_VARIABLE_PREFIX}${id:1}
    var_base_name=${var_base_name//[\/\-]/_}
    
    # namespace(subcommand) definition
    if [[ $id == $namespace ]]; then
        cmdmode=true

        if [[ -n $global ]]; then
            _zetopt::msg::def_error "Sub-Command Difinition with Global Option Sign +"
            return 1
        fi

        # command has two help indices for itself and its argument
        helpidx="0 0"

        if [[ $_ZETOPT_DEFINED =~ (^|.*$LF)(($id:[^$LF]+:)([0-9]+)\ ([0-9]+)$LF)(.*) ]]; then
            local head_lines="${BASH_REMATCH[$((1 + $INIT_IDX))]}"
            local tmp_line="${BASH_REMATCH[$((2 + $INIT_IDX))]}"
            local tmp_line_nohelp="${BASH_REMATCH[$((3 + $INIT_IDX))]}"
            helpidx_cmd="${BASH_REMATCH[$((4 + $INIT_IDX))]}"
            local helpidx_cmdarg="${BASH_REMATCH[$((5 + $INIT_IDX))]}"
            local tail_lines="${BASH_REMATCH[$((6 + $INIT_IDX))]}"

            # remove auto defined namespace
            if [[ $tmp_line == "${id}:::%.0~0...=0:0 0$LF" ]]; then
                _ZETOPT_DEFINED="$head_lines$tail_lines"
            
            elif [[ $has_param == true && $tmp_line =~ [@%] ]] || [[ $help_only == true && $tmp_line =~ :[1-9][0-9]*\ [0-9]+$LF$ ]]; then
                _zetopt::msg::def_error "Already Defined:" "$id"
                return 1

            # help only definition: rewrite help reference number part of existing definition
            elif [[ $help_only == true && $tmp_line =~ :0\ ([0-9]+)$LF$ ]]; then
                _ZETOPT_OPTHELPS+=("$helpdef")
                helpidx=$((${#_ZETOPT_OPTHELPS[@]} - 1 + $INIT_IDX))
                _ZETOPT_DEFINED="$head_lines$tmp_line_nohelp$helpidx $helpidx_cmdarg$LF$tail_lines"
                return 0

            # remove help only definition and continue parsing
            else
                _ZETOPT_DEFINED="$head_lines$tail_lines"
            fi
        fi
    fi
    
    if [[ $LF$_ZETOPT_DEFINED =~ $LF${id}[+]?: ]]; then
        _zetopt::msg::def_error "Duplicate Identifier:" "$id"
        return 1
    fi

    # options
    if [[ $namedef =~ : ]]; then
        shift
        IFS=,
        \set -- $*

        while [[ $# -ne 0 ]]
        do
            if [[ -z $1 ]]; then
                shift
                continue
            fi
            
            # short option
            if [[ ${#1} -eq 1 ]]; then
                if [[ -n $short ]]; then
                    _zetopt::msg::def_error "2 Short Options at once:" "$1"
                    return 1
                fi

                if [[ ! $1 =~ ^[a-zA-Z0-9_]$ ]]; then
                    _zetopt::msg::def_error "Invalid Short Option Name:" "$1"
                    return 1
                fi
                
                # subcommand scope option
                if [[ $LF$_ZETOPT_DEFINED =~ $LF${namespace}[a-zA-Z0-9_]*[+]?:$1: ]]; then
                    _zetopt::msg::def_error "Already Defined:" "-$1"
                    return 1
                fi
                short=$1

            # long option
            else
                if [[ -n $long ]]; then
                    _zetopt::msg::def_error "2 Long Options at once:" "$1"
                    return 1
                fi

                if [[ ! $1 =~ ^[a-zA-Z0-9_]+(-[a-zA-Z0-9_]*)*$ ]]; then
                    _zetopt::msg::def_error "Invalid Long Option Name:" "$1"
                    return 1
                fi

                # subcommand scope option
                if [[ $LF$_ZETOPT_DEFINED =~ $LF${namespace}[a-zA-Z0-9_]*[+]?:[^:]?:$1: ]]; then
                    _zetopt::msg::def_error "Already Defined:" "--$1"
                    return 1
                fi
                long=$1
            fi
            shift
        done

        # no short nor long
        if [[ -z $short$long ]]; then
            return 1
        fi
    fi
    
    # parameters
    local param_def=
    if [[ $has_param == true ]]; then
        local param_optional=false param params default_is_set=false
        declare -i param_idx=$INIT_IDX param_default_idx
        local param_validator_idxs param_validator_separator
        local param_hyphens param_type param_name param_varlen param_varlen_max param_default param_names= param_validator= param_validator_name=
        local var_param_name var_param_default var_param_len=$(($maxloop-$idx))
        params=()
        for ((; idx<maxloop; idx++))
        do
            param=${args[$idx]}
            param_default_idx=0
            if [[ ! $param =~ ^(-{0,2})([@%])([a-zA-Z_][a-zA-Z0-9_]*)?(([~][a-zA-Z_][a-zA-Z0-9_]*(,[a-zA-Z_][a-zA-Z0-9_]*)*)|([\[]=[~][a-zA-Z_][a-zA-Z0-9_]*(,[a-zA-Z_][a-zA-Z0-9_]*)*[\]]))?([.]{3,3}([1-9][0-9]*)?)?(=.*)?$ ]]; then
                _zetopt::msg::def_error "Invalid Parameter Definition:" "$param"
                return 1
            fi

            param_hyphens=${BASH_REMATCH[$((1 + INIT_IDX))]}
            param_type=${BASH_REMATCH[$((2 + INIT_IDX))]}
            param_name=${BASH_REMATCH[$((3 + INIT_IDX))]}
            param_validator=${BASH_REMATCH[$((4 + INIT_IDX))]}
            param_varlen=${BASH_REMATCH[$((9 + INIT_IDX))]}
            param_varlen_max=${BASH_REMATCH[$((10 + INIT_IDX))]}
            param_default=${BASH_REMATCH[$((11 + INIT_IDX))]}

            if [[ $param_type == @ ]]; then
                if [[ $param_optional == true ]]; then
                    _zetopt::msg::def_error "Required Parameter after Optional"
                    return 1
                fi
            else
                param_optional=true
            fi

            if [[ -n $param_varlen && $((idx + 1)) -ne $maxloop ]]; then
                _zetopt::msg::def_error "Variable-length parameter must be at the last"
                return 1
            fi

            # check if parameter names are duplicated
            var_param_name=$param_idx
            if [[ -n $param_name ]]; then
                if [[ $param_names =~ \ $param_name\  ]]; then
                    _zetopt::msg::def_error "Duplicate Parameter Name:" "$param_name"
                    return 1
                fi
                param_names+=" $param_name "
                var_param_name=$param_name
            fi

            param_validator_idxs=0
            if [[ $param_validator =~ ([a-zA-Z_][a-zA-Z0-9_]*(,[a-zA-Z_][a-zA-Z0-9_]*)*) ]]; then
                param_validator_separator=
                param_validator_idxs=
                IFS=,
                \set -- ${BASH_REMATCH[$((1 + INIT_IDX))]}
                while [[ $# -ne 0 ]]
                do
                    param_validator_name=$1
                    if [[ ! $LF${_ZETOPT_VALIDATOR_KEYS-} =~ $LF$param_validator_name:([0-9]+)$LF ]]; then
                        _zetopt::msg::def_error "Undefined Validator:" "$param_validator_name"
                        return 1
                    fi
                    param_validator_idxs="$param_validator_idxs$param_validator_separator${BASH_REMATCH[$((1 + INIT_IDX))]}"
                    param_validator_separator=,
                    shift 1
                done
            fi

            # save default value
            var_param_default=$ZETOPT_CFG_VARIABLE_DEFAULT
            if [[ -n $param_default ]]; then
                var_param_default=${param_default##=}
                _ZETOPT_DEFAULTS+=("${param_default##=}")
                param_default_idx=$((${#_ZETOPT_DEFAULTS[@]} - 1 + INIT_IDX))
                default_is_set=true
            elif [[ $default_is_set == true ]]; then
                _zetopt::msg::def_error "Non-default Argument Following Default Argument:" "$param_name"
                return 1
            fi
            params+=("$param_hyphens$param_type$param_name.$param_idx~$param_validator_idxs$param_varlen=$param_default_idx")
            param_idx+=1

            # define variable 
            if [[ $var_param_len == 1 ]]; then
                var_name=$var_base_name
            else
                var_name=$var_base_name$([[ $cmdmode == false ]] && echo _ ||:)$var_param_name
            fi
            \eval $var_name'=$var_param_default'
        done
        IFS=$' '
        param_def="${params[*]}"

    # Flag option
    else
        var_name="$var_base_name"
        \eval $var_name'=$ZETOPT_CFG_FLAGVAL_FALSE'
    fi

    if [[ -n "$helpdef" ]]; then
        _ZETOPT_OPTHELPS+=("$helpdef")
        helpidx=$((${#_ZETOPT_OPTHELPS[@]} - 1 + $INIT_IDX))
        if [[ $cmdmode == true ]]; then
            [[ $has_param == true ]] \
            && helpidx="$helpidx_cmd $helpidx" \
            || helpidx+=" 0"
        fi
    fi

    _ZETOPT_DEFINED+="$id$global:$short:$long:$param_def:$helpidx$LF"

    # defines parent subcommands automatically
    IFS=$' '
    local ns= curr_ns=
    for ns in ${namespace//\// }
    do
        curr_ns="${curr_ns%*/}/$ns/"
        [[ $LF$_ZETOPT_DEFINED =~ $LF$curr_ns: ]] && return 0
        _ZETOPT_DEFINED+="$curr_ns:::%.0~0...=0:0 0$LF"
    done
}

# defined(): Print the defined data. Print all if ID not given.
# def.) _zetopt::def::defined [ID]
# e.g.) _zetopt::def::defined /foo
# STDOUT: strings separated with $'\n'
_zetopt::def::defined()
{
    if [[ -z ${_ZETOPT_DEFINED-} ]]; then
        _ZETOPT_DEFINED="/:::$LF"
    fi
    if [[ -z ${1-} ]]; then
        \printf -- "%s" "$_ZETOPT_DEFINED"
        return 0
    fi
    _zetopt::def::field "$1" $ZETOPT_FIELD_DEF_ALL
}

# field(): Search and print the definition.
# def.) _zetopt::def::field {ID} [FIELD-DEF-NUMBER-TO-PRINT]
# e.g.) _zetopt::def::field /foo $ZETOPT_FIELD_DEF_ARG
# STDOUT: string
_zetopt::def::field()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if [[ ! $LF$_ZETOPT_DEFINED$LF =~ .*$LF(($id):([^:]*):([^:]*):([^:]*):([^:]*))$LF.* ]]; then
        return 1
    fi
    local field="${2:-$ZETOPT_FIELD_DEF_ALL}"
    case "$field" in
        $ZETOPT_FIELD_DEF_ALL)   \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DEF_ALL))]}";;
        $ZETOPT_FIELD_DEF_ID)    \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DEF_ID))]}";;
        $ZETOPT_FIELD_DEF_SHORT) \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DEF_SHORT))]}";;
        $ZETOPT_FIELD_DEF_LONG)  \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DEF_LONG))]}";;
        $ZETOPT_FIELD_DEF_ARG)   \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DEF_ARG))]}";;
        $ZETOPT_FIELD_DEF_HELP)  \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DEF_HELP))]}";;
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
    local id="$1" && [[ ! $id =~ ^/ ]] && id=/$id
    [[ $LF$_ZETOPT_DEFINED =~ $LF${id}[+]?: ]]
}

# has_subcmd(): Check if the current namespace has subcommands
# def.) _zetopt::def::has_subcmd {NAMESPACE}
# e.g.) _zetopt::def::has_subcmd /sub/
# STDOUT: NONE
_zetopt::def::has_subcmd()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1" && [[ ! $ns =~ ^/ ]] && ns=/$ns
    [[ $LF$_ZETOPT_DEFINED =~ $LF${ns}[a-zA-Z0-9_-]+/ ]]
}

# has_options(): Check if the current namespace has options
# def.) _zetopt::def::has_options {NAMESPACE}
# e.g.) _zetopt::def::has_options /sub/
# STDOUT: NONE
_zetopt::def::has_options()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1" && [[ ! $ns =~ ^/ ]] && ns=/$ns
    [[ ! $ns =~ /$ ]] && ns=$ns/
    [[ $LF$_ZETOPT_DEFINED =~ $LF${ns}[a-zA-Z0-9_]+[+]?: ]]
}

# has_arguments(): Check if the current namespace has arguments
# def.) _zetopt::def::has_arguments {NAMESPACE}
# e.g.) _zetopt::def::has_arguments /sub/
# STDOUT: NONE
_zetopt::def::has_arguments()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1" && [[ ! $ns =~ ^/ ]] && ns=/$ns
    [[ ! $ns =~ /$ ]] && ns=$ns/
    [[ $LF$_ZETOPT_DEFINED =~ $LF${ns}:::-?[@%] ]]
}

# options(): Print option definition
# def.) _zetopt::def::options
# e.g.) _zetopt::def::options
# STDOUT: option definition
_zetopt::def::options()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1" && [[ ! $ns =~ ^/ ]] && ns=/$ns
    [[ ! $ns =~ /$ ]] && ns=$ns/
    <<< "$_ZETOPT_DEFINED" \grep -E "^${ns}[a-zA-Z0-9_]+[+]?:"
}

# is_cmd(): Check if ID is command
# def.) _zetopt::def::is_cmd {ID}
# e.g.) _zetopt::def::is_cmd /sub/
# STDOUT: NONE
_zetopt::def::is_cmd()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1"
    [[ ! $ns =~ ^/ ]] && ns=/$ns ||:
    [[ ! $ns =~ /$ ]] && ns=$ns/ ||:
    [[ $LF$_ZETOPT_DEFINED =~ $LF${ns}: ]]
}

# namespaces(): Print namespace definition
# def.) _zetopt::def::namespaces
# e.g.) _zetopt::def::namespaces
# STDOUT: namespace definition
_zetopt::def::namespaces()
{
    <<< "$_ZETOPT_DEFINED" \grep -E '^/([^:]+/)?:' | \sed -e 's/:.*//'
}

# opt2id(): Print the identifier by searching with a namespace and a option name.
# If not found in the current namespace, search a global option in parent namespaces.
# def.) _zetopt::def::opt2id {NAMESPACE} {OPTION-NAME} {IS_SHORT}
# e.g.) _zetopt::def::opt2id /remote/add/ version
# STDOUT: an identifier
# RETURN: 0:No Error, 1:Not Found, 2:Ambiguous Name
_zetopt::def::opt2id()
{
    local ns="${1-}" opt="${2-}" is_short=${3-}
    if [[ -z $ns || -z $opt || -z $is_short ]]; then
        return 1
    fi

    local regex= global="[+]?" tmpid=
    while :
    do
        # short
        if [[ $is_short == true ]]; then
            if [[ $LF$_ZETOPT_DEFINED =~ $LF(${ns}[a-zA-Z0-9_]+)${global}:$opt: ]]; then
                \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX))]}"
                return 0
            fi
        
        # long
        else
            if [[ $ZETOPT_CFG_ABBREVIATED_LONG == true ]]; then
                if [[ $LF$_ZETOPT_DEFINED =~ $LF(${ns}[a-zA-Z0-9_]+)${global}:[^:]?:${opt}[^:]*:[^$LF]+$LF(.*) ]]; then
                    tmpid=${BASH_REMATCH[$((1 + $INIT_IDX))]}

                    # reject ambiguous name
                    if [[ $LF${BASH_REMATCH[$((2 + $INIT_IDX))]} =~ $LF(${ns}[a-zA-Z0-9_]+)${global}:[^:]?:${opt}[^:]*: ]]; then
                        return 2
                    fi
                    \printf -- "%s" "$tmpid"
                    return 0
                fi
            else
                if [[ $LF$_ZETOPT_DEFINED =~ $LF(${ns}[a-zA-Z0-9_]+)${global}:[^:]?:${opt}: ]]; then
                    \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX))]}"
                    return 0
                fi
            fi
        fi

        if [[ $ns == / ]]; then
            return 1
        fi
        ns=${ns%/*}  # remove the last /
        ns=${ns%/*}/ # parent ns
        global="[+]"
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
    if [[ ! $2 =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    local def_str="$(_zetopt::def::field "$id" $ZETOPT_FIELD_DEF_ARG)"
    if [[ -z $def_str ]]; then
        return 1
    fi
    if [[ $def_str =~ [@%]${2}[.]([0-9]+) ]]; then
        \printf -- "%s" ${BASH_REMATCH[$((1 + INIT_IDX))]}
        return 0
    fi
    return 1
}

# paramlen(): Print the length of parameters
# def.) _zetopt::def::paramlen {ID} [all | required | @ | optional | % | max]
# e.g.) _zetopt::def::paramlen /foo required
# STDOUT: an integer
_zetopt::def::paramlen()
{
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if ! _zetopt::def::exists "$id"; then
        \echo 0; return 1
    fi
    local def="$(_zetopt::def::field "$id" $ZETOPT_FIELD_DEF_ARG)"
    if [[ -z $def ]]; then
        \echo 0; return 0
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
            [[ $def =~ ([.]{3,3}([1-9][0-9]*)?)?=[0-9]+$ ]] || :
            if [[ -n ${BASH_REMATCH[$((1 + INIT_IDX))]} ]]; then
                [[ -n ${BASH_REMATCH[$((2 + INIT_IDX))]} ]] \
                && out=$reqcnt+$optcnt+${BASH_REMATCH[$((2 + INIT_IDX))]}-1 \
                || out=$((1<<31)) #2147483648
            else
                out=$reqcnt+$optcnt
            fi
            ;;
        "" | all) out=$reqcnt+$optcnt;;
        *)        out=$reqcnt+$optcnt;;
    esac
    \echo $out
}

# default(): Print default values
# def.) _zetopt::def::default {ID} [ONE-DIMENSIONAL-KEY]
# e.g.) _zetopt::def::default /foo @ FOO $ FOO,$
# STDOUT: default values separated with $ZETOPT_CFG_VALUE_IFS
_zetopt::def::default()
{
    if [[ -z ${_ZETOPT_DEFINED:-} || -z ${1-} ]]; then
        _zetopt::msg::debug "Syntax Error"
        return 1
    fi

    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if ! _zetopt::def::exists "$id"; then
        _zetopt::msg::debug "No Such Indentifier:" "${1-}"
        return 1
    fi
    shift

    local IFS=' ' params defaults_idx_arr output_list
    output_list=()
    local def_args="$(_zetopt::def::field "$id" $ZETOPT_FIELD_DEF_ARG)"
    params=($def_args)
    if [[ ${#params[@]} -eq 0 ]]; then
        _zetopt::msg::debug "No Parameter Defined"
        return 1
    fi

    defaults_idx_arr=(${params[@]#*=})
    if [[ "${defaults_idx_arr[*]}" =~ ^[0\ ]$ ]]; then
        _zetopt::msg::debug "Default Value Not Set"
        return 1
    fi

    [[ $# -eq 0 ]] && set -- @
    local key
    declare -i last_idx="$((${#params[@]} - 1 + $INIT_IDX))"
    for key in "$@"
    do
        if [[ ! $key =~ ^(@|(([$\^$INIT_IDX]|-?[1-9][0-9]*|[a-zA-Z_]+[a-zA-Z0-9_]*)(,([$\^$INIT_IDX]|-?[1-9][0-9]*|[a-zA-Z_]+[a-zA-Z0-9_]*)?)?)?)?$ ]]; then
            _zetopt::msg::debug "Bad Key:" "$key"
            return 1
        fi

        # split the value index range string
        local tmp_start_idx= tmp_end_idx=
        if [[ $key =~ , ]]; then
            tmp_start_idx="${key%%,*}"
            tmp_end_idx="${key#*,}"
        else
            tmp_start_idx=$key
            tmp_end_idx=$key
        fi

        case "$tmp_start_idx" in
            @ | "") tmp_start_idx=$INIT_IDX;;
            ^)      tmp_start_idx=$INIT_IDX;;
            $)      tmp_start_idx=$;; # the last index will be determined later
            *)      tmp_start_idx=$tmp_start_idx;;
        esac
        case "$tmp_end_idx" in
            @ | "") tmp_end_idx=$;; # the last index will be determined later
            ^)      tmp_end_idx=$INIT_IDX;;
            $)      tmp_end_idx=$;; # the last index will be determined later
            *)      tmp_end_idx=$tmp_end_idx;;
        esac

        # index by name
        declare -i idx=0
        local param_name=
        for param_name in $tmp_start_idx $tmp_end_idx
        do
            if [[ ! $param_name =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]]; then
                idx+=1
                continue
            elif [[ ! $def_args =~ [@%]${param_name}[.]([0-9]+) ]]; then
                _zetopt::msg::debug "Parameter Name Not Found:" "$param_name"
                return 1
            fi

            if [[ $idx -eq 0 ]]; then
                tmp_start_idx=${BASH_REMATCH[$((1 + INIT_IDX))]}
            else
                tmp_end_idx=${BASH_REMATCH[$((1 + INIT_IDX))]}
            fi
            idx+=1
        done

        # determine the value start/end index
        declare -i start_idx end_idx
        if [[ $tmp_start_idx == $ ]]; then
            start_idx=$last_idx  # set the last index
        else
            start_idx=$tmp_start_idx
        fi
        if [[ $tmp_end_idx == $ ]]; then
            end_idx=$last_idx    # set the last index
        else
            end_idx=$tmp_end_idx
        fi

        # convert negative indices to positive
        if [[ $start_idx =~ ^- ]]; then
            start_idx=$((last_idx - (start_idx * -1 - 1)))
        fi
        if [[ $end_idx =~ ^- ]]; then
            end_idx=$((last_idx - (end_idx * -1 - 1)))
        fi

        # check the range
        if [[ $start_idx -lt $INIT_IDX || $end_idx -gt $last_idx
            || $end_idx -lt $INIT_IDX || $start_idx -gt $last_idx
        ]]; then
            [[ $start_idx == $end_idx ]] \
            && local translated_idx=$start_idx \
            || local translated_idx=$start_idx~$end_idx
            _zetopt::msg::debug "Index Out of Range ($INIT_IDX~$last_idx):" "Translate \"$key\" -> $translated_idx"
            return 1
        fi

        declare -i default_idx idx
        for idx in $(\eval "\echo {$start_idx..$end_idx}")
        do
            default_idx=${defaults_idx_arr[idx]}
            if [[ $default_idx -eq 0 ]]; then
                _zetopt::msg::debug "Default Value Not Set"
                return 1
            fi
            output_list+=("${_ZETOPT_DEFAULTS[default_idx]}")
        done
    done
    if [[ ${#output_list[@]} -ne 0 ]]; then
        IFS=$ZETOPT_CFG_VALUE_IFS
        \printf -- "%s" "${output_list[*]}"
    fi
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
        _ZETOPT_VALIDATOR_DATA=
        _ZETOPT_VALIDATOR_ERRMSG=
    fi

    declare -i validator_idx=0 msg_idx=0
    local IFS=$' \n\t' name= validator= type=r errmsg= flags= error=false 
    while [[ $# -ne 0 ]]
    do
        case "$1" in
            -f | --function)
                type=f; shift;;
            -i | --ignore-case)
                flags+=i; shift;;
            -n | --not)
                flags+=n; shift;;
            --*)
                error=true; break;;
            -*)
                if [[ ! $1 =~ ^-[fin]+$ ]]; then
                    error=true; break
                fi
                [[ $1 =~ f ]] && type=f
                [[ $1 =~ i ]] && flags+=i
                [[ $1 =~ n ]] && flags+=n
                shift;;
            *)
                if [[ -n $name ]]; then
                    error=true; break
                fi
                name=$1
                if [[ -z ${2-} ]]; then
                    error=true; break
                fi
                validator=$2
                if [[ -n ${3-} ]]; then
                    errmsg=$3
                    if [[ -n ${4-} ]]; then
                        error=true; break
                    fi
                fi
                break;;
        esac
    done

    # check errors
    if [[ $error == true ]]; then
        _zetopt::msg::def_error "zetopt def-validator [-f | --function] [-i | --ignore-case] [-n | --not] {<NAME> <REGEXP | FUNCNAME> [#<ERROR_MESSAGE>]}"
        return 1
    fi
    if [[ ! $name =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        _zetopt::msg::def_error "Invalid Validator Name:" "$name"
        return 1
    fi
    if [[ $type == f ]]; then
        [[ -n ${ZSH_VERSION-} ]] \
        && local _type=$(whence -w "$validator") \
        || local _type=$(type -t "$validator")
        if [[ ! ${_type#*:} =~ function ]]; then
            _zetopt::msg::def_error "No Such Shell Function:" "$validator"
            return 1
        fi
    fi
    if [[ $LF$_ZETOPT_VALIDATOR_KEYS =~ $LF$name: ]]; then
        _zetopt::msg::def_error "Duplicate Validator Name:" "$name"
        return 1
    fi
    if [[ -n $errmsg && $errmsg =~ ^[^\#] ]]; then
        _zetopt::msg::def_error "Help message should start with \"#\""
        return 1
    fi

    # save validator
    if [[ -n $errmsg ]]; then
        _ZETOPT_VALIDATOR_ERRMSG+=("${errmsg:1}")
        msg_idx=$((${#_ZETOPT_VALIDATOR_ERRMSG[@]} - 1 + $INIT_IDX))
    fi
    _ZETOPT_VALIDATOR_DATA+=("$name:$type:$flags:$msg_idx:$validator")
    validator_idx=$((${#_ZETOPT_VALIDATOR_DATA[@]} - 1 + $INIT_IDX))
    _ZETOPT_VALIDATOR_KEYS+=$name:$validator_idx$LF
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
    \set -- ${BASH_REMATCH[$((1 + INIT_IDX))]}
    IFS=$' \t\n'

    while [[ $# -ne 0 ]]
    do
        declare -i validator_idx=$1
        shift 1

        if [[ ! ${_ZETOPT_VALIDATOR_DATA[$validator_idx]} =~ ^([^:]+):([rf]):([in]*):([0-9]+):(.*)$ ]]; then
            _zetopt::msg::debug "Internal Error:" "Validator Broken"
            return 1
        fi
        local validator_name="${BASH_REMATCH[$((1 + INIT_IDX))]}"
        local validator_type="${BASH_REMATCH[$((2 + INIT_IDX))]}"
        local validator_flags="${BASH_REMATCH[$((3 + INIT_IDX))]}"
        declare -i validator_msgidx="${BASH_REMATCH[$((4 + INIT_IDX))]}"
        local validator="${BASH_REMATCH[$((5 + INIT_IDX))]}"

        local result=$(
            # set ignore case option temporally
            if [[ $validator_flags =~ i ]]; then
                [[ -n ${ZSH_VERSION-} ]] \
                && \setopt localoptions NOCASEMATCH \
                || \shopt -s nocasematch
            fi

            # r: regexp
            if [[ $validator_type == r ]]; then
                if [[ ! $validator_flags =~ n ]]; then
                    [[ $arg =~ $validator ]] && echo true || echo false
                else
                    [[ $arg =~ $validator ]] && echo false || echo true
                fi
            # f: function
            else
                local _path=$PATH _lc_all=$LC_ALL _lang=$LANG
                local PATH=$_PATH LC_ALL=$_LC_ALL LANG=$_LANG
                if [[ ! $validator_flags =~ n ]]; then
                    "$validator" "$arg" && echo true || echo false
                else
                    "$validator" "$arg" && echo false || echo true
                fi
                PATH=$_path LC_ALL=$_lc_all LANG=$_lang
            fi
        )

        if [[ $result == false ]]; then
            if [[ $validator_msgidx -ne 0 ]]; then
                local errmsg="${_ZETOPT_VALIDATOR_ERRMSG[validator_msgidx]}"
                _zetopt::msg::user_error Error "$arg:" "$errmsg"
            fi
            return 1
        fi
    done
    return 0
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
}

# parse(): Parse arguments. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::parse {ARGUMENTS}
# e.g.) _zetopt::parser::parse "$@"
# STDOUT: NONE
_zetopt::parser::parse()
{
    if [[ $_ZETOPT_DEF_ERROR == true ]]; then
        _zetopt::msg::debug "Invalid Definition Data:" "Fix definition error before parse"
        return 1
    fi

    if [[ -z ${_ZETOPT_DEFINED:-} ]]; then
        _ZETOPT_DEFINED="/:::%.0~0...=0:0 0$LF"
    fi
    _zetopt::parser::init
    _zetopt::data::init
    
    local optname= optnames_len= optarg= idx= opt_prefix= pseudoname=
    local additional_args_count=0 consumed_args_count= args
    local namespace=/ ns= check_subcmd=true error_subcmd_name=
    
    # internal global variables
    declare -i _CONSUMED_ARGS_COUNT=0

    if ! _zetopt::parser::setsub $namespace; then
        _zetopt::msg::debug "Invalid Definition Data:" "Root Namespace Not Found"
        return 1
    fi

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
        elif [[ $1 =~ ^(--|[+][+])[^+-] || ($ZETOPT_CFG_SINGLE_PREFIX_LONG == true && ($1 =~ ^-[^-]. || $1 =~ ^[+][^+]. )) ]]; then
            if [[ ! $1 =~ ^([-+]{1,2})([a-zA-Z0-9_]+(-[a-zA-Z0-9_]+)*)((:[a-zA-Z0-9_]+)*)(=(.*$))?$ ]]; then
                ZETOPT_OPTERR_INVALID+=("$1")
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_INVALID_OPTFORMAT))
                shift
                check_subcmd=false
                continue
            fi
            opt_prefix=${BASH_REMATCH[$((1 + INIT_IDX))]}
            optname=${BASH_REMATCH[$((2 + INIT_IDX))]}
            pseudoname=${BASH_REMATCH[$((4 + INIT_IDX))]/:/}
            optarg=${BASH_REMATCH[$((7 + INIT_IDX))]}
            shift
            if [[ -n $optarg ]]; then
                additional_args_count=1
                _zetopt::parser::setopt $namespace $opt_prefix $optname "$pseudoname" "$optarg" "$@" ||:
            else
                _zetopt::parser::setopt $namespace $opt_prefix $optname "$pseudoname" "$@" ||:
            fi
            check_subcmd=false

        # short option(s)
        elif [[ $1 =~ ^([+-])([^+-].*)$ ]]; then
            opt_prefix=${BASH_REMATCH[$((1 + INIT_IDX))]}
            optnames=${BASH_REMATCH[$((2 + INIT_IDX))]}
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
                        break
                    else
                        if [[ $ZETOPT_CFG_CONCATENATED_OPTARG == true ]]; then
                            _zetopt::parser::setopt $namespace $opt_prefix $optname "" "${optnames:$((idx+1)):$(($optnames_len - $idx - 1))}" "$@" ||:
                            if [[ $consumed_args_count -ne $_CONSUMED_ARGS_COUNT ]]; then
                                additional_args_count=1
                                break
                            fi
                        else
                            _zetopt::parser::setopt $namespace $opt_prefix $optname "" "$@"||:
                        fi
                    fi
                else
                    _zetopt::parser::setopt $namespace $opt_prefix $optname "" "$@" ||:
                fi
            done
            check_subcmd=false

        # Positional Arguments or Subcommand
        else
            # Subcommand
            if [[ $check_subcmd == true ]] && _zetopt::def::has_subcmd "$namespace"; then
                ns="${namespace%/*}/$1/"
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
                if _zetopt::parser::setsub $ns; then
                    namespace=$ns
                    ZETOPT_LAST_COMMAND=$ns
                fi
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

    # assign positional args
    _zetopt::parser::assign_args "$namespace" ||:
    
    # show errors
    if [[ $ZETOPT_CFG_ERRMSG_USER_ERROR == true ]]; then
        IFS=$' \t\n'
        local subcmdstr="${namespace//\// }" msg=

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
        if [[ $(($ZETOPT_PARSE_ERRORS & $ZETOPT_STATUS_TOO_MATCH_ARGS)) -ne 0 ]]; then
            msg=($subcmdstr "${#_ZETOPT_TEMP_ARGV[@]} Arguments Given (Up To "$(_zetopt::def::paramlen $namespace max)")")
            _zetopt::msg::user_error Error "Too Match Arguments:" "${msg[*]}"
        fi
    fi

    [[ $ZETOPT_PARSE_ERRORS -le $ZETOPT_STATUS_ERROR_THRESHOLD ]]
}

# setsub(): Increment the set count of a sub-command. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::setsub {NAMESPACE}
# e.g.) _zetopt::parser::setsub /sub/
# STDOUT: NONE
_zetopt::parser::setsub()
{
    local id=${1-}
    if [[ ! $LF$_ZETOPT_PARSED =~ (.*$LF)(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))($LF.*) ]]; then
        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_SUBCMD))
        return $ZETOPT_STATUS_UNDEFINED_SUBCMD
    fi

    local head_lines="${BASH_REMATCH[$((1 + INIT_IDX))]:1}"
    local tail_lines="${BASH_REMATCH[$((10 + INIT_IDX))]}"
    local offset=2

    local IFS=:
    \set -- ${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_ALL))]}
    local cnt=$(($7 + 1))
    local pseudoidx=$INIT_IDX
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

    if [[ ! $LF$_ZETOPT_PARSED =~ (.*$LF)(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))($LF.*) ]]; then
        return 1
    fi
    local head_lines="${BASH_REMATCH[$((1 + INIT_IDX))]:1}"
    local tail_lines="${BASH_REMATCH[$((10 + INIT_IDX))]}"
    local IFS=:
    \set -- ${BASH_REMATCH[$((2 + INIT_IDX + ZETOPT_FIELD_DATA_ALL))]}
    local id="$1" refs_str="$2" argcs="$3" types="$4" pseudo_idexs="$5" stat="$6" cnt="$7"
    local curr_stat=$ZETOPT_STATUS_NORMAL

    local ref_arr paramdef_str="$(_zetopt::def::field "$id" $ZETOPT_FIELD_DEF_ARG)"
    declare -i optarg_idx=$((${#_ZETOPT_DATA[@]} + $INIT_IDX))
    declare -i arg_cnt=0
    ref_arr=()

    # options requiring NO argument
    if [[ -z $paramdef_str ]]; then
        [[ $opt_prefix =~ ^--?$ ]] \
        && _ZETOPT_DATA+=("${ZETOPT_CFG_FLAGVAL_TRUE:-0}") \
        || _ZETOPT_DATA+=("${ZETOPT_CFG_FLAGVAL_FALSE:-1}")
        ref_arr=($optarg_idx)

    # options requiring arguments
    else
        IFS=$' '
        \set -- $paramdef_str
        local arg def def_arr varlen_mode=false no_avail_args=false
        declare -i def_len=$(($# + INIT_IDX)) def_idx=$INIT_IDX
        declare -i arg_def_max arg_idx=$INIT_IDX arg_max_idx=$((${#args[@]} + $INIT_IDX))
        def_arr=($@)

        while [[ $def_idx -lt $def_len ]]
        do
            def=${def_arr[$def_idx]}

            # there are available args 
            if [[ $arg_idx -lt $arg_max_idx ]]; then
                arg="${args[$arg_idx]}"
                if [[ $arg == "" && $ZETOPT_CFG_IGNORE_BLANK_STRING == true ]]; then
                    arg_idx+=1
                    continue
                fi

                # check arg format
                if [[ $arg =~ ^[^-+]
                    || $arg =~ ^[-+]$
                    || $arg == ""
                    || ($arg =~ ^-[^-] && $def =~ ^-[^-])
                    || ($arg != "--" && $arg =~ ^- && $def =~ ^--)
                    || ($arg =~ ^[+] && $def =~ ^--? && $ZETOPT_CFG_OPTTYPE_PLUS == true)
                    || ($arg == "--" && $ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN -eq 0)
                ]]; then
                    # validate
                    if ! _zetopt::validator::validate "$def" "$arg"; then
                        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_VALIDATOR_FAILED))
                        return 1
                    fi
                    _ZETOPT_DATA+=("$arg")
                    ref_arr+=($optarg_idx)
                    arg_cnt+=1
                    _CONSUMED_ARGS_COUNT+=1

                    arg_idx+=1
                    optarg_idx+=1

                    if [[ $varlen_mode == false && $def =~ [.]{3,3} ]]; then
                        varlen_mode=true
                        arg_def_max=$(_zetopt::def::paramlen $id max)
                    fi

                    if [[ $varlen_mode == true && $arg_cnt -ge $arg_def_max ]]; then
                        break
                    fi

                    # increment def_idx if def is not a variable-length argument
                    if [[ $varlen_mode == false ]]; then
                        def_idx+=1
                    fi
                else
                    no_avail_args=true
                    break
                fi
            else
                no_avail_args=true
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
                while [[ $def_idx -lt $def_len ]]
                do
                    def=${def_arr[$def_idx]}

                    # has default value
                    if [[ $def =~ ([.]{3,3}([1-9][0-9]*)?)?=([1-9][0-9]*) ]]; then
                        arg=${_ZETOPT_DEFAULTS[${BASH_REMATCH[$((3 + INIT_IDX))]}]}
                        _ZETOPT_DATA+=("$arg")
                        ref_arr+=($optarg_idx)
                        optarg_idx+=1
                        def_idx+=1
                        continue
                    
                    # warning: missing optional optarg
                    else
                        curr_stat=$ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS
                        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | curr_stat))
                        ZETOPT_OPTERR_MISSING_OPTIONAL+=("$opt_prefix$opt")
                        break
                    fi
                done
            fi
        fi
    fi

    local type=$ZETOPT_TYPE_CMD
    case $opt_prefix in
        -)  type=$ZETOPT_TYPE_SHORT;;
        --) type=$ZETOPT_TYPE_LONG;;
        +)  type=$ZETOPT_TYPE_PLUS;;
    esac

    _ZETOPT_DATA+=("$pseudoname")
    local pseudoidx=$((${#_ZETOPT_DATA[@]} - 1 + $INIT_IDX))

    IFS=$' '
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


# assign_args(): Assign indices to subcommand parameters. 
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
    local def_str def_arr ref_arr IFS=' '
    def_str="$(_zetopt::def::field "$id" $ZETOPT_FIELD_DEF_ARG)"
    ref_arr=()
    def_arr=($def_str)
    declare -i def_len=${#def_arr[@]} arg_len=${#_ZETOPT_TEMP_ARGV[@]} rtn=$ZETOPT_STATUS_NORMAL idx maxloop

    # enough
    if [[ $arg_len -ge $def_max_len ]]; then
        ref_arr=($(\eval "\echo {$INIT_IDX..$((def_max_len - 1 + INIT_IDX))}"))
        maxloop=$def_len+$INIT_IDX
        # explicit defined arguments
        for ((idx=INIT_IDX; idx<maxloop; idx++))
        do
            # validate
            if ! _zetopt::validator::validate "${def_arr[idx]}" "${_ZETOPT_TEMP_ARGV[ref_arr[idx]]}"; then
                rtn=$((rtn | ZETOPT_STATUS_VALIDATOR_FAILED))
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                continue
            fi
            _ZETOPT_DATA+=("${_ZETOPT_TEMP_ARGV[ref_arr[idx]]}")
            ref_arr[$idx]=$((${#_ZETOPT_DATA[@]} - 1 + $INIT_IDX))
        done
        
        # variable length arguments
        for ((; idx<$((def_max_len+INIT_IDX)); idx++))
        do
            _ZETOPT_DATA+=("${_ZETOPT_TEMP_ARGV[ref_arr[idx]]}")
            ref_arr[$idx]=$((${#_ZETOPT_DATA[@]} - 1 + $INIT_IDX))
        done

        # too match arguments
        if [[ $arg_len -gt $def_max_len ]]; then
            _ZETOPT_EXTRA_ARGV=("${_ZETOPT_TEMP_ARGV[@]:$((def_max_len))}")
            #rtn=$((rtn | ZETOPT_STATUS_TOO_MATCH_ARGS))
            : #ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
        fi

    # not enough
    else
        # has some args
        declare -i ref_idx=$INIT_IDX
        if [[ $arg_len -ne 0 ]]; then
            ref_idx=$arg_len-1+$INIT_IDX
            ref_arr=($(\eval "\echo {$INIT_IDX..$ref_idx}"))
            ref_idx+=1

            maxloop=$arg_len+$INIT_IDX
            local def=
            for ((idx=INIT_IDX; idx<maxloop; idx++))
            do
                # validate
                if [[ $idx -lt $((${#def_arr[@]} + INIT_IDX)) ]]; then
                    def=${def_arr[idx]}
                else
                    def=${def_arr[$((${#def_arr[@]}-1+INIT_IDX))]}
                fi
                if ! _zetopt::validator::validate "$def" "${_ZETOPT_TEMP_ARGV[ref_arr[idx]]}"; then
                    rtn=$((rtn | ZETOPT_STATUS_VALIDATOR_FAILED))
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                fi

                _ZETOPT_DATA+=("${_ZETOPT_TEMP_ARGV[ref_arr[idx]]}")
                ref_arr[$idx]=$((${#_ZETOPT_DATA[@]} - 1 + $INIT_IDX))
            done
        fi

        declare -i def_loops=$def_len+$INIT_IDX default_idx
        for ((; ref_idx<def_loops; ref_idx++))
        do
            # missing required
            if [[ ! ${def_arr[ref_idx]} =~ ^-{0,2}%([A-Za-z_][A-Za-z0-9_]*)?[.][0-9]+[~][0-9]+(,[0-9]+)*([.]{3,3}([1-9][0-9]*)?)?=([0-9]+)$ ]]; then
                rtn=$((rtn | ZETOPT_STATUS_MISSING_REQUIRED_ARGS))
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                break
            fi
            default_idx=${BASH_REMATCH[$((5 + INIT_IDX))]}

            # missing optional : has no default value
            if [[ $default_idx -eq 0 ]]; then
                rtn=$((rtn | ZETOPT_STATUS_MISSING_OPTIONAL_ARGS))
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                break
            fi

            # set default value
            #_ZETOPT_DATA+=("${_ZETOPT_DEFAULTS[default_idx]}")
            _ZETOPT_DATA+=(_NULL)
            ref_arr+=($((${#_ZETOPT_DATA[@]} - 1 + $INIT_IDX)))
        done
    fi

    # update parsed data
    if [[ ! $LF$_ZETOPT_PARSED =~ (.*$LF)(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))($LF.*) ]]; then
        return 1
    fi
    local head_lines="${BASH_REMATCH[$((1 + INIT_IDX))]:1}"
    local tail_lines="${BASH_REMATCH[$((10 + INIT_IDX))]}"
    local offset=2
    local line="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_ALL))]}"
    local id="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_ID))]}"
    #local argv="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_ARGV))]}"
    #local argc="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_ARGC))]}"
    local type="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_TYPE))]}"
    local pseudoname="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_PSEUDO))]}"
    #local status="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_STATUS))]}"
    local count="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_COUNT))]}"
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
    local IFS=$LF line=
    for line in ${_ZETOPT_DEFINED//+/} # remove global signs
    do
        IFS=:
        set -- $line
        _ZETOPT_PARSED+="$1::::::0$LF"
    done
    _ZETOPT_DATA=()
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
        \echo "${_ZETOPT_PARSED-}"
        return 0
    fi
    _zetopt::data::field "$1" $ZETOPT_FIELD_DATA_ALL
}

# field(): Search and print the parsed data
# def.) _zetopt::data::field {ID} [FILED-DATA-NUMBER]
# e.g.) _zetopt::data::field /foo $ZETOPT_FIELD_DATA_ARGV
# STDOUT: string
_zetopt::data::field()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if [[ ! $LF${_ZETOPT_PARSED-}$LF =~ .*$LF(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))$LF.* ]]; then
        return 1
    fi
    local field="${2:-$ZETOPT_FIELD_DATA_ALL}"
    case "$field" in
        $ZETOPT_FIELD_DATA_ALL)    \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_ALL))]}";;
        $ZETOPT_FIELD_DATA_ID)     \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_ID))]}";;
        $ZETOPT_FIELD_DATA_ARGV)   \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_ARGV))]}";;
        $ZETOPT_FIELD_DATA_ARGC)   \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_ARGC))]}";;
        $ZETOPT_FIELD_DATA_TYPE)   \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_TYPE))]}";;
        $ZETOPT_FIELD_DATA_PSEUDO) \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_PSEUDO))]}";;
        $ZETOPT_FIELD_DATA_STATUS) \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_STATUS))]}";;
        $ZETOPT_FIELD_DATA_COUNT)  \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_COUNT))]}";;
        $ZETOPT_FIELD_DATA_EXTRA_ARGV) \printf -- "%s" "$(_zetopt::data::extra_field $id)";;
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
        if [[ ${#_ZETOPT_EXTRA_ARGV[@]} -ne 0 ]]; then
            \printf -- "%s" "$(eval '\echo {'$INIT_IDX'..'$((${#_ZETOPT_EXTRA_ARGV[@]} - 1 + $INIT_IDX))'}')"
        fi
    fi
}

# isset(): Check if the option is set
# def.) _zetopt::data::isset {ID}
# e.g.) _zetopt::data::isset /foo
# STDOUT: NONE
_zetopt::data::isset()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    [[ $LF${_ZETOPT_PARSED-} =~ $LF$id: && ! $LF${_ZETOPT_PARSED-} =~ $LF$id:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:0 ]]
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
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if ! _zetopt::def::exists "$id"; then
        return 1
    fi
    if [[ $LF$_ZETOPT_PARSED =~ $LF$id:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:0 ]]; then
        return 1
    fi

    shift
    local status_list="$(_zetopt::data::print $ZETOPT_FIELD_DATA_STATUS "$id" "$@")"
    if [[ -z $status_list ]]; then
        return 1
    fi
    [[ ! $status_list =~ [^$ZETOPT_STATUS_NORMAL$ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS$ZETOPT_STATUS_MISSING_OPTIONAL_ARGS\ ] ]]
}

# pickup(): Print option arguments/status index list
# def.) _zetopt::data::pickup {ID} {[$ZETOPT_FILED_DATA_ARGS|$ZETOPT_FIELD_DATA_TYPE|$ZETOPT_FIELD_DATA_PSEUDO|$ZETOPT_FILED_DATA_STATUS]} [1D/2D-KEY...]
# e.g.) _zetopt::data::pickup /foo $ZETOPT_FILED_DATA_ARGS 0 @ 0:1 0:@ 1:@ name 0:1,-1 @:foo,baz 
# STDOUT: integers separated with spaces
_zetopt::data::pickup()
{
    if [[ -z ${_ZETOPT_PARSED:-} || $# -lt 2 || -z ${1-} ]]; then
        return 1
    fi
    case $2 in
        $ZETOPT_FIELD_DATA_ARGV | $ZETOPT_FIELD_DATA_ARGC | $ZETOPT_FIELD_DATA_TYPE | $ZETOPT_FIELD_DATA_PSEUDO | $ZETOPT_FIELD_DATA_STATUS | $ZETOPT_FIELD_DATA_EXTRA_ARGV) :;;
        *) return 1;;
    esac
    local field="$2"
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    local IFS=, lists output_list
    lists=($(_zetopt::data::field "$id" $field))
    if [[ ${#lists[@]} -eq 0 ]]; then
        return 1
    fi
    output_list=()
    local lists_last_idx="$((${#lists[@]} - 1 + $INIT_IDX))"

    shift 2
    IFS=' '
    if [[ $# -eq 0 ]]; then
        output_list=(${lists[$lists_last_idx]})
    else
        # get the arg definition for param names
        local def_args=
        if [[ $field -eq $ZETOPT_FIELD_DATA_ARGV ]]; then
            def_args="$(_zetopt::def::field "$id" $ZETOPT_FIELD_DEF_ARG)"
        fi

        local list_last_vals
        list_last_vals=(${lists[$lists_last_idx]})
        local val_lastlist_lastidx=$((${#list_last_vals[@]} - 1 + $INIT_IDX))

        local input_idx= tmp_list
        for input_idx in "$@"
        do
            if [[ ! $input_idx =~ ^(@|([$\^$INIT_IDX]|-?[1-9][0-9]*)(,([$\^$INIT_IDX]|-?[1-9][0-9]*)?)?)?(:?(@|(([$\^$INIT_IDX]|-?[1-9][0-9]*|[a-zA-Z_]+[a-zA-Z0-9_]*)(,([$\^$INIT_IDX]|-?[1-9][0-9]*|[a-zA-Z_]+[a-zA-Z0-9_]*)?)?)?)?)?$ ]]; then
                _zetopt::msg::debug "Bad Key:" "$input_idx"
                return 1
            fi

            # shortcuts for improving performance
            # @ / 0,$ / ^,$
            if [[ $input_idx =~ ^(@|[${INIT_IDX}\^],[\$${val_lastlist_lastidx}])$ ]]; then
                output_list+=(${list_last_vals[@]})
                continue
            # @:@ / ^,$:@ / 0,$:@ / @:^,$ / @:0,$ / 0,$:0,$ / 0,$:^,$
            elif [[ $input_idx =~ ^(@|\^,\$|${INIT_IDX},\$):(@|\^,\$|${INIT_IDX},\$)$ ]]; then
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
            else
                tmp_list_start_idx=$tmp_list_idx
                tmp_list_end_idx=$tmp_list_idx
            fi

            # determine the list start/end index
            local list_start_idx= list_end_idx=
            case "$tmp_list_start_idx" in
                @)      list_start_idx=$INIT_IDX;;
                ^)      list_start_idx=$INIT_IDX;;
                $|"")   list_start_idx=$lists_last_idx;;
                *)      list_start_idx=$tmp_list_start_idx;;
            esac
            case "$tmp_list_end_idx" in
                @)      list_end_idx=$lists_last_idx;;
                ^)      list_end_idx=$INIT_IDX;;
                $|"")   list_end_idx=$lists_last_idx;;
                *)      list_end_idx=$tmp_list_end_idx
            esac

            # convert negative indices to positive ones
            if [[ $list_start_idx =~ ^- ]]; then
                list_start_idx=$((lists_last_idx - (list_start_idx * -1 - 1)))
            fi
            if [[ $list_end_idx =~ ^- ]]; then
                list_end_idx=$((lists_last_idx - (list_end_idx * -1 - 1)))
            fi
            
            # check the range
            if [[ $list_start_idx -lt $INIT_IDX || $list_end_idx -gt $lists_last_idx
                || $list_end_idx -lt $INIT_IDX || $list_start_idx -gt $lists_last_idx
            ]]; then
                [[ $list_start_idx == $list_end_idx ]] \
                && local translated_idx=$list_start_idx \
                || local translated_idx=$list_start_idx~$list_end_idx
                _zetopt::msg::debug "Session Index Out of Range ($INIT_IDX~$lists_last_idx)" "Translate \"$tmp_list_idx\" -> $translated_idx"
                return 1
            fi

            # split the value index range string
            local tmp_val_start_idx= tmp_val_end_idx=
            if [[ $tmp_val_idx =~ , ]]; then
                tmp_val_start_idx="${tmp_val_idx%%,*}"
                tmp_val_end_idx="${tmp_val_idx#*,}"
            else
                tmp_val_start_idx=$tmp_val_idx
                tmp_val_end_idx=$tmp_val_idx
            fi

            case "$tmp_val_start_idx" in
                @)      tmp_val_start_idx=$INIT_IDX;;
                ^)      tmp_val_start_idx=$INIT_IDX;;
                $|"")   tmp_val_start_idx=$;; # the last index will be determined later
                *)      tmp_val_start_idx=$tmp_val_start_idx;;
            esac
            case "$tmp_val_end_idx" in
                @)      tmp_val_end_idx=$;; # the last index will be determined later
                ^)      tmp_val_end_idx=$INIT_IDX;;
                $|"")   tmp_val_end_idx=$;; # the last index will be determined later
                *)      tmp_val_end_idx=$tmp_val_end_idx
            esac

            # index by name : look up a name from parameter definition
            local idx=0 param_name=
            for param_name in $tmp_val_start_idx $tmp_val_end_idx
            do
                if [[ ! $param_name =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]]; then
                    idx+=1
                    continue
                fi

                if [[ ! $def_args =~ [@%]${param_name}[.]([0-9]+) ]]; then
                    _zetopt::msg::debug "Parameter Name Not Found:" "$param_name"
                    return 1
                fi

                if [[ $idx -eq 0 ]]; then
                    tmp_val_start_idx=${BASH_REMATCH[$((1 + INIT_IDX))]}
                else
                    tmp_val_end_idx=${BASH_REMATCH[$((1 + INIT_IDX))]}
                fi
                idx+=1
            done
            
            local list_idx= val_idx= maxidx= val_start_idx= val_end_idx=
            tmp_list=()
            for list_idx in $(\eval "echo {$list_start_idx..$list_end_idx}")
            do 
                tmp_list=(${lists[$list_idx]})
                if [[ ${#tmp_list[@]} -eq 0 ]]; then
                    continue
                fi
                
                # determine the value start/end index
                maxidx=$((${#tmp_list[@]} - 1 + $INIT_IDX))
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

                # convert negative indices to positive
                if [[ $val_start_idx =~ ^- ]]; then
                    val_start_idx=$((maxidx - (val_start_idx * -1 - 1)))
                fi
                if [[ $val_end_idx =~ ^- ]]; then
                    val_end_idx=$((maxidx - (val_end_idx * -1 - 1)))
                fi

                # check the range
                if [[ $val_start_idx -lt $INIT_IDX || $val_end_idx -gt $maxidx
                    || $val_end_idx -lt $INIT_IDX || $val_start_idx -gt $maxidx
                ]]; then
                    [[ $val_start_idx == $val_end_idx ]] \
                    && local translated_idx=$val_start_idx \
                    || local translated_idx=$val_start_idx~$val_end_idx
                    _zetopt::msg::debug "Value Index Out of Range ($INIT_IDX~$maxidx):" "Translate \"$tmp_val_idx\" -> $translated_idx"
                    return 1
                fi

                for val_idx in $(\eval "\echo {$val_start_idx..$val_end_idx}")
                do
                    output_list+=(${tmp_list[$val_idx]})
                done
            done
        done
    fi
    \printf -- "%s\n" "${output_list[*]}"
}


# hasarg(): Check if the target has arg
# def.) _zetopt::data:hasarg {ID} [1D-KEY...]
# e.g.) _zetopt::data::hasarg /foo 0
# STDOUT: NONE
_zetopt::data::hasarg()
{
    local argc_str="$(_zetopt::data::print $ZETOPT_FIELD_DATA_ARGC "$@")"
    [[ -n "$argc_str" && ! "$argc_str" =~ ^[0\ ]+$ ]]
}


# print(): Print field data with keys.
# -a/-v enables to store data in user specified array/variable.
# def.) _zetopt::data::print {FIELD_NUMBER} {ID} [1D/2D-KEY...] [-a,--array <ARRAY_NAME> | -v,--variable <VARIABLE_NAME>] [-I,--IFS <IFS_VALUE>]
# e.g.) _zetopt::data::print /foo $ZETOPT_FIELD_DATA_ARGV @:@ --array myarr
# STDOUT: data option names separated with $ZETOPT_CFG_VALUE_IFS or --IFS value
_zetopt::data::print()
{
    if [[ $# -eq 0 ]]; then
        return 1
    fi
    local __field=$1
    shift
    local __out_mode=stdout __var_name= __newline=$LF
    local __args __ifs=${ZETOPT_CFG_VALUE_IFS-$' '}
    __args=()

    while [[ $# -ne 0 ]]
    do
        case "$1" in
            -a | --array)
                __out_mode=array
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Option Argument:" "-a, --array <ARRAY_NAME>"
                    return 1
                fi
                __var_name=$1
                shift
                ;;
            -v | --variable)
                __out_mode=variable
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Option Argument:" "-v, --variable <VARIABLE_NAME>"
                    return 1
                fi
                __var_name=$1
                shift
                ;;
            -I | --IFS)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Option Argument:" "-I, --IFS <IFS_VALUE>"
                    return 1
                fi
                __ifs=$1
                shift
                ;;
            -E | --extra) __field=$ZETOPT_FIELD_DATA_EXTRA_ARGV; shift;;
            -n | --no-newline) __newline=; shift;;
            --) shift; __args+=("$@"); break;;
            --*|-[a-zA-Z])
                _zetopt::msg::debug "Undefined Option:" "$1"
                return 1;;
            *)  __args+=("$1"); shift;;
        esac
    done

    if [[ $__out_mode =~ ^(array|variable)$ ]]; then
        # check the user defined variable name before eval to avoid overwriting local variables
        if [[ ! $__var_name =~ ^[a-zA-Z_]([0-9a-zA-Z_]+)*$ ]] || [[ $__var_name =~ ((^_$)|(^__[0-9a-zA-Z][0-9a-zA-Z_]*$)|(^IFS$)) ]]; then
            _zetopt::msg::debug "Invalid Variable Name:" "$__var_name"
            return 1
        fi
        case $__out_mode in
            array) \eval "$__var_name=()";;
            variable) \eval "$__var_name=";;
        esac
    fi

    local IFS=' '
    local __id="${__args[$((0 + $INIT_IDX))]-$ZETOPT_LAST_COMMAND}"
    if ! _zetopt::def::exists "$__id"; then
        _zetopt::msg::debug "No Such ID:" "$__id" 
        return 1
    fi
    [[ ! $__id =~ ^/ ]] && __id="/$__id" ||:
    
    local __keys=${__args[@]:1}
    if [[ -z $__keys ]]; then
        [[ $__field =~ ^[$ZETOPT_FIELD_DATA_ARGV$ZETOPT_FIELD_DATA_EXTRA_ARGV]$ ]] \
        && __keys=@ \
        || __keys=$
    fi
    
    local __list_str
    if [[ $__field != $ZETOPT_FIELD_DATA_COUNT ]]; then
        __list_str="$(_zetopt::data::pickup "$__id" $__field $__keys)"
    else
        __list_str=$(_zetopt::data::field "$__id" $__field || echo 0)
    fi
    if [[ -z "$__list_str" ]]; then
        return 1
    fi
    
    declare -i __idx= __i=$INIT_IDX
    \set -- $__list_str
    local __max=$(($# + INIT_IDX - 1))
    local __nl=

    # indexes to refer target data in array
    if [[ $__field =~ ^[$ZETOPT_FIELD_DATA_ARGV$ZETOPT_FIELD_DATA_PSEUDO$ZETOPT_FIELD_DATA_EXTRA_ARGV]$ ]]; then
        if [[ $__field =~ ^[$ZETOPT_FIELD_DATA_ARGV$ZETOPT_FIELD_DATA_PSEUDO]$ ]]; then
            __args=("${_ZETOPT_DATA[@]}")
        else
            __args=("${_ZETOPT_EXTRA_ARGV[@]}")
        fi
        for __idx in "$@"
        do
            # store data in user specified array
            if [[ $__out_mode == array ]]; then
                \eval $__var_name'[$__i]=${__args[$__idx]}'
            else
                if [[ $__i -eq $__max ]]; then
                    __ifs= __nl=$__newline
                fi
                
                # print to STDOUT
                if [[ $__out_mode == stdout ]]; then
                    \printf -- "%s$__ifs$__nl" "${__args[$__idx]}"

                # store data in user specified variable
                else
                    \eval $__var_name'="$'$__var_name'${__args[$__idx]}$__ifs"'
                fi
            fi
            __i+=1
        done

    # target data itself
    else
        for __idx in "$@"
        do
            # store data in user specified array
            if [[ $__out_mode == array ]]; then
                \eval $__var_name'[$__i]=$__idx'
            else
                if [[ $__i -eq $__max ]]; then
                    __ifs= __nl=$__newline
                fi

                # output to STDOUT
                if [[ $__out_mode == stdout ]]; then
                    \printf -- "%s$__ifs$__nl" "$__idx"
                    
                # store data in user specified variable
                else
                    \eval $__var_name'="$'$__var_name'$__idx$__ifs"'
                fi
            fi
            __i+=1
        done
    fi
}


_zetopt::data::iterate()
{
    local __args__ __action__= __field__=$ZETOPT_FIELD_DATA_ARGV
    local __user_value__=ZV_VALUE __user_key__= __user_last_key__= __user_array__=
    local __itr_id__= __null_value__=NULL __null_key__=NULL
    __args__=()
    while [[ $# -ne 0 ]]
    do
        case "$1" in
            -v | --value)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Option Argument:" "-v, --value <VARIABLE_NAME_FOR_VALUE,...>"
                    return 1
                fi
                __user_value__=$1
                shift;;
            -k | --key)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Option Argument:" "-k, --key <VARIABLE_NAME_FOR_KEY,...>"
                    return 1
                fi
                __user_key__=$1
                shift;;
            -l | --last-key)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Option Argument:" "-l, --last-key <VARIABLE_NAME_FOR_LAST_KEY>"
                    return 1
                fi
                __user_last_key__=$1
                shift;;
            -a | --array)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Option Argument:" "-a, --array <VARIABLE_NAME_FOR_ARRAY>"
                    return 1
                fi
                __user_array__=$1
                shift;;
            --nv | --null-value)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Option Argument:" "-V, --null-value <NULL_VALUE>"
                    return 1
                fi
                __null_value__=$1
                shift;;
            --nk | --null-key)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Option Argument:" "-K, --null-key <NULL_KEY>"
                    return 1
                fi
                __null_key__=$1
                shift;;
            --id)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Option Argument:" "--id <ITERATOR_ID>"
                    return 1
                fi
                __itr_id__=_$1
                shift;;
            --reset)
                __action__=reset
                shift;;
            --unset)
                __action__=unset
                shift;;
            --has-next)
                __action__=has-next
                shift;;
            --extra)
                __field__=$ZETOPT_FIELD_DATA_EXTRA_ARGV
                shift;;
            --* | -[a-zA-Z])
                _zetopt::msg::debug "Undefined Option:" "$1"
                return 1;;
            --) shift; __args__+=("$@"); break;;
            *)  __args__+=("$1"); shift;;
        esac
    done
    
    local __id__="${__args__[$((0 + $INIT_IDX))]-${ZETOPT_LAST_COMMAND}}"
    local __complemented_id__=
    if ! _zetopt::def::exists "$__id__"; then
        # complement ID if the first arg looks a key
        if [[ ! $__id__ =~ ^(/([a-zA-Z0-9_]+)?|^(/[a-zA-Z0-9_]+(-[a-zA-Z0-9_]+)*)+/([a-zA-Z0-9_]+)?)$ && $__id__ =~ [@,\^\$\-\:] ]]; then
            __id__=$ZETOPT_LAST_COMMAND
            __complemented_id__=$ZETOPT_LAST_COMMAND
        else
            _zetopt::msg::debug "No Such ID:" "$__id__" 
            return 1
        fi
    fi
    [[ ! $__id__ =~ ^/ ]] && __id__="/$__id__" ||:

    # make variable names based on ID, KEY or --id <ITERATOR_ID>
    local __var_id_suffix__
    if [[ -n $__itr_id__ ]]; then
        if [[ ! $__itr_id__ =~ ^[a-zA-Z0-9_]+$ ]]; then
            _zetopt::msg::debug "Invalid Iterator ID:" "$__itr_id__"
            return 1
        fi
        __var_id_suffix__=$__itr_id__
    else
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
    local __array__=_zetopt_iterator_array_$__var_id_suffix__
    local __index__=_zetopt_iterator_index_$__var_id_suffix__

    # --has-next checks next item existence
    if [[ $__action__ == has-next ]]; then
        if [[ -n $(eval 'echo ${'$__array__'+x}') && -n $(eval 'echo ${'$__index__'+x}') ]]; then
            if [[ $__index__ -ge $(eval 'echo $((${#'$__array__'[@]} + INIT_IDX))') ]]; then
                return 1
            else
                return 0
            fi
        else
            return 1
        fi
    fi

    # --reset resets index
    if [[ $__action__ == reset ]]; then
        if [[ -n $(eval 'echo ${'$__array__'+x}') && -n $(eval 'echo ${'$__index__'+x}') ]]; then
            eval $__index__'=$INIT_IDX'
            return 0
        else
            return 1
        fi
    fi

    # --unset unsets array and index
    if [[ $__action__ == unset ]]; then
        unset $__array__ ||:
        unset $__index__ ||:
        return 0
    fi

    # check the user defined variable name before eval to avoid invalid characters and overwriting local variables
    local IFS=,
    set -- $__user_value__ $__user_key__ $__user_last_key__ $__user_array__
    for __tmp_var_name__ in $@
    do
        [[ -z $__tmp_var_name__ ]] && continue ||:
        if [[ ! $__tmp_var_name__ =~ ^[a-zA-Z_]([0-9a-zA-Z_]+)*$ ]] || [[ $__tmp_var_name__ =~ ((^_$)|(^__[0-9a-zA-Z][0-9a-zA-Z_]*__$)|(^IFS$)) ]]; then
            _zetopt::msg::debug "Invalid Variable Name:" "$__tmp_var_name__"
            return 1
        fi
    done
    local __user_value_names__ __user_key_names__
    __user_value_names__=($__user_value__)
    __user_key_names__=($__user_key__)
    if [[ (-n $__user_value__ && -n $__user_key__) && (${#__user_value_names__[@]} -ne ${#__user_key_names__[@]}) ]]; then
        _zetopt::msg::debug "Number of Variables Mismatch :" "--value=$__user_value__ --key=$__user_key__"
        return 1
    fi
    IFS=$' \n\t'

    # initialize if unbound
    if [[ ! -n $(eval 'echo ${'$__array__'+x}') || ! -n $(eval 'echo ${'$__index__'+x}') ]]; then
        if _zetopt::data::print $__field__ $__complemented_id__ "${__args__[@]}" -a $__array__; then
            eval $__index__'=$INIT_IDX'

        # unset and return error if failed
        else
            unset $__array__
            unset $__index__
            return 1
        fi
    fi

    # has no next
    local __max__=$(eval 'echo $((${#'$__array__'[@]} + INIT_IDX))')
    if [[ $__index__ -ge $__max__ ]]; then
        unset $__array__
        unset $__index__
        return 1
    fi

    # last-key / array
    [[ -n $__user_last_key__ ]] && eval $__user_last_key__'=$((${#'$__array__'[@]} - 1 + $INIT_IDX))' ||:
    [[ -n $__user_array__ ]] && eval $__user_array__'=("${'$__array__'[@]}")' ||:

    # value / key : Iterate with multiple values/keys
    if [[ -n $__user_value__ || -n $__user_key__ ]]; then
        local __idx__=
        local __max_idx__=$(($([[ -n $__user_value__ ]] && echo ${#__user_value_names__[@]} || echo ${#__user_key_names__[@]}) + $INIT_IDX))
        for (( __idx__=INIT_IDX; __idx__<__max_idx__; __idx__++ ))
        do
            # value
            if [[ -n $__user_value__ ]]; then
                eval ${__user_value_names__[$__idx__]}'="${'$__array__'[$'$__index__']}"' ||:
            fi

            # key
            if [[ -n $__user_key__ ]]; then
                eval ${__user_key_names__[$__idx__]}'=$'$__index__ ||:
            fi

            # increment index
            eval $__index__'=$(('$__index__' + 1))'
            if [[ $__index__ -ge $__max__ ]]; then
                break
            fi
        done

        # substitute NULL_VALUE/NULL_KEY if breaking the previous loop because of __array__ being short
        for (( __idx__++; __idx__<__max_idx__; __idx__++ ))
        do
            # value
            if [[ -n $__user_value__ ]]; then
                eval ${__user_value_names__[$__idx__]}'=$__null_value__' ||:
            fi

            # key
            if [[ -n $__user_key__ ]]; then
                eval ${__user_key_names__[$__idx__]}'=$__null_key__' ||:
            fi
        done
    else
        # increment for using last-key / array only
        eval $__index__'=$(('$__index__' + 1))'
    fi
    return 0
}

# setids(): Print the list of IDs set
# def.) _zetopt::data::setids
# e.g.) _zetopt::data::setids
# STDOUT: string separated with \n
_zetopt::data::setids()
{
    <<< "$_ZETOPT_PARSED" \grep -E ':[1-9][0-9]*$' | \sed -e 's/:.*//'
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


#------------------------------------------------------------
# _zetopt::help
#------------------------------------------------------------
_zetopt::help::init()
{
    local IFS=$' '
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
    \printf -- "%s" "$(
        [[ -n ${ZSH_VERSION-} ]] \
        && \setopt localoptions NOCASEMATCH \
        || \shopt -s nocasematch
        local IFS=$LF
        [[ "$LF${_ZETOPT_HELPS_IDX[*]}$LF" =~ $LF([0-9]+):$title$LF ]] \
        && \printf -- "%s" ${BASH_REMATCH[$((1 + $INIT_IDX))]} \
        || \printf -- "%s" $ZETOPT_IDX_NOT_FOUND
    )"
}

_zetopt::help::body()
{
    local title="${1-}"
    local idx=$(_zetopt::help::search "$title")
    if [[ $idx != $ZETOPT_IDX_NOT_FOUND ]]; then
        \printf -- "%s\n" "${_ZETOPT_HELPS[$(($idx + $INIT_IDX))]}"
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
    local refidx=$(($idx + $INIT_IDX))
    _ZETOPT_HELPS_IDX[$refidx]="$idx:$title"
    shift 1
    local IFS=$''
    _ZETOPT_HELPS[$refidx]="$*"
}

_zetopt::help::rename()
{
    if [[ -z ${_ZETOPT_HELPS_IDX[@]-} ]]; then
        _zetopt::help::init
    fi
    if [[ $# -ne 2 || -z ${1-} || -z ${2-} ]]; then
        _zetopt::msg::debug "Usage:" "zetopt def-help --rename <OLD_TITLE> <NEW_TITLE>"
        return 1
    fi
    local oldtitle="$1"
    local newtitle="$2"
    local idx=$(_zetopt::help::search "$oldtitle")
    if [[ $idx == $ZETOPT_IDX_NOT_FOUND ]]; then
        _zetopt::msg::debug "No Such Help Title: $oldtitle"
        return 1
    fi
    if [[ $(_zetopt::help::search "$newtitle") -ne $ZETOPT_IDX_NOT_FOUND ]]; then
        _zetopt::msg::debug "Already Exists: $newtitle"
        return 1
    fi
    local refidx=$(($idx + $INIT_IDX))
    _ZETOPT_HELPS_IDX[$refidx]="$idx:$newtitle"
}

_zetopt::help::show()
{
    if [[ -z ${_ZETOPT_HELPS_IDX[@]-} ]]; then
        _zetopt::help::init
    fi
    declare -i idx_name=0 idx_synopsis=3 idx_options=5 idx_commands=6 idx=0
    declare -i _TERM_MAX_COLS=$(($(\tput cols) - 3))
    declare -i default_max_cols=120
    declare -i _MAX_COLS=$(_zetopt::utils::min $_TERM_MAX_COLS $default_max_cols)
    declare -i _BASE_COLS=0
    declare -i _OPT_COLS=4
    declare -i _OPT_DESC_MARGIN=2
    declare -i _INDENT_STEP=4
    declare -i _INDENT_LEVEL=0
    local _DECORATION=false
    local IFS body bodyarr title titles cols indent_cnt deco_title
    local _DECO_BOLD= _DECO_END=
    if _zetopt::msg::should_decorate $FD_STDOUT; then
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
        _zetopt::msg::debug "Usage:" "zetopt show-help [--lang <LANG>] [HELP_TITLE ...]"
        return 1
    fi
    IFS=$' '
    if [[ -z "${titles[@]-}" ]]; then
        titles=("${_ZETOPT_HELPS_IDX[@]#*:}")
    fi
    IFS=$LF
    
    for title in "${titles[@]}"
    do
        idx=$(_zetopt::help::search "$title")
        if [[ $idx -eq $ZETOPT_IDX_NOT_FOUND || -z "${_ZETOPT_HELPS[$(($idx + $INIT_IDX))]-}" ]]; then
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
            body="${_ZETOPT_HELPS[$(($idx + $INIT_IDX))]}"
            _zetopt::help::general "$title" "$body"
        fi
    done
}

_zetopt::help::general()
{
    local title="${1-}"
    local body="${2-}"
    \printf -- "$(_zetopt::help::indent)%b\n" "$_DECO_BOLD$title$_DECO_END"
    _INDENT_LEVEL+=1
    declare -i indent_cnt=$((_BASE_COLS + _INDENT_STEP * _INDENT_LEVEL))
    declare -i cols=$_MAX_COLS-$indent_cnt
    \printf -- "%b\n" "$body" | _zetopt::utils::fold --width $cols --indent $indent_cnt --lang "$_HELP_LANG"
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
    \printf -- "%${count}s" ""
}

_zetopt::help::synopsis()
{
    local title="${1-}"
    local IFS=$LF app="$ZETOPT_CALLER_NAME"
    local ns cmd has_arg has_arg_req has_opt has_sub line args bodyarr
    declare -i idx loop cmdcol
    local did_output=false
    local nslist
    nslist=($(_zetopt::def::namespaces))
    if [[ ${#nslist} -eq 0 ]]; then
        return 0
    fi

    \printf -- "$(_zetopt::help::indent)%b\n" "$_DECO_BOLD$title$_DECO_END"
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
            cmd=$(IFS=$' '; \printf -- "$_DECO_BOLD%s$_DECO_END " $cmd)
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
            bodyarr=($(\printf -- "%b" "$line" | _zetopt::utils::fold --width $cols --lang "$_HELP_LANG"))
            \printf -- "$base_indent%b\n" "$cmd ${bodyarr[$INIT_IDX]# *}"
            if [[ ${#bodyarr[@]} -gt 1 ]]; then
                if [[ $ZETOPT_OLDBASH == true ]]; then
                    unset bodyarr[0]
                    \printf -- "$cmd_indent%b\n" "${bodyarr[@]}"
                else
                    \printf -- "$cmd_indent%b\n" "${bodyarr[@]:1}"
                fi
            fi
            line="--$args"
        done | _zetopt::help::decorate --synopsis
    done

    if [[ $did_output == false ]]; then
        \printf -- "$(_zetopt::help::indent)%b\n" "$_DECO_BOLD$app$_DECO_END"
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
    local IFS=$LF ns="${1-}" line
    for line in $(_zetopt::def::options "$ns")
    do
        \printf -- "[%s] " "$(_zetopt::help::format --synopsis "$line")"
    done
}

_zetopt::help::fmtcmdopt()
{
    local title="${1-}"
    local subcmd_mode=$([[ ${2-} == "--commands" ]] && echo true || echo false)
    local id tmp desc optarg cmd helpidx cmdhelpidx arghelpidx optlen subcmd_title
    local nslist ns prev_ns=/
    local incremented=false did_output=false
    local IFS=$LF indent
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
                \printf -- "$(_zetopt::help::indent)%b\n" "$_DECO_BOLD$title$_DECO_END"
                _INDENT_LEVEL+=1
            fi

            helpidx=${line##*:}
            cmdhelpidx=0
            arghelpidx=0

            # sub-command
            if [[ $id =~ /$ ]]; then
                cmdhelpidx=${helpidx% *}
                arghelpidx=${helpidx#* }
                helpidx=$arghelpidx
                cmd="${id:1:$((${#id}-2))}"
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
                subcmd_title=$(IFS=$' '; \printf -- "$sub_title_deco%s$_DECO_END " $cmd)
                \printf -- "$(_zetopt::help::indent)%b\n" "$subcmd_title"
                _INDENT_LEVEL+=1
                prev_ns=$ns
                incremented=true

                if [[ $cmdhelpidx -ne 0 ]]; then
                    # calc rest cols
                    indent_cnt=$((_BASE_COLS + _INDENT_STEP * _INDENT_LEVEL))
                    cols=$_MAX_COLS-$indent_cnt
                    \printf -- "%b\n" "$(<<<"${_ZETOPT_OPTHELPS[$cmdhelpidx]}" _zetopt::utils::fold --width $cols --indent $indent_cnt --lang "$_HELP_LANG")"
                    \printf -- "%s\n" " "
                fi

                # no arg: sub-command itself
                if [[ $optlen == $cmdcol ]]; then
                    continue
                fi
                cmd=$(IFS=$' '; \printf -- "$sub_deco%s$_DECO_END " $cmd)
            fi

            optarg="$cmd${optarg# }"

            # calc rest cols
            indent_count=$((_BASE_COLS + _OPT_COLS + _OPT_DESC_MARGIN + _INDENT_STEP * _INDENT_LEVEL))
            indent=$(\printf -- "%${indent_count}s" "")
            cols=$(($_MAX_COLS - $indent_count))
            if [[ $helpidx -ne 0 ]]; then
                desc=($(\printf -- "%b" "${_ZETOPT_OPTHELPS[$helpidx]}" | _zetopt::utils::fold --width $cols --lang "$_HELP_LANG"))
            fi
            if [[ $optlen -le $(($_OPT_COLS)) ]]; then
                \printf -- "$(_zetopt::help::indent)%-$(($_OPT_COLS + $_OPT_DESC_MARGIN))s%s\n" "$optarg" "${desc[$((0 + $INIT_IDX))]}"
                if [[ ${#desc[@]} -gt 1 ]]; then
                    if [[ $ZETOPT_OLDBASH == true ]]; then
                        \unset desc[0]
                        \printf -- "$indent%s\n" "${desc[@]}"
                    else
                        \printf -- "$indent%s\n" "${desc[@]:$((1 + $INIT_IDX))}"
                    fi
                fi
            else
                \printf -- "$(_zetopt::help::indent)%s\n" "$optarg"
                if [[ -n "${desc[@]}" ]]; then
                    \printf -- "$indent%s\n" "${desc[@]}"
                fi
            fi
            \printf -- "%s\n" " "
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
    local id short long args dummy opt optargs default_argname
    local sep=", " synopsis=false
    if [[ ${1-} == "--synopsis" ]]; then
        synopsis=true
        sep="|"
        shift
    fi
    local IFS=:
    \set -- ${1-}
    id=${1-}
    short=${2-}
    long=${3-}
    args=${4-}
    IFS=$LF
    
    if [[ $id =~ /$ ]]; then
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
        IFS=$' '
        declare -i cnt=1
        local arg param default_idx default_value=
        for arg in $args
        do
            param=${arg%%.*}
            default_idx=${arg#*=}
            default_value=
            if [[ $default_idx -ne 0 ]]; then
                default_value="=${_ZETOPT_DEFAULTS[$default_idx]}"
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
            optargs="${optargs:0:$((${#optargs} - 1))}${BASH_REMATCH[$((1 + INIT_IDX))]}]"
        fi
        IFS=$LF
    fi
    \printf -- "%b" "$optargs"
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


