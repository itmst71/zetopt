#------------------------------------------------
# Variables
#------------------------------------------------
# app info
declare -r ZETOPT_APPNAME="zetopt"
declare -r ZETOPT_VERSION="1.2.0a (2018-12-31 12:00)"

# field numbers for definition
declare -r ZETOPT_FIELD_DEF_ALL=0
declare -r ZETOPT_FIELD_DEF_ID=1
declare -r ZETOPT_FIELD_DEF_SHORT=2
declare -r ZETOPT_FIELD_DEF_LONG=3
declare -r ZETOPT_FIELD_DEF_ARG=4
declare -r ZETOPT_FIELD_DEF_HELP=5

# field numbers for parsed data
declare -r ZETOPT_FIELD_DATA_ALL=0
declare -r ZETOPT_FIELD_DATA_ID=1
declare -r ZETOPT_FIELD_DATA_SHORT=2
declare -r ZETOPT_FIELD_DATA_LONG=3
declare -r ZETOPT_FIELD_DATA_ARG=4
declare -r ZETOPT_FIELD_DATA_TYPE=5
declare -r ZETOPT_FIELD_DATA_STATUS=6
declare -r ZETOPT_FIELD_DATA_COUNT=7

# types
declare -r ZETOPT_TYPE_CMD=0
declare -r ZETOPT_TYPE_SHORT=1
declare -r ZETOPT_TYPE_LONG=2
declare -r ZETOPT_TYPE_PLUS=3

# parse status
declare -r ZETOPT_STATUS_NORMAL=0
declare -r ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS=$((1 << 0))
declare -r ZETOPT_STATUS_MISSING_OPTIONAL_ARGS=$((1 << 1))
declare -r ZETOPT_STATUS_TOO_MATCH_ARGS=$((1 << 2))
declare -r ZETOPT_STATUS_MISSING_REQUIRED_OPTARGS=$((1 << 3))
declare -r ZETOPT_STATUS_MISSING_REQUIRED_ARGS=$((1 << 4))
declare -r ZETOPT_STATUS_UNDEFINED_OPTION=$((1 << 5))
declare -r ZETOPT_STATUS_UNDEFINED_SUBCMD=$((1 << 6))
declare -r ZETOPT_STATUS_INVALID_OPTFORMAT=$((1 << 7))

# misc
declare -r ZETOPT_IDX_NOT_FOUND=-1

# caller
if [[ -n ${ZSH_VERSION-} ]]; then
    _caller=${funcfiletrace%:*}
else
    _caller=$0
fi
declare -r ZETOPT_CALLER_NAME=${_caller##*/}
\unset _caller

# self file path
declare -r ZETOPT_SOURCE_FILE_PATH="${BASH_SOURCE:-$0}"

# config
export ZETOPT_CFG_VALUE_IFS=$'\n'
export ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN=false
export ZETOPT_CFG_CLUSTERED_AS_LONG=false
export ZETOPT_CFG_IGNORE_BLANK_STRING=false
export ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR=false
export ZETOPT_CFG_OPTTYPE_PLUS=false
export ZETOPT_CFG_FLAGVAL_TRUE=0
export ZETOPT_CFG_FLAGVAL_FALSE=1
export ZETOPT_CFG_ERRMSG=true
export ZETOPT_CFG_ERRMSG_APPNAME=$ZETOPT_CALLER_NAME
export ZETOPT_CFG_ERRMSG_COL_MODE=auto
export ZETOPT_CFG_ERRMSG_COL_DEFAULT="0;0;39"
export ZETOPT_CFG_ERRMSG_COL_ERROR="0;1;31"
export ZETOPT_CFG_ERRMSG_COL_WARNING="0;0;33"
export ZETOPT_CFG_ERRMSG_COL_SCRIPTERR="0;1;31"
export ZETOPT_CFG_HELP_INDENT_SPACES=4


#------------------------------------------------
# Main
#------------------------------------------------
# zetopt {SUB-COMMAND} [ARGS]
# STDOUT: depending on each sub-commands
zetopt()
{
    local PATH="/usr/bin:/bin"
    local IFS=$' \t\n'
    local LC_ALL=C LANG=C

    # setup for zsh
    if [[ -n ${ZSH_VERSION-} ]]; then
        if [[ $'\n'$(\setopt) =~ $'\n'ksharrays ]]; then
            declare -r IDX_OFFSET=0
        else
            declare -r IDX_OFFSET=1
        fi
        \setopt localoptions SH_WORD_SPLIT
        \setopt localoptions BSD_ECHO
        \setopt localoptions NO_NOMATCH
        \setopt localoptions GLOB_SUBST
        \setopt localoptions NO_EXTENDED_GLOB
        \setopt localoptions BASH_REMATCH
    else
        declare -r IDX_OFFSET=0
    fi

    # save whether the stderr of the main function is TTY or not.
    if [[ -t 2 ]]; then
        declare -r TTY_STDERR=0
    else
        declare -r TTY_STDERR=1
    fi

    # show help if subcommand not given
    if [[ $# -eq 0 ]]; then
        _zetopt::help::selfhelp short
        return 1
    fi

    local _COMMAND_LINE
    _COMMAND_LINE=("$@")
    
    local subcmd="$1"
    \shift

    case "$subcmd" in
        -v | --version)
            \echo $ZETOPT_APPNAME $ZETOPT_VERSION;;
        -h | --help)
            _zetopt::selfhelp::show;;
        init)
            ZETOPT_DEFINED=
            _ZETOPT_DEFINED_LIST=()
            _ZETOPT_ID_LIST=()
            _ZETOPT_OPTHELPS=()
            _ZETOPT_HELPS_IDX=()
            _ZETOPT_HELPS=()

            ZETOPT_PARSED=
            _ZETOPT_PARSED_LIST=()
            ZETOPT_OPTVALS=()
            ZETOPT_ARGS=()

            ZETOPT_PARSE_ERRORS=$ZETOPT_STATUS_NORMAL
            ZETOPT_OPTERR_INVALID=()
            ZETOPT_OPTERR_UNDEFINED=()
            ZETOPT_OPTERR_MISSING_REQUIRED=()
            ZETOPT_OPTERR_MISSING_OPTIONAL=()
            ;;
        reset)
            _zetopt::parser::init
            _zetopt::def::init
            _zetopt::data::init
            ;;
        define | def)
            _zetopt::def::define "${@-}";;
        defined)
            _zetopt::def::defined "${@-}";;
        defined-field)
            _zetopt::def::get "${@-}";;
        load)
            _zetopt::def::load "${@-}";;
        parse)
            # for supporting blank string argument
            if [[ $# -eq 0 ]]; then
                _zetopt::parser::parse
            else
                _zetopt::parser::parse "${@-}"
            fi
            ;;
        parsed)
            _zetopt::data::parsed "${@-}";;
        define-help | def-help)
            _zetopt::help::define "${@-}";;
        show-help)
            _zetopt::help::show "${@-}";;
        show-option-help)
            _zetopt::help::single_opthelp "${@-}";;
        isset)
            _zetopt::data::isset "${@-}";;
        isok)
            _zetopt::data::isok "${@-}";;
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
        *)
            _zetopt::utils::script_error "Undefined Sub-Command:" "$subcmd"
            return 1;;
    esac
}


#------------------------------------------------
# _zetopt::def
#------------------------------------------------

