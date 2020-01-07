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
    if [[ -z ${_ZETOPT_DEFINED:-} ]]; then
        _ZETOPT_DEFINED="/:::"$'\n'
    fi
    _zetopt::parser::init
    _zetopt::data::init
    
    local optname= optarg= idx= optsign= added_cnt=0 args
    local namespace=/ ns= check_subcmd=true error_subcmd_name=
    
    # internal global variables
    declare -i _CONSUMED_ARGS_COUNT=0
    local _ZETOPT_CFG_CLUSTERED_AS_LONG="$(_zetopt::utils::is_true -t true "${ZETOPT_CFG_CLUSTERED_AS_LONG-}")"
    local _ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN="$(_zetopt::utils::is_true -t true "${ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN-}")"
    local _ZETOPT_CFG_IGNORE_BLANK_STRING="$(_zetopt::utils::is_true -t true "${ZETOPT_CFG_IGNORE_BLANK_STRING-}")"
    local _ZETOPT_CFG_OPTTYPE_PLUS="$(_zetopt::utils::is_true -t true "${ZETOPT_CFG_OPTTYPE_PLUS-}")"
    local _ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR="$(_zetopt::utils::is_true -t true "${ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR-}")"

    if ! _zetopt::parser::setsub $namespace; then
        _zetopt::msg::script_error "Invalid Definition Data:" "Root Namespace Not Found"
        return 1
    fi

    args=()
    while [[ $# -ne 0 ]]
    do
        _CONSUMED_ARGS_COUNT=0
        
        if [[ $1 == -- ]]; then
            if [[ $_ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN != true ]]; then
                shift
                ZETOPT_ARGS+=("$@")
                break
            else
                ZETOPT_ARGS+=("$1")
                shift
            fi
            check_subcmd=false
        elif [[ $1 =~ ^[-+]$ ]]; then
            ZETOPT_ARGS+=("$1")
            shift
            check_subcmd=false

        elif [[ $1 == "" ]]; then
            if [[ $_ZETOPT_CFG_IGNORE_BLANK_STRING == true ]]; then
                shift
                continue
            fi
            ZETOPT_ARGS+=("$1")
            shift
            check_subcmd=false
                
        # long option or clustered short options with ZETOPT_CFG_CLUSTERED_AS_LONG enabled
        elif [[ $1 =~ ^-- || ($_ZETOPT_CFG_CLUSTERED_AS_LONG == true && $1 =~ ^-[^-]. ) ]]; then
            if [[ ! $1 =~ ^--?[a-zA-Z0-9_] ]]; then
                ZETOPT_OPTERR_INVALID+=("$1")
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_INVALID_OPTFORMAT))
                shift
                check_subcmd=false
            fi

            if [[ $1 =~ ^-[^-]. && $_ZETOPT_CFG_CLUSTERED_AS_LONG == true ]]; then
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
                    shift
                    check_subcmd=false
                    continue
                fi

                added_cnt=1
                shift
                _zetopt::parser::setopt $namespace $optsign $optname "$optarg" "$@" ||:
            else
                optname="${1#*${optsign}}"
                shift
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
                    shift
                    check_subcmd=false
                    continue
                fi
                added_cnt=1
            else
                optname="${1#*-}"
            fi
            shift

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
        elif [[ $1 =~ ^[+] && $_ZETOPT_CFG_OPTTYPE_PLUS == true ]]; then
            if [[ ! $1 =~ ^[+][a-zA-Z0-9_] ]]; then
                ZETOPT_OPTERR_INVALID+=("$1")
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_INVALID_OPTFORMAT))
                shift
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
                    shift
                    check_subcmd=false
                    continue
                fi
                added_cnt=1
            else
                optname="${1#*+}"
            fi
            shift

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
                if ! _zetopt::def::exists "$ns"; then
                    check_subcmd=false
                    if [[ $_ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR == true ]]; then
                        ZETOPT_ARGS+=("$1")
                        shift
                        continue
                    fi
                    error_subcmd_name="${ns//\// }"
                    _zetopt::msg::user_error Error "Undefined Sub-Command:" "$error_subcmd_name"
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_SUBCMD))
                    break
                fi

                # change namespace
                if _zetopt::parser::setsub $ns; then
                    namespace=$ns
                    ZETOPT_LAST_COMMAND=$ns
                fi
                shift
                continue
            fi

            # a regular positional argument
            ZETOPT_ARGS+=("$1")
            shift
        fi

        # shift
        if [[ $(($_CONSUMED_ARGS_COUNT - $added_cnt)) -gt 0 ]]; then
            shift $(($_CONSUMED_ARGS_COUNT - $added_cnt))
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
    if [[ ! $'\n'$_ZETOPT_PARSED =~ (.*$'\n')((${id}):([^:]*):([^:]*):([^:]*):([^:]*))($'\n'.*) ]]; then
        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_SUBCMD))
        return $ZETOPT_STATUS_UNDEFINED_SUBCMD
    fi

    local head_lines="${BASH_REMATCH[$((1 + ZETOPT_IDX_OFFSET))]:1}"
    local tail_lines="${BASH_REMATCH[$((8 + ZETOPT_IDX_OFFSET))]}"
    local offset=2

    local IFS=:
    \set -- ${BASH_REMATCH[$((offset + ZETOPT_IDX_OFFSET + ZETOPT_FIELD_DATA_ALL))]}
    local cnt=$(($5 + 1))
    _ZETOPT_PARSED=$head_lines$1:$2:$ZETOPT_TYPE_CMD:$ZETOPT_STATUS_NORMAL:$cnt$tail_lines
}

