#------------------------------------------------------------
# _zetopt::parser
#------------------------------------------------------------

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
    ZETOPT_LAST_COMMAND=/
}

# Parse arguments. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::parse {ARGUMENTS}
# e.g.) _zetopt::parser::parse "$@"
# STDOUT: NONE
_zetopt::parser::parse()
{
    if _zetopt::utils::is_true "${_ZETOPT_DEF_ERROR-}"; then
        _zetopt::msg::debug "Invalid Definition Data:" "Fix definition error before parse"
        return 1
    fi

    if [[ -z ${_ZETOPT_DEFINED:-} ]]; then
        _ZETOPT_DEFINED="/:::$LF"
    fi
    _zetopt::parser::init
    _zetopt::data::init
    
    local optname= optnames_len= optarg= idx= opt_prefix= pseudoname=
    local additional_args_count=0 consumed_args_count= args
    local namespace=/ ns= check_subcmd=true error_subcmd_name=
    
    # internal global variables
    declare -i _CONSUMED_ARGS_COUNT=0
    local _CFG_SINGLE_PREFIX_LONG="$(_zetopt::utils::is_true -t true "${ZETOPT_CFG_SINGLE_PREFIX_LONG-}")"
    local _CFG_ESCAPE_DOUBLE_HYPHEN="$(_zetopt::utils::is_true -t true "${ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN-}")"
    local _CFG_PSEUDO_OPTION="$(_zetopt::utils::is_true -t true "${ZETOPT_CFG_PSEUDO_OPTION-}")"
    local _CFG_CONCATENATED_OPTARG="$(_zetopt::utils::is_true -t true "${ZETOPT_CFG_CONCATENATED_OPTARG-}")"
    local _CFG_IGNORE_BLANK_STRING="$(_zetopt::utils::is_true -t true "${ZETOPT_CFG_IGNORE_BLANK_STRING-}")"
    local _CFG_OPTTYPE_PLUS="$(_zetopt::utils::is_true -t true "${ZETOPT_CFG_OPTTYPE_PLUS-}")"
    local _CFG_IGNORE_SUBCMD_UNDEFERR="$(_zetopt::utils::is_true -t true "${ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR-}")"

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
            if [[ $_CFG_ESCAPE_DOUBLE_HYPHEN != true ]]; then
                shift
                ZETOPT_ARGS+=("$@")
                break
            else
                ZETOPT_ARGS+=("$1")
                shift
            fi
            check_subcmd=false

        # Single Prefix Only
        elif [[ $1 =~ ^[-+]$ ]]; then
            ZETOPT_ARGS+=("$1")
            shift
            check_subcmd=false

        # Blank String
        elif [[ $1 == "" ]]; then
            if [[ $_CFG_IGNORE_BLANK_STRING == true ]]; then
                shift
                continue
            fi
            ZETOPT_ARGS+=("$1")
            shift
            check_subcmd=false

        # Long option
        elif [[ $1 =~ ^(--|[+][+])[^+-] || ($_CFG_SINGLE_PREFIX_LONG == true && ($1 =~ ^-[^-]. || $1 =~ ^[+][^+]. )) ]]; then
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
                    if [[ $_CFG_PSEUDO_OPTION == true && ${optnames:$((idx+1)):1} == : ]]; then
                        pseudoname=${optnames:$((idx+2)):$(($optnames_len - $idx - 1))}
                        _zetopt::parser::setopt $namespace $opt_prefix $optname "$pseudoname" "$@" ||:
                        break
                    else
                        if [[ $_CFG_CONCATENATED_OPTARG == true ]]; then
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
                    if [[ $_CFG_IGNORE_SUBCMD_UNDEFERR == true ]]; then
                        ZETOPT_ARGS+=("$1")
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
            ZETOPT_ARGS+=("$1")
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
    if _zetopt::utils::is_true "${ZETOPT_CFG_ERRMSG-}"; then
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
            msg=($subcmdstr "${#ZETOPT_ARGS[@]} Arguments Given (Up To "$(_zetopt::def::paramlen $namespace max)")")
            _zetopt::msg::user_error Error "Too Match Arguments:" "${msg[*]}"
        fi
    fi

    [[ $ZETOPT_PARSE_ERRORS -le $ZETOPT_STATUS_ERROR_THRESHOLD ]]
}