# Define options. 
# ** Must be executed in the current shell **
# def.) _zetopt::def::define {DEFINITION-STRING}
# e.g.) _zetopt::def::define "ver:v:version"
# STDOUT: NONE
_zetopt::def::define()
{
    if [[ -z ${ZETOPT_DEFINED:-} ]]; then
        ZETOPT_DEFINED="/:::0"$'\n'
        _ZETOPT_OPTHELPS=("")
    fi

    local IFS=$' ' origin="$*" lines=
    IFS=$';\n'
    lines=($origin)
    if [[ ${#lines[@]} -eq 0 ]]; then
        _zetopt::utils::script_error "No Definition Given"
        return 1
    fi

    local line namespace id short long namedef paramdef helpdef helpidx global arr
    for line in "${lines[@]}"
    do 
        namespace= id= short= long= namedef= paramdef= helpidx=0 helpdef= global=
        if [[ -z ${line//[$' \t']/} ]]; then
            continue
        fi

        # help
        IFS=$''
        if [[ $line =~ \ \# ]]; then
            helpdef="${line#*\ #}"
            line=${line%%\ #*}
        fi

        IFS=$' '
        \read line <<< "$line" #trim

        # only parameters
        if [[ $line =~ ^-{0,2}[@%] ]]; then
            line="/ $line"
        fi

        namedef="${line%% *}"
        paramdef="${line#* }"

        # no parameter definition
        if [[ $namedef == $paramdef ]]; then
            paramdef=
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
        if [[ $# -gt 3 ]]; then
            _zetopt::utils::script_error "Invalid Definition:" "$line"
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
            _zetopt::utils::script_error "Invalid Definition:" "$line"
            return 1
        fi

        if [[ ! $id =~ ^(/([a-zA-Z0-9_]+)?|^(/[a-zA-Z0-9_]+(-[a-zA-Z0-9_]+)*)+/([a-zA-Z0-9_]+)?)$ ]]; then
            _zetopt::utils::script_error "Invalid Identifier:" "$id"
            return 1
        fi

        # namespace(subcommand) definition
        if [[ $id == $namespace ]]; then
            if [[ -n $global ]]; then
                _zetopt::utils::script_error "Sub-Command Difinition with Global Option Sign +:" "$line"
                return 1
            fi

            # remove the existing subcommand definition
            IFS=$'\n'
            local tmp_line= tmp_defined=
            for tmp_line in $ZETOPT_DEFINED
            do
                if [[ $tmp_line =~ ^${id}: ]]; then
                    continue
                fi
                tmp_defined="$tmp_defined$tmp_line"$'\n'
            done
            ZETOPT_DEFINED=$tmp_defined
        fi
        
        if [[ $'\n'$ZETOPT_DEFINED =~ $'\n'${id}[+]?: ]]; then
            _zetopt::utils::script_error "Duplicated Identifier:" "$1"
            return 1
        fi

        \shift

        # options
        if [[ $line =~ : ]]; then
            IFS=,
            \set -- $*

            while [[ $# -ne 0 ]]
            do
                if [[ -z $1 ]]; then
                    \shift
                    continue
                fi
                
                # short option
                if [[ ${#1} -eq 1 ]]; then
                    if [[ -n $short ]]; then
                        _zetopt::utils::script_error "2 Short Options at once:" "$1"
                        return 1
                    fi

                    if [[ ! $1 =~ ^[a-zA-Z0-9_]$ ]]; then
                        _zetopt::utils::script_error "Invalid Short Option Name:" "$1"
                        return 1
                    fi
                    
                    # subcommand scope option
                    if [[ $'\n'$ZETOPT_DEFINED =~ $'\n'${namespace}[a-zA-Z0-9_]*[+]?:$1: ]]; then
                        _zetopt::utils::script_error "Already Defined:" "-$1 : $line"
                        return 1
                    fi
                    short=$1

                # long option
                else
                    if [[ -n $long ]]; then
                        _zetopt::utils::script_error "2 Long Options at once:" "$1"
                        return 1
                    fi

                    if [[ ! $1 =~ ^[a-zA-Z0-9_]+(-[a-zA-Z0-9_]*)*$ ]]; then
                        _zetopt::utils::script_error "Invalid Long Option Name:" "$1"
                        return 1
                    fi

                    # subcommand scope option
                    if [[ $'\n'$ZETOPT_DEFINED =~ $'\n'${namespace}[a-zA-Z0-9_]*[+]?:[^:]?:$1: ]]; then
                        _zetopt::utils::script_error "Already Defined:" "--$1"
                        return 1
                    fi
                    long=$1
                fi
                \shift
            done

            # no short nor long
            if [[ -z $short$long ]]; then
                return 1
            fi
        fi

        # parameters
        if [[ -n $paramdef ]]; then
            IFS=$' ' read paramdef <<< "$paramdef" # trim spaces
            
            if [[ ! $paramdef =~ ^(\ *-{0,2}[@%]([a-zA-Z_][a-zA-Z0-9_]*)?([.]{3,3}([1-9][0-9]*)*)?)+$ ]]; then
                _zetopt::utils::script_error "Invalid Parameter Definition:" "$paramdef"
                return 1

            elif [[ ${paramdef//[\ .-]/} =~ ^%+@ ]]; then
                _zetopt::utils::script_error "Required Parameter after Optional:" "$paramdef"
                return 1

            elif [[ $paramdef =~ [.]{3,3} && ! ${paramdef//[\ -]/} =~ [%@][a-zA-Z0-9_]*[.]{3,3}([1-9][0-9]*)*$ ]]; then
                _zetopt::utils::script_error "Variable-length parameter must be at the last:" "$paramdef"
                return 1
            fi

            # check if parameter names are duplicated
            if [[ $paramdef =~ [a-zA-Z0-9_] ]]; then
                local paramnames= paramname=
                IFS=$' '
                set -- ${paramdef//[@%-.]/}
                if [[ $# -ge 1 ]]; then
                    for paramname in $@
                    do
                        if [[ \ $paramnames\  =~ \ $paramname\  ]]; then
                            _zetopt::utils::script_error "Duplicated Parameter Name:" "$paramdef"
                            return 1
                        fi
                        paramnames="$paramnames $paramname "
                    done
                fi
            fi
            IFS=$' '
            \set -- $paramdef
            paramdef="$*"
        fi

        if [[ -n "$helpdef" ]]; then
            _ZETOPT_OPTHELPS+=("$helpdef")
            helpidx=$((${#_ZETOPT_OPTHELPS[@]} - 1 + $IDX_OFFSET))
        fi

        line="$id$global:$short:$long:$paramdef:$helpidx"
        ZETOPT_DEFINED="$ZETOPT_DEFINED$line"$'\n'

        # defines parent subcommands automatically
        if [[ $namespace == / ]]; then
            [[ $'\n'$ZETOPT_DEFINED =~ $'\n'/: ]] && continue
            ZETOPT_DEFINED="$ZETOPT_DEFINED/:::0"$'\n'
            continue
        fi

        IFS=$' '
        local ns= curr_ns=
        for ns in ${namespace//\// }
        do
            curr_ns="${curr_ns%*/}/$ns/"
            [[ $'\n'$ZETOPT_DEFINED =~ $'\n'$curr_ns: ]] && continue
            ZETOPT_DEFINED="$ZETOPT_DEFINED$curr_ns:::0"$'\n'
        done
    done
}

# Initialize variables concerned with the definition. 
# ** Must be executed in the current shell **
# def.) _zetopt::def::init
# STDOUT: NONE
_zetopt::def::init()
{
    if [[ -z ${ZETOPT_DEFINED+_} ]]; then
        return 1
    fi
    ZETOPT_DEFINED=$(<<< "$ZETOPT_DEFINED" \sort -t : -k 1,1 | \sed '/^$/d') 
    local IFS=$'\n' line=
    _ZETOPT_DEFINED_LIST=($ZETOPT_DEFINED)
    _ZETOPT_ID_LIST=()
    for line in ${ZETOPT_DEFINED//+/} # remove global signs
    do
        IFS=:
        \set -- $line
        _ZETOPT_ID_LIST+=($1)
    done
}

# Load definition data from a file.
# def.) _zetopt::def::load {FILE-PATH}
# e.g.) _zetopt::def::load option.txt
# STDOUT: NONE
_zetopt::def::load()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    if [[ ! -f $1 ]]; then
        _zetopt::utils::script_error "No Such File:" "$1"
        return 1
    fi

    ZETOPT_DEFINED=$(cat "${1-}")
}

# Print the defined data. Print all if ID not given.
# def.) _zetopt::def::defined [ID]
# STDOUT: strings separated with $'\n'
_zetopt::def::defined()
{
    if [[ ${#_ZETOPT_DEFINED_LIST[@]} -eq 0 ]]; then
        _zetopt::def::init
    fi
    if [[ -z ${1-} ]]; then
        \echo "${ZETOPT_DEFINED-}"
        return 0
    fi
    _zetopt::def::get "$1" $ZETOPT_FIELD_DEF_ALL
}

# Search and print the definition.
# def.) _zetopt::def::get {ID} [FIELD-DEF-NUMBER-TO-PRINT]
# e.g.) _zetopt::def::get /foo $ZETOPT_FIELD_DEF_ARG
# STDOUT: string
_zetopt::def::get()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if ! _zetopt::def::idexist "$id"; then
        return 1
    fi
    local ididx=$(_zetopt::def::ididx "$id")
    if [[ $ididx == $ZETOPT_IDX_NOT_FOUND ]]; then
        return 1
    fi
    local field="${2:-$ZETOPT_FIELD_DEF_ALL}"

    local line="${_ZETOPT_DEFINED_LIST[$ididx]}"
    if [[ $field == $ZETOPT_FIELD_DEF_ALL ]]; then
        \echo "$line"
    else
        if [[ $field =~ [^0-9] ]]; then
            return 1
        fi
        IFS=:
        \set -- $line
        \eval echo '"${'$field'-}"'
    fi
}

# Check if the ID exists
# def.) _zetopt::def::idexist {ID}
# e.g.) _zetopt::def::idexist /foo
# STDOUT: NONE
_zetopt::def::idexist()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id=/$id
    [[ $'\n'$ZETOPT_DEFINED =~ $'\n'${id}[+]?: ]]
}

# Check if the current namespace has subcommands
# def.) _zetopt::def::has_subcmd {NAMESPACE}
# e.g.) _zetopt::def::has_subcmd /sub/
# STDOUT: NONE
_zetopt::def::has_subcmd()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1" && [[ ! $ns =~ ^/ ]] && ns=/$ns
    [[ $'\n'$ZETOPT_DEFINED =~ $'\n'${ns}[a-zA-Z0-9_-]+/ ]]
}

# Print the index of the specified ID to refer 
# def.) _zetopt::def::ididx {ID}
# e.g.) _zetopt::def::ididx /foo
# STDOUT: an integer
_zetopt::def::ididx()
{
    if [[ -z ${1-} ]]; then
        \echo $ZETOPT_IDX_NOT_FOUND
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id=/$id

    # binary search
    local min=$IDX_OFFSET max=$((${#_ZETOPT_ID_LIST[@]} + $IDX_OFFSET)) mid=-1
    while :
    do
        if [[ $max -lt $min ]]; then
            \echo $ZETOPT_IDX_NOT_FOUND
            return 1
        else
            mid=$((min + (max - min) / 2))
            if [[ ${_ZETOPT_ID_LIST[$mid]} > $id ]]; then
                max=$((mid - 1))
                continue
            elif [[ ${_ZETOPT_ID_LIST[$mid]} < $id ]]; then
                min=$((mid + 1))
                continue
            else
                \echo $mid
                return 0
            fi
        fi
    done
    \echo $ZETOPT_IDX_NOT_FOUND
    return 1
}

# Check if the option exists in some namespace. This works faster.
# def.) _zetopt::def::optexist {OPTION-NAME}
# e.g.) _zetopt::def::optexist version
# STDOUT: NONE
_zetopt::def::optexist()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    if [[ ${#1} -eq 1 ]]; then
        [[ $'\n'$ZETOPT_DEFINED =~ $'\n'[^:]+:$1: ]]
    else
        [[ $'\n'$ZETOPT_DEFINED =~ $'\n'[^:]+:[^:]?:$1: ]]
    fi
}

# Print the index of the definition by searching with a namespace and a option name.
# If not found in the current namespace, search a global option in parent namespaces.
# def.) _zetopt::def::nsoptidx {NAMESPACE} {OPTION-NAME}
# e.g.) _zetopt::def::nsoptidx /remote/add/ version
# STDOUT: an integer
_zetopt::def::nsoptidx()
{
    local ns="${1-}" opt="${2-}"
    if [[ -z $ns || -z $opt ]]; then
        \echo $ZETOPT_IDX_NOT_FOUND
        return 1
    fi
    if ! _zetopt::def::optexist "$opt" ; then
        \echo $ZETOPT_IDX_NOT_FOUND
        return 1
    fi

    local regex= regex_tmp= global="[+]?"
    while true
    do
        if [[ ${#opt} -eq 1 ]]; then
            regex_tmp="${ns}[a-zA-Z0-9_]+${global}:$opt:"
        else
            regex_tmp="${ns}[a-zA-Z0-9_]+${global}:[^:]?:$opt:"
        fi
        if [[ $'\n'$ZETOPT_DEFINED =~ $'\n'$regex_tmp ]]; then
            regex=$regex_tmp
            \break
        fi
        if [[ $ns == / ]]; then
            \echo $ZETOPT_IDX_NOT_FOUND
            return 1
        fi
        ns=${ns%/*}  # remove the last /
        ns=${ns%/*}/ # parent ns
        global="[+]"
    done

    local line= ididx=$IDX_OFFSET
    for line in "${_ZETOPT_DEFINED_LIST[@]}"
        do
        if [[ $line =~ ^$regex ]]; then
            \echo $ididx
            return 0
        fi
        : $((ididx++))
    done

    \echo $ZETOPT_IDX_NOT_FOUND
    return 1
}

# Print the index of the specified parameter name
# def.) _zetopt::def::paramidx {ID} {PARAM-NAME}
# e.g.) _zetopt::def::paramidx /foo name
# STDOUT: an integer
_zetopt::def::paramidx()
{
    if [[ $# -lt 2 ]]; then
        return 1
    fi
    if [[ ! $2 =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*-?$ ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    local paramdef_str="$(_zetopt::def::get "$id" $ZETOPT_FIELD_DEF_ARG)"
    if [[ -z $paramdef_str ]]; then
        return 1
    fi
    local name=${2//-/}

    local IFS=$' ' def= defidx=$IDX_OFFSET
    for def in $paramdef_str
    do
        if [[ ${def//[-@%.]/} == $name ]]; then
            \echo $defidx
            return 0
        fi
        : $((defidx++))
    done
    return 1
}

# Print the length of parameters
# def.) _zetopt::def::paramlen {ID} [all | required | @ | optional | % | max]
# e.g.) _zetopt::def::paramlen /foo required
# STDOUT: an integer
_zetopt::def::paramlen()
{
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    local paramdef_str="$(_zetopt::def::get "$id" $ZETOPT_FIELD_DEF_ARG)"
    if [[ -z $paramdef_str ]]; then
        \echo 0
        return 0
    fi

    local tmp= reqcnt= optcnt= out=
    tmp=${paramdef_str//[!@]/}
    reqcnt=${#tmp} 
    tmp=${paramdef_str//[!%]/}
    optcnt=${#tmp}

    case ${2-} in
        required | @)
                out=$reqcnt;;
        optional | %)
                out=$optcnt;;
        max)
            if [[ ! $paramdef_str =~ [.]{3,3}([1-9][0-9]*)*$ ]]; then
                out=$((reqcnt + optcnt))
            elif [[ $paramdef_str =~ [.]{3,3}$ ]]; then
                out=$((1<<31))
            elif [[ $paramdef_str =~ [.]{3,3}([1-9][0-9]*)$ ]]; then
                out=$((reqcnt + optcnt + ${paramdef_str##*...} - 1))
            fi
            ;;
        "" | all)
                out=$((reqcnt + optcnt));;
        *)      
                out=$((reqcnt + optcnt));;
    esac
    \echo $out
}

#------------------------------------------------
# _zetopt::parser
#------------------------------------------------

# Initialize variables concerned with the parser. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::init
# STDOUT: NONE
_zetopt::parser::init()
{
    ZETOPT_OPTERR_INVALID=()
    ZETOPT_OPTERR_MISSING_REQUIRED=()
    ZETOPT_OPTERR_UNDEFINED=()
    ZETOPT_OPTERR_MISSING_OPTIONAL=()
    ZETOPT_PARSE_ERRORS=$ZETOPT_STATUS_NORMAL
}

# Parse arguments. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::parse {ARGUMENTS}
# e.g.) _zetopt::parser::parse "$@"
# STDOUT: NONE
_zetopt::parser::parse()
{
    if [[ -z ${ZETOPT_DEFINED:-} ]]; then
        ZETOPT_DEFINED="/:::"$'\n'
    fi
    _zetopt::parser::init
    _zetopt::def::init
    _zetopt::data::init
    
    local optname= optarg= idx= optsign= added_cnt=0 args
    local namespace=/ ns= check_subcmd=true error_subcmd_name=
    
    # internal global variables
    local _CONSUMED_ARGS_COUNT=0
    local _ZETOPT_CFG_CLUSTERED_AS_LONG="$(_zetopt::utils::is_true --stdout "${ZETOPT_CFG_CLUSTERED_AS_LONG-}")"
    local _ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN="$(_zetopt::utils::is_true --stdout "${ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN-}")"
    local _ZETOPT_CFG_IGNORE_BLANK_STRING="$(_zetopt::utils::is_true --stdout "${ZETOPT_CFG_IGNORE_BLANK_STRING-}")"
    local _ZETOPT_CFG_OPTTYPE_PLUS="$(_zetopt::utils::is_true --stdout "${ZETOPT_CFG_OPTTYPE_PLUS-}")"
    local _ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR="$(_zetopt::utils::is_true --stdout "${ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR-}")"

    if ! _zetopt::parser::setsub $namespace; then
        _zetopt::utils::script_error "Invalid Definition Data:" "Root Namespace Not Found"
        return 1
    fi

    args=()
    while [[ $# -ne 0 ]]
    do
        _CONSUMED_ARGS_COUNT=0
        
        if [[ $1 == -- ]]; then
            if [[ $_ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN -ne 0 ]]; then
                \shift
                ZETOPT_ARGS+=("$@")
                \break
            else
                ZETOPT_ARGS+=("$1")
                \shift
            fi
            check_subcmd=false
        elif [[ $1 =~ ^[-+]$ ]]; then
            ZETOPT_ARGS+=("$1")
            \shift
            check_subcmd=false

        elif [[ $1 == "" ]]; then
            if [[ $_ZETOPT_CFG_IGNORE_BLANK_STRING -eq 0 ]]; then
                \shift
                continue
            fi
            ZETOPT_ARGS+=("$1")
            \shift
            check_subcmd=false
                
        # long option or clustered short options with ZETOPT_CFG_CLUSTERED_AS_LONG enabled
        elif [[ $1 =~ ^-- || ($_ZETOPT_CFG_CLUSTERED_AS_LONG -eq 0 && $1 =~ ^-[^-]. ) ]]; then
            if [[ ! $1 =~ ^--?[a-zA-Z0-9_] ]]; then
                ZETOPT_OPTERR_INVALID+=("$1")
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_INVALID_OPTFORMAT))
                \shift
                check_subcmd=false
            fi

            if [[ $1 =~ ^-[^-]. && $_ZETOPT_CFG_CLUSTERED_AS_LONG -eq 0 ]]; then
                optsign=-
            else
                optsign=--
            fi
            

            if [[ $1 =~ = ]]; then
                optarg="${1#*=}"
                optname="${1%%=*}"
                optname="${optname#*${optsign}}"
                if [[ -z $optname ]]; then
                    ZETOPT_OPTERR_INVALID+=("$1")
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_INVALID_OPTFORMAT))
                    \shift
                    check_subcmd=false
                    continue
                fi

                added_cnt=1
                \shift
                _zetopt::parser::setopt $namespace $optsign $optname "$optarg" "$@" ||:
            else
                optname="${1#*${optsign}}"
                \shift
                _zetopt::parser::setopt $namespace $optsign $optname "$@" ||:
            fi
            check_subcmd=false

        # short option(s)
        elif [[ $1 =~ ^- ]]; then
            if [[ $1 =~ = ]]; then
                optarg="${1#*=}"
                optname="${1%%=*}"
                optname="${optname##*-}"
                if [[ -z $optname ]]; then
                    ZETOPT_OPTERR_INVALID+=("$1")
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_INVALID_OPTFORMAT))
                    \shift
                    check_subcmd=false
                    continue
                fi
                added_cnt=1
            else
                optname="${1#*-}"
            fi
            \shift

            for ((idx=0; idx<$((${#optname} - 1)); idx++))
            do
                _zetopt::parser::setopt $namespace - ${optname:$idx:1} ||:
            done
            if [[ $added_cnt -eq 0 ]]; then
                _zetopt::parser::setopt $namespace - ${optname:$idx:1} "$@" ||:
            else
                _zetopt::parser::setopt $namespace - ${optname:$idx:1} "$optarg" "$@" ||:
            fi
            check_subcmd=false

        # short option(s) with + optsign
        elif [[ $1 =~ ^[+] && $_ZETOPT_CFG_OPTTYPE_PLUS -eq 0 ]]; then
            if [[ ! $1 =~ ^[+][a-zA-Z0-9_] ]]; then
                ZETOPT_OPTERR_INVALID+=("$1")
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_INVALID_OPTFORMAT))
                \shift
                check_subcmd=false
                continue
            fi

            if [[ $1 =~ = ]]; then
                optarg="${1#*=}"
                optname="${1%%=*}"
                optname="${optname##*+}"
                if [[ -z $optname ]]; then
                    ZETOPT_OPTERR_INVALID+=("$1")
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_INVALID_OPTFORMAT))
                    \shift
                    check_subcmd=false
                    continue
                fi
                added_cnt=1
            else
                optname="${1#*+}"
            fi
            \shift

            for ((idx=0; idx<$((${#optname} - 1)); idx++))
            do
                _zetopt::parser::setopt $namespace + ${optname:$idx:1} ||:
            done
            if [[ $added_cnt -eq 0 ]]; then
                _zetopt::parser::setopt $namespace + ${optname:$idx:1} "$@" ||:
            else
                _zetopt::parser::setopt $namespace + ${optname:$idx:1} "$optarg" "$@" ||:
            fi
            check_subcmd=false

        # positional argument or subcommand
        else
            # subcommand
            if [[ $check_subcmd == true ]] && _zetopt::def::has_subcmd "$namespace"; then
                ns="${namespace%/*}/$1/"
                if [[ ! $ns =~ ^(/([a-zA-Z0-9_]+)?|^(/[a-zA-Z0-9_]+(-[a-zA-Z0-9_]+)*)+/([a-zA-Z0-9_]+)?)$ || -z $(_zetopt::def::get "$ns") ]]; then
                    check_subcmd=false
                    if [[ $_ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR -eq 0 ]]; then
                        ZETOPT_ARGS+=("$1")
                        \shift
                        continue
                    fi
                    error_subcmd_name="${ns//\// }"
                    _zetopt::utils::msg Error "Undefined Sub-Command:" "$error_subcmd_name"
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_SUBCMD))
                    \break
                fi

                # change namespace
                if _zetopt::parser::setsub $ns; then
                    namespace=$ns
                fi
                \shift
                continue
            fi

            # a regular positional argument
            ZETOPT_ARGS+=("$1")
            \shift
        fi

        # shift
        if [[ $(($_CONSUMED_ARGS_COUNT - $added_cnt)) -gt 0 ]]; then
            \shift $(($_CONSUMED_ARGS_COUNT - $added_cnt))
        fi
    done

    # assign positional args
    _zetopt::parser::assign_args "$namespace"
    
    # show errors
    if _zetopt::utils::is_true "${ZETOPT_CFG_ERRMSG-}"; then
        IFS=$' \t\n'
        local subcmdstr="${namespace//\// }" msg=

        # Undefined Options
        if [[ $(($ZETOPT_PARSE_ERRORS & $ZETOPT_STATUS_UNDEFINED_OPTION)) -ne 0 ]]; then
            msg=($subcmdstr $(<<< "${ZETOPT_OPTERR_UNDEFINED[*]}" \tr " " "\n" | \sort | \uniq))
            _zetopt::utils::msg Warning "Undefined Option(s):" "${msg[*]}"
        fi

        # Invalid Format Options
        if [[ $(($ZETOPT_PARSE_ERRORS & $ZETOPT_STATUS_INVALID_OPTFORMAT)) -ne 0 ]]; then
            msg=($subcmdstr $(<<< "${ZETOPT_OPTERR_INVALID[*]}" \tr " " "\n" | \sort | \uniq))
            _zetopt::utils::msg Error "Invalid Format Option(s):" "${msg[*]}"
        fi

        # Missing Required Option Arguments
        if [[ $(($ZETOPT_PARSE_ERRORS & $ZETOPT_STATUS_MISSING_REQUIRED_OPTARGS)) -ne 0 ]]; then
            msg=($subcmdstr $(<<< "${ZETOPT_OPTERR_MISSING_REQUIRED[*]}" \tr " " "\n" | \sort | \uniq))
            _zetopt::utils::msg Error "Missing Required Option Argument(s):" "${msg[*]}"
        fi

        # Missing Required Positional Arguments
        if [[ $(($ZETOPT_PARSE_ERRORS & $ZETOPT_STATUS_MISSING_REQUIRED_ARGS)) -ne 0 ]]; then
            msg=($subcmdstr "$(_zetopt::def::paramlen $namespace required) Argument(s) Required")
            _zetopt::utils::msg Error "Missing Required Argument(s):" "${msg[*]}"
        fi

        # Too Match Positional Arguments
        if [[ $(($ZETOPT_PARSE_ERRORS & $ZETOPT_STATUS_TOO_MATCH_ARGS)) -ne 0 ]]; then
            msg=($subcmdstr "Given ${#ZETOPT_ARGS[@]} Arguments (Up To "$(_zetopt::def::paramlen $namespace max)")")
            _zetopt::utils::msg Error "Too Match Arguments:" "${msg[*]}"
        fi
    fi

    IFS=$'\n'
    ZETOPT_PARSED="${_ZETOPT_PARSED_LIST[*]}"
    [[ $ZETOPT_PARSE_ERRORS -le $ZETOPT_STATUS_MISSING_OPTIONAL_ARGS ]]
    return $?
}

# Increment the set count of a sub-command. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::setsub {NAMESPACE}
# e.g.) _zetopt::parser::setsub /sub/
# STDOUT: NONE
_zetopt::parser::setsub()
{
    local ididx="$(_zetopt::def::ididx "${1-}")"
    if [[ $ididx == $ZETOPT_IDX_NOT_FOUND ]]; then
        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_SUBCMD))
        return $ZETOPT_STATUS_UNDEFINED_SUBCMD
    fi
    local line="${_ZETOPT_PARSED_LIST[$ididx]}"
    local IFS=:
    \set -- $line
    local cnt="$7"
    : $((cnt++))
    _ZETOPT_PARSED_LIST[$ididx]="$1:$2:$3:$4:$ZETOPT_TYPE_CMD:$ZETOPT_STATUS_NORMAL:$cnt"
}

# Set option data. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::setopt {NAMESPACE} {OPTSIGN} {OPTNAME} {ARGUMENTS}
# e.g.) _zetopt::parser::setopt /sub/cmd - version "$@"
# STDOUT: NONE
_zetopt::parser::setopt()
{
    local namespace="${1-}" optsign="${2-}" opt="${3-}" args
    \shift 3
    args=("$@")

    local ididx=$(_zetopt::def::nsoptidx "$namespace" "$opt")
    if [[ $ididx == $ZETOPT_IDX_NOT_FOUND ]]; then
        ZETOPT_OPTERR_UNDEFINED+=("$optsign$opt")
        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_OPTION))
        return 1
    fi

    local IFS=:
    \set -- ${_ZETOPT_PARSED_LIST[$ididx]}
    local id="$1" short="$2" long="$3" refsstr="$4" types="$5" stat="$6" cnt="$7"
    local curr_stat=$ZETOPT_STATUS_NORMAL

    local refs paramdef_str="$(_zetopt::def::get "$id" $ZETOPT_FIELD_DEF_ARG)"
    local arg arg_idx=$IDX_OFFSET arglen=${#args[@]}
    local optarg_idx=$((${#ZETOPT_OPTVALS[@]} + $IDX_OFFSET))
    refs=()

    # options requiring NO argument
    if [[ -z $paramdef_str ]]; then
        if [[ $optsign =~ ^--?$ ]]; then
            ZETOPT_OPTVALS+=(${ZETOPT_CFG_FLAGVAL_TRUE:-0})
        else
            ZETOPT_OPTVALS+=(${ZETOPT_CFG_FLAGVAL_FALSE:-1})
        fi
        refs=($optarg_idx)

    # options requring arguments
    else
        IFS=$' '
        \set -- $paramdef_str
        local def= defarr deflen=$# defidx=$IDX_OFFSET varlen_mode=false argcnt=0 argmax=$(_zetopt::def::paramlen $id max)
        defarr=($@)

        while [[ $defidx -lt $(($deflen + $IDX_OFFSET)) ]]
        do
            def=${defarr[$defidx]}

            # args not enough
            if [[ $arg_idx -ge $(($arglen + $IDX_OFFSET)) ]]; then
                if [[ $varlen_mode == false ]]; then
                    if [[ $def =~ @ ]]; then
                        curr_stat=$ZETOPT_STATUS_MISSING_REQUIRED_OPTARGS
                        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_MISSING_REQUIRED_OPTARGS))
                        ZETOPT_OPTERR_MISSING_REQUIRED+=("$optsign$opt")
                    else
                        curr_stat=$ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS
                        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS))
                        ZETOPT_OPTERR_MISSING_OPTIONAL+=("$optsign$opt")
                    fi
                fi
                \break
            fi

            arg="${args[$arg_idx]}"
            if [[ $arg == "" && $_ZETOPT_CFG_IGNORE_BLANK_STRING -eq 0 ]]; then
                : $((arg_idx++))
                continue
            fi

            # add optarg
            if [[ $arg =~ ^[^-+]
                || $arg =~ ^[-+]$
                || $arg == ""
                || ($arg =~ ^-[^-] && $def =~ ^-[^-])
                || ($arg != "--" && $arg =~ ^- && $def =~ ^--)
                || ($arg =~ ^[+] && $def =~ ^--? && $_ZETOPT_CFG_OPTTYPE_PLUS -eq 0)
                || ($arg == "--" && $_ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN -eq 0)
            ]]; then
                ZETOPT_OPTVALS+=("$arg")
                refs+=($optarg_idx)
                : $((argcnt++))
            
            # error: missing required arguments 
            elif [[ $def =~ @ && $varlen_mode == false ]]; then
                curr_stat=$ZETOPT_STATUS_MISSING_REQUIRED_OPTARGS
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | curr_stat))
                ZETOPT_OPTERR_MISSING_REQUIRED+=("$optsign$opt")
                \break
            
            # warning: missing optional arguments
            else
                if [[ $varlen_mode == false ]]; then
                    curr_stat=$ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | curr_stat))
                fi
                ZETOPT_OPTERR_MISSING_OPTIONAL+=("$optsign$opt")
                \break
            fi

            : $((arg_idx++))
            : $((optarg_idx++))

            if [[ $varlen_mode == false && $def =~ [%@]([a-zA-Z_][0-9a-zA-Z_]*)?[.]{3,3} ]]; then
                varlen_mode=true
            fi

            if [[ $varlen_mode == true && $argcnt -ge $argmax ]]; then
                \break
            fi

            # increment defidx if def is not a variable-length argument
            if [[ $varlen_mode == false ]]; then
                : $((defidx++))
            fi
        done
        _CONSUMED_ARGS_COUNT=${#refs[@]}
    fi

    local type=$ZETOPT_TYPE_CMD
    case $optsign in
        -)  type=$ZETOPT_TYPE_SHORT;;
        --) type=$ZETOPT_TYPE_LONG;;
        +)  type=$ZETOPT_TYPE_PLUS;;
    esac

    IFS=$' '
    if [[ $cnt -eq 0 ]]; then
        stat="$curr_stat"
        refsstr="${refs[*]-}"
        types="$type"
    else
        stat="$stat $curr_stat"
        refsstr="$refsstr,${refs[*]-}"
        types="$types $type"
    fi
    : $((cnt++))
    
    _ZETOPT_PARSED_LIST[$ididx]="$id:$short:$long:$refsstr:$types:$stat:$cnt"
    [[ $curr_stat -le $ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS ]]
    return $?
}

# Assign indices to subcommand parameters. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::assign_args {NAMESPACE} {ARGUMENTS}
# e.g.) _zetopt::parser::assign_args /sub/cmd/ "$@"
# STDOUT: NONE
_zetopt::parser::assign_args()
{
    local namespace="${1-}"
    local ididx="$(_zetopt::def::ididx "$namespace")"
    if [[ $ididx == $ZETOPT_IDX_NOT_FOUND ]]; then
        return 1
    fi
    \shift
    local arglen=${#ZETOPT_ARGS[@]}
    local IFS=:
    \set -- ${_ZETOPT_DEFINED_LIST[$ididx]}
    local paramdef_str="$(eval echo '"${'$ZETOPT_FIELD_DEF_ARG'-}"')"
    if [[ -z $paramdef_str ]]; then
        return 0
    fi

    local rtn=$ZETOPT_STATUS_NORMAL

    IFS=$' '
    local defarr
    defarr=($paramdef_str)
    local deflen=${#defarr[@]}  refsstr=
    local len=$(($arglen > $deflen ? $deflen : $arglen))
    
    if [[ $len -ne 0 ]]; then
        # variable length
        local lastdef=${defarr[$((deflen - 1 + $IDX_OFFSET))]}
        if [[ $lastdef =~ [.]{3,3}([1-9][0-9]*)*$ ]]; then
            local defmaxlen=${lastdef##*...}
            local maxlen=$arglen
            if [[ ! -z "$defmaxlen" ]]; then
                maxlen=$(($arglen > $defmaxlen ? $defmaxlen : $arglen))
                if [[ $maxlen -lt $arglen ]]; then
                    rtn=$((rtn | ZETOPT_STATUS_TOO_MATCH_ARGS))
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_TOO_MATCH_ARGS))
                fi
            fi
            refsstr=$(\eval "\echo {$IDX_OFFSET..$(($maxlen - 1 + $IDX_OFFSET))}")
        else
            refsstr=$(\eval "\echo {$IDX_OFFSET..$(($len - 1 + $IDX_OFFSET))}")
        fi
    fi

    # actual arguments length is shorter than defined
    if [[ $len -lt $deflen ]]; then
        if [[ ${defarr[$(($len + $IDX_OFFSET))]} =~ @ ]]; then
            rtn=$((rtn | ZETOPT_STATUS_MISSING_REQUIRED_ARGS))
            ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_MISSING_REQUIRED_ARGS))
        elif [[ ${defarr[$(($len + $IDX_OFFSET))]} =~ % ]]; then
            rtn=$((rtn | ZETOPT_STATUS_MISSING_OPTIONAL_ARGS))
            ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_MISSING_OPTIONAL_ARGS))
        fi
    fi

    IFS=:
    \set -- ${_ZETOPT_PARSED_LIST[$ididx]}
    _ZETOPT_PARSED_LIST[$ididx]="$1:$2:$3:$refsstr:$5:$rtn:$7"
    return $rtn
}


#------------------------------------------------
# _zetopt::data
#------------------------------------------------
# Initialize variables concerned with the parsed data. 
# ** Must be executed in the current shell **
# def.) _zetopt::data::init
# STDOUT: NONE
_zetopt::data::init()
{
    ZETOPT_PARSED=
    _ZETOPT_PARSED_LIST=()
    local IFS=$'\n' line=
    for line in ${ZETOPT_DEFINED//+/} # remove global signs
    do
        IFS=:
        set -- $line
        _ZETOPT_PARSED_LIST+=("$1:$2:$3::::0")
    done
    ZETOPT_OPTVALS=()
    ZETOPT_ARGS=()
}

# Print the parsed data. Print all if ID not given
# def.) _zetopt::data::parsed [ID]
# STDOUT: strings separated with $'\n'
_zetopt::data::parsed()
{
    if [[ -z ${1-} ]]; then
        \echo "${ZETOPT_PARSED-}"
        return 0
    fi
    _zetopt::data::get "$1" $ZETOPT_FIELD_DATA_ALL
}

# Search and print the parsed data
# def.) _zetopt::data::get {ID} [FILED-DATA-NUMBER]
# e.g.) _zetopt::data::get /foo $ZETOPT_FIELD_DATA_ARG
# STDOUT: string
_zetopt::data::get()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    local ididx=$(_zetopt::def::ididx "$id")
    if [[ $ididx == $ZETOPT_IDX_NOT_FOUND ]]; then
        return 1
    fi
    local field="${2-0}"
    if [[ $field -eq 0 ]]; then
        \echo "${_ZETOPT_PARSED_LIST[$ididx]}"
    else
        if [[ $field =~ [^0-9] ]]; then
            return 1
        fi
        IFS=:
        set -- ${_ZETOPT_PARSED_LIST[$ididx]}
        \eval echo '$'$field
    fi
}

# Check if the option is set
# def.) _zetopt::data::isset {ID}
# e.g.) _zetopt::data::isset /foo
# STDOUT: NONE
_zetopt::data::isset()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    [[ $'\n'$ZETOPT_PARSED =~ $'\n'$id: && ! $'\n'$ZETOPT_PARSED =~ $'\n'$id:[^:]?:[^:]*:[^:]*:[^:]*:[^:]*:0 ]];
    return $?
}

# Check if the option is set and its status is OK
# def.) _zetopt::data::isok {ID} [ONE-DIMENSIONAL-KEYS]
# e.g.) _zetopt::data::isok /foo @
# STDOUT: NONE
_zetopt::data::isok()
{
    if [[ -z ${ZETOPT_PARSED:-} ]]; then
        return 1
    fi
    if [[ $# -eq 0 ]]; then
        return 1
    fi
    if [[ -z ${1-} ]]; then
        return 1
    fi

    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if ! _zetopt::def::idexist "$id"; then
        return 1
    fi
    if [[ $'\n'$ZETOPT_PARSED =~ $'\n'$id:[^:]?:[^:]*:[^:]*:[^:]*:[^:]*:0 ]]; then
        return 1
    fi

    \shift
    local stat="$(_zetopt::data::status "$id" "${@-}")"
    if [[ -z $stat ]]; then
        return 1
    fi
    # 0 $ZETOPT_STATUS_NORMAL, 1 $ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS, 2 $ZETOPT_STATUS_MISSING_OPTIONAL_ARGS
    [[ ! $stat =~ [^012\ ] ]]
    return $?
}

# Print option arguments/status index list
# def.) _zetopt::data::validx {ID} {[$ZETOPT_FILED_ARGS|$ZETOPT_FILED_STATUS|$ZETOPT_FIELD_DATA_TYPE]} [TWO-DIMENSIONAL-KEYS]
# e.g.) _zetopt::data::validx /foo $ZETOPT_FILED_ARGS 0 @ 0:1 0:@ 1:@ name 0:1,-1 @:foo,baz 
# STDOUT: integers separated with spaces
_zetopt::data::validx()
{
    if [[ -z ${ZETOPT_PARSED:-} ]]; then
        return 1
    fi
    if [[ $# -lt 2 ]]; then
        return 1
    fi
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    local ididx=$(_zetopt::def::ididx "$id")
    if [[ $ididx == $ZETOPT_IDX_NOT_FOUND ]]; then
        return 1
    fi

    local field="$2"
    case $field in
        $ZETOPT_FIELD_DATA_ARG | $ZETOPT_FIELD_DATA_TYPE | $ZETOPT_FIELD_DATA_STATUS) :;;
        *) return 1;;
    esac

    \shift 2
    local args
    args=("$@")

    # get the definition
    local IFS=:
    \set -- ${_ZETOPT_DEFINED_LIST[$ididx]}
    local def_str="$(\eval echo '"${'$field'-}"')"

    # get the actual arguments list
    \set -- ${_ZETOPT_PARSED_LIST[$ididx]}
    local lists_str="$(\eval echo '$'$field)"
    if [[ -z $lists_str ]]; then
        return 1
    fi
    IFS=$','
    local lists output_list
    lists=($lists_str) output_list=()
    local lists_last_idx="$((${#lists[@]} - 1 + $IDX_OFFSET))"

    IFS=$' '
    if [[ ${#args[@]} -eq 0 ]]; then
        output_list=(${lists[$lists_last_idx]})
    else
        local input_idx= tmp_list
        for input_idx in "${args[@]}"
        do            
            if [[ ! $input_idx =~ ^(@|([$\^]|-?[1-9][0-9]*)(,([$\^]|-?[1-9][0-9]*)?)?)?(:?(@|(([$\^]|-?[1-9][0-9]*|[a-zA-Z_]+[a-zA-Z0-9_]*)(,([$\^]|-?[1-9][0-9]*|[a-zA-Z_]+[a-zA-Z0-9_]*)?)?)?)?)?$ ]]; then
                _zetopt::utils::script_error "Bad Key:" "$input_idx"
                return 1
            fi

            # shortcuts for improving performance
            if [[ $input_idx == @ ]]; then
                output_list+=(${lists[$lists_last_idx]})
                continue
            elif [[ $input_idx == @:@ ]]; then
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
                @)      list_start_idx=$IDX_OFFSET;;
                ^)      list_start_idx=$IDX_OFFSET;;
                $|"")   list_start_idx=$lists_last_idx;;
                *)      list_start_idx=$tmp_list_start_idx;;
            esac
            case "$tmp_list_end_idx" in
                @)      list_end_idx=$lists_last_idx;;
                ^)      list_end_idx=$IDX_OFFSET;;
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
            if [[ $list_start_idx -lt $IDX_OFFSET || $list_end_idx -gt $lists_last_idx
                || $list_end_idx -lt $IDX_OFFSET || $list_start_idx -gt $lists_last_idx
            ]]; then
                _zetopt::utils::script_error "Index Out of Range:" "$input_idx"
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

            local val_start_idx= val_end_idx= val_idx=
            case "$tmp_val_start_idx" in
                @)      val_start_idx=$IDX_OFFSET;;
                ^)      val_start_idx=$IDX_OFFSET;;
                $|"")   val_start_idx=$;; # the last index will be determined later
                *)      val_start_idx=$tmp_val_start_idx;;
            esac
            case "$tmp_val_end_idx" in
                @)      val_end_idx=$;; # the last index will be determined later
                ^)      val_end_idx=$IDX_OFFSET;;
                $|"")   val_end_idx=$;; # the last index will be determined later
                *)      val_end_idx=$tmp_val_end_idx
            esac

            # index by name : look up a name from parameter definition
            local def= defidx= idx=0 param_names=
            for param_names in $val_start_idx $val_end_idx
            do
                if [[ ! $param_names =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]]; then
                    : $((idx++))
                    continue
                fi

                defidx=$IDX_OFFSET nameidx=
                for def in $def_str
                do
                    if [[ ${def//[-@%.]/} == $param_names ]]; then
                        nameidx=$defidx
                        \break
                    fi
                    : $((defidx++))
                done

                if [[ -z $nameidx ]]; then
                    _zetopt::utils::script_error "Parameter Name Not Found:" "$input_idx"
                    return 1
                fi

                if [[ $idx -eq 0 ]]; then
                    val_start_idx=$nameidx
                else
                    val_end_idx=$nameidx
                fi
                : $((idx++))
            done

            local list_idx= val_idx= maxidx=
            tmp_list=()
            for list_idx in $(\eval "\echo {$list_start_idx..$list_end_idx}")
            do 
                tmp_list=(${lists[$list_idx]})
                if [[ ${#tmp_list[@]} -eq 0 ]]; then
                    continue
                fi
                
                # determine the value start/end index
                maxidx=$((${#tmp_list[@]} - 1 + $IDX_OFFSET))
                if [[ $val_start_idx == $ ]]; then
                    val_start_idx=$maxidx  # set the last index
                fi
                if [[ $val_end_idx == $ ]]; then
                    val_end_idx=$maxidx    # set the last index
                fi

                # convert negative indices to positive
                if [[ $val_start_idx =~ ^- ]]; then
                    val_start_idx=$((maxidx - (val_start_idx * -1 - 1)))
                fi
                if [[ $val_end_idx =~ ^- ]]; then
                    val_end_idx=$((maxidx - (val_end_idx * -1 - 1)))
                fi

                # check the range
                if [[ $val_start_idx -lt $IDX_OFFSET || $val_end_idx -gt $maxidx
                    || $val_end_idx -lt $IDX_OFFSET || $val_start_idx -gt $maxidx
                ]]; then
                    _zetopt::utils::script_error "Index Out of Range:" "$input_idx -> $val_start_idx~$val_end_idx (Valid: $IDX_OFFSET~$maxidx)"
                    return 1
                fi

                for val_idx in $(\eval "\echo {$val_start_idx..$val_end_idx}")
                do
                    output_list+=(${tmp_list[$val_idx]})
                done
            done
        done
    fi
    \echo ${output_list[@]}
}

# Check if it has value
# def.) _zetopt::data:hasvalue {ID} [ONE-DIMENSIONAL-KEYS]
# e.g.) _zetopt::data::hasvalue /foo 0
# STDOUT: NONE
_zetopt::data::hasvalue()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if [[ $'\n'$ZETOPT_PARSED =~ $'\n'$id: && $'\n'$ZETOPT_PARSED =~ $'\n'$id:[^:]?:[^:]*::[^:]*:[^:]*:[^:]* ]]; then
        return 1
    fi
    local len=$(_zetopt::data::arglength "$@")
    if [[ -z $len ]]; then
        return 1
    fi
    [[ $len -ne 0 ]]
    return $?
}

# Print option arguments index list to refer $ZETOPT_OPTVALS
# def.) _zetopt::data::argidx {ID} [TWO-DIMENSIONAL-KEYS]
# e.g.) _zetopt::data::argidx /foo $ZETOPT_FILED_ARGS 0 @ 0:1 0:@ 1:@ name 0:1,-1 @:foo,baz
# STDOUT: integers separated with spaces
_zetopt::data::argidx()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    \shift
    
    local list_str="$(_zetopt::data::validx "$id" $ZETOPT_FIELD_DATA_ARG "$@")"
    if [[ -z "$list_str" ]]; then
        return 1
    fi
    local IFS=$' '
    \echo $list_str
}

# Print the values of the option/subcommand argument
# def.) _zetopt::data::argvalue <ID> [<TWO-DIMENSIONAL-KEYS>] [-a,--array <ARRAY_NAME>]
# e.g.) _zetopt::data::argvalue /foo 0:@ 1:@ --array myarr
# STDOUT: strings separated with $ZETOPT_CFG_VALUE_IFS
_zetopt::data::argvalue()
{
    if [[ $# -eq 0 ]]; then
        return 1
    fi

    local __array_mode=false __arrname=
    local __args
    __args=()

    while [[ $# -ne 0 ]]
    do
        case "$1" in
            --array|-a)
                __array_mode=true;
                \shift;
                if [[ $# -eq 0 ]]; then
                    _zetopt::utils::script_error "Missing Required Argument:" "-a, --array <ARRAY_NAME>"
                    return 1
                fi
                __arrname=$1
                \shift
                ;;
            --) \shift; __args+=("$@"); \break;;
            *)  __args+=("$1"); \shift;;
        esac
    done

    if [[ $__array_mode == true ]]; then
        # check the user defined array name before eval to avoid overwriting local variables
        if [[ ! $__arrname =~ ^[a-zA-Z_]([0-9a-zA-Z_]+)*$ ]] || [[ $__arrname =~ ((^_$)|(^__[0-9a-zA-Z][0-9a-zA-Z_]*$)|(^IFS$)) ]]; then
            _zetopt::utils::script_error "Invalid Array Name:" "$__arrname"
            return 1
        fi
        \eval "$__arrname=()"
    fi

    local IFS=' '
    if [[ -z ${__args[$((0 + $IDX_OFFSET))]-} ]]; then
        return 1
    fi
    local __id="${__args[$((0 + $IDX_OFFSET))]}" && [[ ! $__id =~ ^/ ]] && __id="/$__id"
    \unset __args[$((0 + $IDX_OFFSET))]
    __args=(${__args[@]})
    
    local __list_str="$(_zetopt::data::validx "$__id" $ZETOPT_FIELD_DATA_ARG "${__args[@]}")"
    if [[ -z "$__list_str" ]]; then
        return 1
    fi
    
    # for subcommands
    __args=()
    if [[ $__id =~ ^/(.*/)?$ ]]; then
        __args=("${ZETOPT_ARGS[@]}")

    # for options
    else
        __args=("${ZETOPT_OPTVALS[@]}")
    fi

    local __idx= __i=$IDX_OFFSET
    local __ifs=${ZETOPT_CFG_VALUE_IFS-$'\n'}
    \set -- $__list_str
    for __idx in "$@"
    do
        if [[ $__array_mode == true ]]; then
            \eval $__arrname'[$__i]=${__args[$__idx]}'
        else
            \printf -- "%s$__ifs" "${__args[$__idx]}"
        fi
        : $((__i++))
    done
}

# Print the actual length of arguments of the option/subcommand
# def.) _zetopt::data::arglength {ID} [ONE-DIMENSIONAL-KEYS]
# e.g.) _zetopt::data::arglength /foo 1
# STDOUT: an integer
_zetopt::data::arglength()
{
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if ! _zetopt::def::idexist "$id"; then
        return 1
    fi
    \shift

    local idxarr
    idxarr=()
    if [[ $# -eq 0 || -z ${@-} ]]; then
        idxarr=($:@)
    else
        local idx=
        for idx in "$@"
        do 
            if [[ $idx =~ [^@$\^,0-9-] ]]; then
                _zetopt::utils::script_error "Bad Index:" "$idx"
                return 1
            fi
            idxarr+=("$idx:@")
        done
    fi
    local IFS=$' '
    local arr
    arr=($(_zetopt::data::validx "$id" $ZETOPT_FIELD_DATA_ARG "${idxarr[@]}"))
    \echo ${#arr[@]}
}

# Print the parse status in integers
# def.) _zetopt::data::status {ID} [ONE-DIMENSIONAL-KEYS]
# e.g.) _zetopt::data::status /foo 1
# STDOUT: integers separated with spaces
_zetopt::data::status()
{
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if ! _zetopt::def::idexist "$id"; then
        return 1
    fi
    \shift

    local idxarr
    idxarr=()
    if [[ $# -eq 0 || -z ${@-} ]]; then
        idxarr=($)
    else
        local idx=
        for idx in "$@"
        do 
            if [[ $idx =~ [^@$\^,0-9-] ]]; then
                _zetopt::utils::script_error "Bad Index:" "$idx"
                return 1
            fi
            idxarr+=("$idx")
        done
    fi
    _zetopt::data::validx "$id" $ZETOPT_FIELD_DATA_STATUS "${idxarr[@]}"
}

# Print the type of option in ZETOPT_TYPE_*
# def.) _zetopt::data::type {ID} [ONE-DIMENSIONAL-KEYS]
# e.g.) _zetopt::data::type /foo 0
# STDOUT: integers separated with spaces
_zetopt::data::type()
{
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if ! _zetopt::def::idexist "$id"; then
        return 1
    fi
    \shift

    local idxarr
    idxarr=()
    if [[ $# -eq 0 || -z ${@-} ]]; then
        idxarr=($)
    else
        local idx=
        for idx in "$@"
        do 
            if [[ $idx =~ [^@$\^,0-9-] ]]; then
                _zetopt::utils::script_error "Bad Index:" "$idx"
                return 1
            fi
            idxarr+=("$idx")
        done
    fi
    _zetopt::data::validx "$id" $ZETOPT_FIELD_DATA_TYPE "${idxarr[@]}"
}


# Print the number of times the option was set
# def.) _zetopt::data::count {ID}
# e.g.) _zetopt::data::count /foo
# STDOUT: an integer
_zetopt::data::count()
{
    _zetopt::data::get "${1-}" $ZETOPT_FIELD_DATA_COUNT || echo 0
}


# Print the list of IDs set
# def.) _zetopt::data::setids
# e.g.) _zetopt::data::setids
# STDOUT: string separated with spaces
_zetopt::data::setids()
{
    local line= ids
    ids=()
    local IFS=:
    for line in "${_ZETOPT_PARSED_LIST[@]}"
    do
        \set -- $line
        if [[ $7 -ne 0 ]]; then
            ids+=("$1")
        fi
    done
    IFS=' '
    \echo "${ids[*]}"
}


#------------------------------------------------
# _zetopt::utils
#------------------------------------------------
_zetopt::utils::msg()
{
    if ! _zetopt::utils::is_true "${ZETOPT_CFG_ERRMSG-}"; then
        return 0
    fi

    local title="${1-}" text="${2-}" value="${3-}" col=
    local coloring=false
    case "$(<<< "${ZETOPT_CFG_ERRMSG_COL_MODE:-never}" \tr "[:upper:]" "[:lower:]")" in
        never) coloring=false;;
        always) coloring=true;;
        auto) [[ $TTY_STDERR -eq 0 ]] && coloring=true || coloring=false;;
    esac

    # plain text message
    if [[ $coloring == false ]]; then
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

_zetopt::utils::script_error()
{
    local text=${1-} value=${2-}
    local lineno=${BASH_LINENO-${funcfiletrace[1]##*:}}
    local appname=${ZETOPT_CFG_ERRMSG_APPNAME-$ZETOPT_APPNAME}
    local filename=${ZETOPT_SOURCE_FILE_PATH##*/}
    local title="SCRIPT ERROR"
    local funcname="$(_zetopt::utils::funcname 1 )()"
    local col=${ZETOPT_CFG_ERRMSG_COL_SCRIPTERR:-"7;1;31"}
    local textcol=${ZETOPT_CFG_ERRMSG_COL_DEFAULT:-"0;0;39"}
    local IFS=$' \t\n'
    \printf >&2 "\e[${col}m%b\e[0m \e[${textcol}m%b\e[0m \e[${col}m%b\e[0m\n" "$appname: $title: $filename: $funcname [$lineno]" "\n$text" "$value"
    \printf >&2 -- "\n\e[4mCommand Line\e[m\n -> zetopt"
    \printf >&2 -- " \"%s\"" "${_COMMAND_LINE[@]}"
    \printf >&2 -- "\n\n\e[4mStack Trace\e[m\n"
    IFS=$'\n'
    \printf >&2 -- " -> %b\n" $(_zetopt::utils::stack_trace)
}

_zetopt::utils::funcname()
{
    local skip_stack_count=0
    if [[ -n ${1-} ]]; then
        skip_stack_count=$1
    fi

    if [[ -n $BASH_VERSION ]]; then
        \printf -- "%s" "${FUNCNAME[$((1 + $skip_stack_count))]}"
    elif [[ -n $ZSH_VERSION ]]; then
        \printf -- "%s" "${funcstack[$((1 + $skip_stack_count + $IDX_OFFSET))]}"
    fi
}

_zetopt::utils::stack_trace()
{
    local skip_stack_count=1
    if [[ -n ${1-} ]]; then
        skip_stack_count=$1
    fi
    local funcs_start_idx=$((skip_stack_count + 1))
    local lines_start_idx=$skip_stack_count
    local funcs lines i
    funcs=()
    lines=()
    if [[ -n $BASH_VERSION ]]; then
        funcs=("${FUNCNAME[@]:$funcs_start_idx}")
        funcs[$((${#funcs[@]} - 1))]=$ZETOPT_CALLER_NAME
        lines=("${BASH_LINENO[@]:$lines_start_idx}")
    elif [[ -n $ZSH_VERSION ]]; then
        \setopt localoptions KSH_ARRAYS
        funcs=("${funcstack[@]:$funcs_start_idx}" "$ZETOPT_CALLER_NAME")
        lines=("${funcfiletrace[@]:$lines_start_idx}")
        lines=("${lines[@]##*:}")
    fi
    for ((i=0; i<${#funcs[@]}; i++))
    do
        \printf -- "%s [%s]\n" "${funcs[$i]}" "${lines[$i]}"
    done
}

_zetopt::utils::repeat()
{
    if [[ $# -ne 2 || ! $1 =~ ^[1-9][0-9]*$ ]]; then
        _zetopt::utils::script_error "Invalid Argument:" "_zetopt::utils::repeat <REPEAT_COUNT> <STRING>"
        return 1
    fi
    local IFS=$' '
    local repstr="${2//\//\\/}"
    \printf -- "0%.s" $(eval "echo {1..$1}") | \sed -e "s/0/$repstr/g"
}

_zetopt::utils::seq()
{
    local start= end= delim= custom_delim=false error=

    while [[ ! $# -eq 0 ]]
    do
        case $1 in
            -d|--delemiter) \shift; delim=${1-}; custom_delim=true; \shift;;
            --) start=$1; \shift; end=${1-}; \shift; \break ;;
            *)
                if [[ -z $start ]]; then
                    start=$1
                elif [[ -z $end ]]; then
                    end=$1
                else
                    error=true
                    \break
                fi
                \shift ;;
        esac
    done
    if [[ -z $start || -z $end ]]; then
        error=true
    fi
    
    if [[ $error == true ]]; then
        _zetopt::utils::script_error "_zetopt::utils::seq <START> <END> [-d,--delimiter <DELIMITER>]"
        return 1
    fi

    if [[ ! $start =~ ^([a-zA-Z]|-?[0-9]+)$ ]] || [[ ! $end =~ ^([a-zA-Z]|-?[0-9]+)$ ]]; then
        _zetopt::utils::script_error "Accepts:" "^([a-zA-Z]|[0-9]+)$"
        return 1
    fi

    if [[ $custom_delim == true ]]; then
        \eval "echo {$start..$end}" | \sed -e "s/ /$delim/g"
    else
        \eval "echo {$start..$end}"
    fi
}

_zetopt::utils::is_true()
{
    local rtn=1
    if [[ $# -eq 0 || -z ${1-} ]]; then
        return $rtn
    fi

    local stdout=false
    if [[ $1 == --stdout ]]; then
        stdout=true
        \shift
    fi
    
    local longest="enabled"
    if [[ -n ${1-} && ${#1} -le ${#longest} ]]; then
        case "$(<<< "${1-}" \tr "[:upper:]" "[:lower:]")" in
            0 | true | yes | y | enabled | enable | on)     rtn=0;;
            #1 | false | no | n | disabled | disable | off)  rtn=1;;
            #*)                                              rtn=1;;
        esac
    fi
    if [[ $stdout == true ]]; then
        \echo $rtn
    fi
    return $rtn
}


#------------------------------------------------
# _zetopt::help
#------------------------------------------------
_zetopt::help::init()
{
    local IFS=$' '
    _ZETOPT_HELPS_IDX=(
        "0:NAME"
        "1:VERSION"
        "2:SYNOPSIS"
        "3:DESCRIPTION"
        "4:OPTIONS"
    )
    _ZETOPT_HELPS=("_" "" "_" "" "_")
    _ZETOPT_HELPS_CUSTOM=
}

_zetopt::help::search()
{
    if [[ -z ${1-} ]]; then
        return $ZETOPT_IDX_NOT_FOUND
    fi

    (
        # for search with ignoring case
        if [[ -n ${ZSH_VERSION-} ]]; then
            \setopt localoptions NOCASEMATCH
            \setopt localoptions KSH_ARRAYS # for BASH_REMATCH
        else
            \shopt -s nocasematch
        fi

        local IFS=$'\n'
        if [[ $'\n'"${_ZETOPT_HELPS_IDX[*]}"$'\n' =~ $'\n'([0-9]+):($1)$'\n' ]]; then
            \printf -- "%s" ${BASH_REMATCH[1]}
        else
            \printf -- "%s" $ZETOPT_IDX_NOT_FOUND
        fi
    )
}

_zetopt::help::body()
{
    local idx=$(_zetopt::help::search "$1")
    if [[ $idx == $ZETOPT_IDX_NOT_FOUND ]]; then
        \printf -- "%s" ""
    else
        local refidx=$(($idx + $IDX_OFFSET))
        \printf -- "%s" "${_ZETOPT_HELPS[$refidx]}"
    fi
}

_zetopt::help::define()
{
    if [[ -z ${_ZETOPT_HELPS_IDX[@]-} ]]; then
        _zetopt::help::init
    fi

    local idx=$(_zetopt::help::search "$1")
    if [[ $idx == $ZETOPT_IDX_NOT_FOUND ]]; then
        idx=${#_ZETOPT_HELPS[@]}
    fi
    _ZETOPT_HELPS_CUSTOM="${_ZETOPT_HELPS_CUSTOM%:}:$idx:"
    local refidx=$(($idx + $IDX_OFFSET))
    _ZETOPT_HELPS_IDX[$refidx]="$idx:$1"
    \shift 1
    local IFS=$''
    _ZETOPT_HELPS[$refidx]="$*"
}

_zetopt::help::show()
{
    if [[ -z ${_ZETOPT_HELPS_IDX[@]-} ]]; then
        _zetopt::help::init
    fi
    local idx_name=0 idx_synopsis=2 idx_option=4 idx=
    local _TERM_MAX_COLS=$(($(tput cols) - 4))
    local _BASE_COLS=0
    local _OPT_COLS=4
    local _OPT_DESC_MARGIN=2
    local _DESC_DEFAULT_COLS=120
    local _INDENT_STEP=4
    local _INDENT_LEVEL=0
    local body= bodyarr= 
    local IFS=$'\n'
    local title titles
    titles=()

    if [[ -z "${@-}" ]]; then
        titles=("${_ZETOPT_HELPS_IDX[@]#*:}")
    else
        titles=("$@")
    fi
    
    for title in "${titles[@]}"
    do
        body=$(_zetopt::help::body "$title")
        if [[ -z $body ]]; then
            continue
        fi

        \printf -- "$(_zetopt::help::indent)%b\n" "\e[1m$title\e[m"
        : $((_INDENT_LEVEL++))
        idx=$(_zetopt::help::search "$title")

        # OPTIONS
        if [[ $idx == $idx_option && ! $_ZETOPT_HELPS_CUSTOM =~ :${idx_option}: ]]; then
            _zetopt::help::options
        else
            # Default NAME
            if [[ $idx == $idx_name && ! $_ZETOPT_HELPS_CUSTOM =~ :${idx_name}: ]]; then
                body="$ZETOPT_CALLER_NAME"

            # Default SYNOPSIS
            elif [[ $idx == $idx_synopsis && ! $_ZETOPT_HELPS_CUSTOM =~ :${idx_synopsis}: ]]; then
                body=$(_zetopt::help::synopsis)
            fi

            bodyarr=($(\printf -- "%b" "$body" | \fold -w $(_zetopt::help::rest_cols) -s -b))
            \printf -- "$(_zetopt::help::indent)%b\n" "${bodyarr[@]}"
            \echo
        fi
        : $((_INDENT_LEVEL--))
    done
}

_zetopt::help::single_opthelp()
{
    local _TERM_MAX_COLS=$(($(\tput cols) - 1))
    local _BASE_COLS=0
    local _OPT_COLS=16
    local _OPT_DESC_MARGIN=2
    local _DESC_DEFAULT_COLS=120
    local _INDENT_STEP=3
    local _INDENT_LEVEL=0
    local body= bodyarr= 
    local IFS=$'\n'
    local line=$(_zetopt::def::get "$1")
    local opt=$(_zetopt::help::fmtoptarg "$line")
    local help=${_ZETOPT_OPTHELPS[${line##*:}]}
    local desc
    desc=($(\printf -- "%b" "$help" | \fold -w $(_zetopt::help::rest_cols) -s -b))
    if [[ ${#opt} -le $(($_OPT_COLS)) ]]; then
        \printf -- "$(_zetopt::help::indent)%-$(($_OPT_COLS + $_OPT_DESC_MARGIN))s%s\n" "$opt" "${desc[$((0 + $IDX_OFFSET))]}"
        if [[ ${#desc[@]} -gt 1 ]]; then
            \unset desc[$((0 + $IDX_OFFSET))]
            desc=(${desc[@]})
            if [[ -n "${desc[@]//\ /}" ]]; then
                \printf -- "$(_zetopt::help::desc_indent)%s\n" "${desc[@]}"
            fi
        fi
    else
        \printf -- "$(_zetopt::help::indent)%s\n" "$opt"
        if [[ -n "${desc[@]}" ]]; then
            \printf -- "$(_zetopt::help::desc_indent)%s\n" "${desc[@]}"
        fi
    fi
}


_zetopt::help::rest_cols()
{
    local desc_cols=$_DESC_DEFAULT_COLS
    local desc_max_cols=$((_TERM_MAX_COLS - _BASE_COLS - _OPT_COLS - (_INDENT_STEP * _INDENT_LEVEL)))
    if [[ $_DESC_DEFAULT_COLS -gt $desc_max_cols ]]; then
        desc_cols=$desc_max_cols
    fi
    \printf -- "%s" "$desc_cols"
}

_zetopt::help::indent()
{
    \printf -- "%s" "$(printf -- "%$((_BASE_COLS + (_INDENT_STEP * _INDENT_LEVEL)))s" "")" 
}

_zetopt::help::desc_indent()
{
    \printf -- "%s" "$(printf -- "%$((_BASE_COLS + _OPT_COLS + _OPT_DESC_MARGIN + (_INDENT_STEP * _INDENT_LEVEL)))s" "")" 
}

_zetopt::help::synopsis()
{
    \echo Auto Generated Synopsis
}

_zetopt::help::options()
{
    local len=${#_ZETOPT_DEFINED_LIST[@]}
    local i=0 id= tmp= desc= opt= rootcmds= subcmds= help=
    rootcmds=() subcmds=()

    for line in "${_ZETOPT_DEFINED_LIST[@]}"
    do
        id=${line%%:*}
        tmp=${id//[!\/]/}
        if [[ ${#tmp} -eq 1 ]]; then
            rootcmds+=("$line")
        else
            subcmds+=("$line")
        fi
    done

    local ns= prev_ns=/
    local subcmd_mode=false
    local incremented=false
    for line in "${rootcmds[@]}" "${subcmds[@]}"
    do
        id= desc= opt=
        id=${line%%:*}
        ns=${id%/*}/
        # command mode
        if [[ $subcmd_mode == false && $id != / && $id =~ /$ ]]; then
            subcmd_mode=true
            _INDENT_LEVEL=0
            \printf -- "$(_zetopt::help::indent)%b\n" "\e[1mSUB-COMMANDS\e[m"
            : $((_INDENT_LEVEL++))
        fi

        opt=$(_zetopt::help::fmtoptarg "$line")
        if [[ $subcmd_mode == true ]]; then
            if [[ ${opt:0:1} == "-" ]]; then
                : $((_INDENT_LEVEL++))
                prev_ns=$ns
                incremented=true
            elif [[ $ns != $prev_ns && $incremented == true ]]; then
                : $((_INDENT_LEVEL--))
                incremented=false
            fi
        fi
        
        help=${_ZETOPT_OPTHELPS[${line##*:}]}
        desc=($(\printf -- "%b" "$help" | \fold -w $(_zetopt::help::rest_cols) -s -b))
        if [[ ${#opt} -le $(($_OPT_COLS)) ]]; then
            \printf -- "$(_zetopt::help::indent)%-$(($_OPT_COLS + $_OPT_DESC_MARGIN))s%s\n" "$opt" "${desc[$((0 + $IDX_OFFSET))]}"
            if [[ ${#desc[@]} -gt 1 ]]; then
                \unset desc[$((0 + $IDX_OFFSET))]
                desc=(${desc[@]})
                if [[ -n "${desc[@]//\ /}" ]]; then
                    \printf -- "$(_zetopt::help::desc_indent)%s\n" "${desc[@]}"
                fi
            fi
        else
            \printf -- "$(_zetopt::help::indent)%s\n" "$opt"
            if [[ -n "${desc[@]}" ]]; then
                \printf -- "$(_zetopt::help::desc_indent)%s\n" "${desc[@]}"
            fi
        fi

        : $((i++))
        if [[ $len -gt $i ]]; then
            \printf -- "%s\n" ""
        fi
    done
}

_zetopt::help::fmtoptarg()
{
    local arridx_id=$(($ZETOPT_FIELD_DEF_ID - 1 + $IDX_OFFSET))
    local arridx_short=$(($ZETOPT_FIELD_DEF_SHORT - 1 + $IDX_OFFSET))
    local arridx_long=$(($ZETOPT_FIELD_DEF_LONG - 1 + $IDX_OFFSET))
    local arridx_arg=$(($ZETOPT_FIELD_DEF_ARG - 1 + $IDX_OFFSET))
    local opt= tmparr= optargs=
    local IFS=:
    local line=$1
    tmparr=($line)
    local id=${tmparr[$arridx_id]}
    local short=${tmparr[$arridx_short]}
    local long=${tmparr[$arridx_long]}
    local args=${tmparr[$arridx_arg]}
    IFS=$'\n'

    if [[ $id == / ]]; then
        opt="$ZETOPT_CALLER_NAME "
    elif [[ $id =~ /$ ]]; then
        opt="${id:1:$((${#id}-2))}"
        opt="${opt//\// }"
    else
        if [[ -n $short ]]; then
            opt="-$short"
            if [[ -n $long ]]; then
                opt="$opt, --$long"
            fi
        elif [[ -n $long ]]; then
            opt="--$long"
        fi
    fi

    optargs=$opt

    if [[ -n $args ]]; then
        args=${args//-/}
        if [[ $args =~ \.\.\. ]]; then
            args=${args//.../ ...}
        fi
        IFS=$' '
        local cnt=1
        for arg in $args
        do
            if [[ $arg == @ ]]; then
                optargs="$optargs <ARG_$cnt>"
                : $((cnt++))
            elif [[ $arg == % ]]; then
                optargs="$optargs [<ARG_$cnt>]"
                : $((cnt++))
            elif [[ ${arg:0:1} == @ ]]; then
                optargs="$optargs <${arg:1}>"
                : $((cnt++))
            elif [[ ${arg:0:1} == % ]]; then
                optargs="$optargs [<${arg:1}>]"
                : $((cnt++))
            elif [[ $arg =~ \.\.\. ]]; then
                optargs="$optargs [$arg]"
            fi
        done
        IFS=$'\n'
    fi
    \printf -- "%s" "$optargs"
}



#------------------------------------------------
# _zetopt::selfhelp
#------------------------------------------------
_zetopt::selfhelp::show()
{
    if [[ $1 == "short" ]]; then
<< __EOHELP__ \cat
NAME
    $ZETOPT_APPNAME -- An option parser for shell scripts
VERSION
    $ZETOPT_VERSION
USAGE
    zetopt {SUB-COMMAND} {ARGS}
SUB-COMMANDS
    version help init reset define defined
    parse data get isset count status index

Type \`zetopt help\` to show more help 
__EOHELP__
        return 0
    fi

<< __EOHELP__ \cat
------------------------------------------------------------------------
Name        : $ZETOPT_APPNAME -- An option parser for shell scripts
Version     : $ZETOPT_VERSION
License     : MIT License
Author      : itmst71@gmail.com
URL         : https://github.com/itmst71/zetopt
Required    : Bash 3.2+ / Zsh 5.0+, Some POSIX commands
------------------------------------------------------------------------
DESCRIPTION
    An option parser for Bash/Zsh scripts.

SYNOPSYS
    $ZETOPT_APPNAME {SUB-COMMAND} {ARGS}

SUB-COMMANDS
    init

    reset
    
    define, def

    defined

    load

    parse

    parsed

    isset

    isok

    hasval

    value, val

    length, len
    
    index, idx

    paramidx, pidx

    paramlen, plen

    status, stat

    count, cnt
    
__EOHELP__
}