# Set option data. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::setopt {NAMESPACE} {OPTSIGN} {OPTNAME} {ARGUMENTS}
# e.g.) _zetopt::parser::setopt /sub/cmd - version "$@"
# STDOUT: NONE
_zetopt::parser::setopt()
{
    local namespace="${1-}" optsign="${2-}" opt="${3-}" args
    shift 3
    args=("$@")

    local id="$(_zetopt::def::opt2id "$namespace" "$opt")"
    if [[ -z $id ]]; then
        ZETOPT_OPTERR_UNDEFINED+=("$optsign$opt")
        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_OPTION))
        return 1
    fi

    if [[ ! $'\n'$_ZETOPT_PARSED =~ (.*$'\n')((${id}):([^:]*):([^:]*):([^:]*):([^:]*))($'\n'.*) ]]; then
        return 1
    fi
    local head_lines="${BASH_REMATCH[$((1 + ZETOPT_IDX_OFFSET))]:1}"
    local tail_lines="${BASH_REMATCH[$((8 + ZETOPT_IDX_OFFSET))]}"
    local IFS=:
    \set -- ${BASH_REMATCH[$((2 + ZETOPT_IDX_OFFSET + ZETOPT_FIELD_DATA_ALL))]}
    local id="$1" refs_str="$2" types="$3" stat="$4" cnt="$5"
    local curr_stat=$ZETOPT_STATUS_NORMAL

    local ref_arr paramdef_str="$(_zetopt::def::field "$id" $ZETOPT_FIELD_DEF_ARG)"
    declare -i optarg_idx=$((${#_ZETOPT_OPTVALS[@]} + $ZETOPT_IDX_OFFSET))
    ref_arr=()

    # options requiring NO argument
    if [[ -z $paramdef_str ]]; then
        [[ $optsign =~ ^--?$ ]] \
        && _ZETOPT_OPTVALS+=("${ZETOPT_CFG_FLAGVAL_TRUE:-0}") \
        || _ZETOPT_OPTVALS+=("${ZETOPT_CFG_FLAGVAL_FALSE:-1}")
        ref_arr=($optarg_idx)

    # options requiring arguments
    else
        IFS=$' '
        \set -- $paramdef_str
        local arg def def_arr varlen_mode=false no_avail_args=false
        declare -i def_len=$(($# + ZETOPT_IDX_OFFSET)) def_idx=$ZETOPT_IDX_OFFSET
        declare -i arg_cnt=0 arg_max arg_idx=$ZETOPT_IDX_OFFSET arg_len=$((${#args[@]} + $ZETOPT_IDX_OFFSET))
        def_arr=($@)

        while [[ $def_idx -lt $def_len ]]
        do
            def=${def_arr[$def_idx]}

            # there are available args 
            if [[ $arg_idx -lt $arg_len ]]; then
                arg="${args[$arg_idx]}"
                if [[ $arg == "" && $_ZETOPT_CFG_IGNORE_BLANK_STRING == true ]]; then
                    arg_idx+=1
                    continue
                fi

                # check arg format
                if [[ $arg =~ ^[^-+]
                    || $arg =~ ^[-+]$
                    || $arg == ""
                    || ($arg =~ ^-[^-] && $def =~ ^-[^-])
                    || ($arg != "--" && $arg =~ ^- && $def =~ ^--)
                    || ($arg =~ ^[+] && $def =~ ^--? && $_ZETOPT_CFG_OPTTYPE_PLUS == true)
                    || ($arg == "--" && $_ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN -eq 0)
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
                        arg_max=$(_zetopt::def::paramlen $id max)
                    fi

                    if [[ $varlen_mode == true && $arg_cnt -ge $arg_max ]]; then
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
                ZETOPT_OPTERR_MISSING_REQUIRED+=("$optsign$opt")
            
            # optional
            else
                while [[ $def_idx -lt $def_len ]]
                do
                    def=${def_arr[$def_idx]}

                    # has default value
                    if [[ $def =~ ([.]{3,3}([1-9][0-9]*)?)?=([1-9][0-9]*) ]]; then
                        arg=${_ZETOPT_DEFAULTS[${BASH_REMATCH[$((3 + ZETOPT_IDX_OFFSET))]}]}
                        _ZETOPT_OPTVALS+=("$arg")
                        ref_arr+=($optarg_idx)
                        optarg_idx+=1
                        def_idx+=1
                        continue
                    
                    # warning: missing optional optarg
                    else
                        curr_stat=$ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS
                        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | curr_stat))
                        ZETOPT_OPTERR_MISSING_OPTIONAL+=("$optsign$opt")
                        break
                    fi
                done
            fi
        fi
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
        refs_str="${ref_arr[*]-}"
        types="$type"
    else
        stat="$stat $curr_stat"
        refs_str="$refs_str,${ref_arr[*]-}"
        types+=" $type"
    fi
    : $((cnt++))

    _ZETOPT_PARSED="$head_lines$id:$refs_str:$types:$stat:$cnt$tail_lines"
    [[ $curr_stat -le $ZETOPT_STATUS_ERROR_THRESHOLD ]]
}

_zetopt::parser::validate()
{
    local param_def="${1-}" arg="${2-}"

    # no validator
    if [[ ! $param_def =~ [~]([1-9][0-9]*) ]]; then
        return 0
    fi

    declare -i validator_idx="${BASH_REMATCH[$((1 + ZETOPT_IDX_OFFSET))]}"
    if [[ ! ${_ZETOPT_VALIDATOR_DATA[$validator_idx]} =~ ^([^:]+):([rf]):([in]*):([0-9]+):(.*)$ ]]; then
        _zetopt::msg::script_error "Internal Error:" "Validator Broken"
        return 1
    fi
    local validator_name="${BASH_REMATCH[$((1 + ZETOPT_IDX_OFFSET))]}"
    local validator_type="${BASH_REMATCH[$((2 + ZETOPT_IDX_OFFSET))]}"
    local validator_flags="${BASH_REMATCH[$((3 + ZETOPT_IDX_OFFSET))]}"
    declare -i validator_msgidx="${BASH_REMATCH[$((4 + ZETOPT_IDX_OFFSET))]}"
    local validator="${BASH_REMATCH[$((5 + ZETOPT_IDX_OFFSET))]}"

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
            _zetopt::msg::user_error Error "Validator \"$validator_name\" Failed: $arg:" "$errmsg"
        fi
        return 1
    fi
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
        ref_arr=($(\eval "\echo {$ZETOPT_IDX_OFFSET..$((def_max_len - 1 + ZETOPT_IDX_OFFSET))}"))

        # validate
        if [[ $has_validator == true ]]; then
            maxloop=$def_len+$ZETOPT_IDX_OFFSET
            for ((idx=ZETOPT_IDX_OFFSET; idx<maxloop; idx++))
            do
                if ! _zetopt::parser::validate "${def_arr[idx]}" "${ZETOPT_ARGS[ref_arr[idx]]}"; then
                    rtn=$((rtn | ZETOPT_STATUS_VALIDATOR_FAILED))
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                fi
            done
        fi

        # too match arguments
        if [[ $arg_len -gt $def_max_len ]]; then
            if [[ ${def_arr[$((def_len - 1 + ZETOPT_IDX_OFFSET))]} =~ [.]{3,3}[1-9][0-9]*=[0-9]+$ ]]; then
                rtn=$((rtn | ZETOPT_STATUS_TOO_MATCH_ARGS))
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
            fi
        fi

    # not enough
    else
        declare -i ref_idx=$ZETOPT_IDX_OFFSET
        if [[ $arg_len -ne 0 ]]; then
            ref_idx=$arg_len-1+$ZETOPT_IDX_OFFSET
            ref_arr=($(\eval "\echo {$ZETOPT_IDX_OFFSET..$ref_idx}"))
            ref_idx+=1

            # validate
            if [[ $has_validator == true ]]; then
                maxloop=$arg_len+$ZETOPT_IDX_OFFSET
                for ((idx=ZETOPT_IDX_OFFSET; idx<maxloop; idx++))
                do
                    if ! _zetopt::parser::validate "${def_arr[idx]}" "${ZETOPT_ARGS[ref_arr[idx]]}"; then
                        rtn=$((rtn | ZETOPT_STATUS_VALIDATOR_FAILED))
                        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                    fi
                done
            fi
        fi

        declare -i def_loops=$def_len+$ZETOPT_IDX_OFFSET default_idx
        for ((; ref_idx<def_loops; ref_idx++))
        do
            # missing required
            if [[ ! ${def_arr[ref_idx]} =~ ^-{0,2}%([A-Za-z_][A-Za-z0-9_]*)?[.][0-9]+[~][0-9]+([.]{3,3}([1-9][0-9]*)?)?=([0-9]+)$ ]]; then
                rtn=$((rtn | ZETOPT_STATUS_MISSING_REQUIRED_ARGS))
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                break
            fi
            default_idx=${BASH_REMATCH[$((4 + ZETOPT_IDX_OFFSET))]}

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
    if [[ ! $'\n'$_ZETOPT_PARSED =~ (.*$'\n')((${id}):([^:]*):([^:]*):([^:]*):([^:]*))($'\n'.*) ]]; then
        return 1
    fi
    local head_lines="${BASH_REMATCH[$((1 + ZETOPT_IDX_OFFSET))]:1}"
    local tail_lines="${BASH_REMATCH[$((8 + ZETOPT_IDX_OFFSET))]}"
    local offset=2
    local line="${BASH_REMATCH[$((offset + ZETOPT_IDX_OFFSET + ZETOPT_FIELD_DATA_ALL))]}"
    local id="${BASH_REMATCH[$((offset + ZETOPT_IDX_OFFSET + ZETOPT_FIELD_DATA_ID))]}"
    #local arg="${BASH_REMATCH[$((offset + ZETOPT_IDX_OFFSET + ZETOPT_FIELD_DATA_ARG))]}"
    local type="${BASH_REMATCH[$((offset + ZETOPT_IDX_OFFSET + ZETOPT_FIELD_DATA_TYPE))]}"
    #local status="${BASH_REMATCH[$((offset + ZETOPT_IDX_OFFSET + ZETOPT_FIELD_DATA_STATUS))]}"
    local count="${BASH_REMATCH[$((offset + ZETOPT_IDX_OFFSET + ZETOPT_FIELD_DATA_COUNT))]}"
    IFS=' '
    local refs_str="${ref_arr[*]}"
    _ZETOPT_PARSED="$head_lines$id:$refs_str:$type:$rtn:$count$tail_lines"
    return $rtn
}