# Increment the set count of a sub-command. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::setsub {NAMESPACE}
# e.g.) _zetopt::parser::setsub /sub/
# STDOUT: NONE
_zetopt::parser::setsub()
{
    local id=${1-}
    if [[ ! $LF$_ZETOPT_PARSED =~ (.*$LF)(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))($LF.*) ]]; then
        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_SUBCMD))
        return $ZETOPT_STATUS_UNDEFINED_SUBCMD
    fi

    local head_lines="${BASH_REMATCH[$((1 + INIT_IDX))]:1}"
    local tail_lines="${BASH_REMATCH[$((9 + INIT_IDX))]}"
    local offset=2

    local IFS=:
    \set -- ${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_ALL))]}
    local cnt=$(($6 + 1))
    local pseudoidx=-1
    _ZETOPT_PARSED=$head_lines$1:$2:$ZETOPT_TYPE_CMD:$pseudoidx:$ZETOPT_STATUS_NORMAL:$cnt$tail_lines
}

# Set option data. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::setopt {NAMESPACE} {PREFIX} {OPTNAME} {PSEUDO} [ARGUMENTS]
# e.g.) _zetopt::parser::setopt /sub/cmd - version "$@"
# STDOUT: NONE
_zetopt::parser::setopt()
{
    local namespace="${1-}" opt_prefix="${2-}" opt="${3-}" pseudoname="${4-}" args
    shift 4
    args=("$@")
    local is_short=$( [[ ${#opt_prefix} -eq 1 && $_CFG_SINGLE_PREFIX_LONG != true ]] && echo true || echo false)
    local id="$(_zetopt::def::opt2id "$namespace" "$opt" "$is_short" || echo ERROR:$?)"
    if [[ $id =~ ^ERROR:[0-9]+$ ]]; then
        ZETOPT_OPTERR_UNDEFINED+=("$opt_prefix$opt")
        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_OPTION))
        return 1
    fi

    if [[ ! $LF$_ZETOPT_PARSED =~ (.*$LF)(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))($LF.*) ]]; then
        return 1
    fi
    local head_lines="${BASH_REMATCH[$((1 + INIT_IDX))]:1}"
    local tail_lines="${BASH_REMATCH[$((9 + INIT_IDX))]}"
    local IFS=:
    \set -- ${BASH_REMATCH[$((2 + INIT_IDX + ZETOPT_FIELD_DATA_ALL))]}
    local id="$1" refs_str="$2" types="$3" pseudo_idexs="$4" stat="$5" cnt="$6"
    local curr_stat=$ZETOPT_STATUS_NORMAL

    local ref_arr paramdef_str="$(_zetopt::def::field "$id" $ZETOPT_FIELD_DEF_ARG)"
    declare -i optarg_idx=$((${#_ZETOPT_OPTVALS[@]} + $INIT_IDX))
    ref_arr=()

    # options requiring NO argument
    if [[ -z $paramdef_str ]]; then
        [[ $opt_prefix =~ ^--?$ ]] \
        && _ZETOPT_OPTVALS+=("${ZETOPT_CFG_FLAGVAL_TRUE:-0}") \
        || _ZETOPT_OPTVALS+=("${ZETOPT_CFG_FLAGVAL_FALSE:-1}")
        ref_arr=($optarg_idx)

    # options requiring arguments
    else
        IFS=$' '
        \set -- $paramdef_str
        local arg def def_arr varlen_mode=false no_avail_args=false
        declare -i def_len=$(($# + INIT_IDX)) def_idx=$INIT_IDX
        declare -i arg_cnt=0 arg_def_max arg_idx=$INIT_IDX arg_max_idx=$((${#args[@]} + $INIT_IDX))
        def_arr=($@)

        while [[ $def_idx -lt $def_len ]]
        do
            def=${def_arr[$def_idx]}

            # there are available args 
            if [[ $arg_idx -lt $arg_max_idx ]]; then
                arg="${args[$arg_idx]}"
                if [[ $arg == "" && $_CFG_IGNORE_BLANK_STRING == true ]]; then
                    arg_idx+=1
                    continue
                fi

                # check arg format
                if [[ $arg =~ ^[^-+]
                    || $arg =~ ^[-+]$
                    || $arg == ""
                    || ($arg =~ ^-[^-] && $def =~ ^-[^-])
                    || ($arg != "--" && $arg =~ ^- && $def =~ ^--)
                    || ($arg =~ ^[+] && $def =~ ^--? && $_CFG_OPTTYPE_PLUS == true)
                    || ($arg == "--" && $_CFG_ESCAPE_DOUBLE_HYPHEN -eq 0)
                ]]; then
                    # validate
                    if ! _zetopt::parser::validate "$def" "$arg"; then
                        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_VALIDATOR_FAILED))
                        return 1
                    fi
                    _ZETOPT_OPTVALS+=("$arg")
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
                        _ZETOPT_OPTVALS+=("$arg")
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

    local pseudoidx=-1
    if [[ -n $pseudoname ]]; then
        _ZETOPT_PSEUDOS+=("$pseudoname")
        pseudoidx=$((${#_ZETOPT_PSEUDOS[@]} - 1 + $INIT_IDX))
    fi

    IFS=$' '
    if [[ $cnt -eq 0 ]]; then
        stat="$curr_stat"
        refs_str="${ref_arr[*]-}"
        types="$type"
        pseudo_idexs="$pseudoidx"
    else
        stat="$stat $curr_stat"
        refs_str="$refs_str,${ref_arr[*]-}"
        types+=" $type"
        pseudo_idexs+=" $pseudoidx"
    fi
    : $((cnt++))

    _ZETOPT_PARSED="$head_lines$id:$refs_str:$types:$pseudo_idexs:$stat:$cnt$tail_lines"
    [[ $curr_stat -le $ZETOPT_STATUS_ERROR_THRESHOLD ]]
}

_zetopt::parser::validate()
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

# Assign indices to subcommand parameters. 
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
    local def_str def_arr ref_arr= IFS=' ' has_validator=false
    def_str="$(_zetopt::def::field "$id" $ZETOPT_FIELD_DEF_ARG)"
    if [[ $def_str =~ [~][1-9][0-9]* ]]; then
        has_validator=true
    fi
    def_arr=($def_str)
    declare -i def_len=${#def_arr[@]} arg_len=${#ZETOPT_ARGS[@]} rtn=$ZETOPT_STATUS_NORMAL idx maxloop

    # enough
    if [[ $arg_len -ge $def_max_len ]]; then
        ref_arr=($(\eval "\echo {$INIT_IDX..$((def_max_len - 1 + INIT_IDX))}"))

        # validate
        if [[ $has_validator == true ]]; then
            maxloop=$def_len+$INIT_IDX
            for ((idx=INIT_IDX; idx<maxloop; idx++))
            do
                if ! _zetopt::parser::validate "${def_arr[idx]}" "${ZETOPT_ARGS[ref_arr[idx]]}"; then
                    rtn=$((rtn | ZETOPT_STATUS_VALIDATOR_FAILED))
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                fi
            done
        fi

        # too match arguments
        if [[ $arg_len -gt $def_max_len ]]; then
            if [[ ${def_arr[$((def_len - 1 + INIT_IDX))]} =~ [.]{3,3}[1-9][0-9]*=[0-9]+$ ]]; then
                rtn=$((rtn | ZETOPT_STATUS_TOO_MATCH_ARGS))
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
            fi
        fi

    # not enough
    else
        declare -i ref_idx=$INIT_IDX
        if [[ $arg_len -ne 0 ]]; then
            ref_idx=$arg_len-1+$INIT_IDX
            ref_arr=($(\eval "\echo {$INIT_IDX..$ref_idx}"))
            ref_idx+=1

            # validate
            if [[ $has_validator == true ]]; then
                maxloop=$arg_len+$INIT_IDX
                for ((idx=INIT_IDX; idx<maxloop; idx++))
                do
                    if ! _zetopt::parser::validate "${def_arr[idx]}" "${ZETOPT_ARGS[ref_arr[idx]]}"; then
                        rtn=$((rtn | ZETOPT_STATUS_VALIDATOR_FAILED))
                        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                    fi
                done
            fi
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
            ZETOPT_ARGS+=("${_ZETOPT_DEFAULTS[default_idx]}")
            ref_arr+=($ref_idx)
        done
    fi

    # update parsed data
    if [[ ! $LF$_ZETOPT_PARSED =~ (.*$LF)(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))($LF.*) ]]; then
        return 1
    fi
    local head_lines="${BASH_REMATCH[$((1 + INIT_IDX))]:1}"
    local tail_lines="${BASH_REMATCH[$((9 + INIT_IDX))]}"
    local offset=2
    local line="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_ALL))]}"
    local id="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_ID))]}"
    #local arg="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_ARG))]}"
    local type="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_TYPE))]}"
    local pseudoname="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_PSEUDO))]}"
    #local status="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_STATUS))]}"
    local count="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_FIELD_DATA_COUNT))]}"
    IFS=' '
    local refs_str="${ref_arr[*]}"
    _ZETOPT_PARSED="$head_lines$id:$refs_str:$type:$pseudoname:$rtn:$count$tail_lines"
    return $rtn
}
