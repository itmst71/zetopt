#------------------------------------------------------------
# _zetopt::def
#------------------------------------------------------------

# Define options. 
# ** Must be executed in the current shell **
# def.) _zetopt::def::define {DEFINITION-STRING}
# e.g.) _zetopt::def::define "ver:v:version"
# STDOUT: NONE
_zetopt::def::define()
{
    if [[ -z ${_ZETOPT_DEFINED:-} ]]; then
        _ZETOPT_DEFINED="/::::0 0$LF"
        _ZETOPT_OPTHELPS=("")
        _ZETOPT_DEFAULTS=("")
    fi

    if [[ -z $@ ]]; then
        _zetopt::msg::def_error "No Definition Given"
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
            if [[ $tmp_line == "${id}::::0 0" ]]; then
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
            if [[ -n $param_name ]]; then
                if [[ $param_names =~ \ $param_name\  ]]; then
                    _zetopt::msg::def_error "Duplicate Parameter Name:" "$param_name"
                    return 1
                fi
                param_names+=" $param_name "
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
            if [[ -n $param_default ]]; then
                _ZETOPT_DEFAULTS+=("${param_default##=}")
                param_default_idx=$((${#_ZETOPT_DEFAULTS[@]} - 1 + INIT_IDX))
                default_is_set=true
            elif [[ $default_is_set == true ]]; then
                _zetopt::msg::def_error "Non-default Argument Following Default Argument:" "$param_name"
                return 1
            fi
            params+=("$param_hyphens$param_type$param_name.$param_idx~$param_validator_idxs$param_varlen=$param_default_idx")
            param_idx+=1
        done
        IFS=$' '
        param_def="${params[*]}"
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
        _ZETOPT_DEFINED+="$curr_ns::::0 0$LF"
    done
}

# Print the defined data. Print all if ID not given.
# def.) _zetopt::def::defined [ID]
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

# Search and print the definition.
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

# Check if the ID exists
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
    [[ $LF$_ZETOPT_DEFINED =~ $LF${ns}[a-zA-Z0-9_-]+/ ]]
}

# Check if the current namespace has options
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

# Check if the current namespace has arguments
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


_zetopt::def::options()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1" && [[ ! $ns =~ ^/ ]] && ns=/$ns
    [[ ! $ns =~ /$ ]] && ns=$ns/
    <<< "$_ZETOPT_DEFINED" \grep -E "^${ns}[a-zA-Z0-9_]+[+]?:"
}

_zetopt::def::namespaces()
{
    <<< "$_ZETOPT_DEFINED" \grep -E '^/([^:]+/)?:' | \sed -e 's/:.*//'
}

# Print the identifier by searching with a namespace and a option name.
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

# Print the index of the specified parameter name
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

# Print the length of parameters
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

# Print default values
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
