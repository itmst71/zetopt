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
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "zetopt def-validator [-f | --function] [-i | --ignore-case] [-n | --not] {<NAME> <REGEXP | FUNCNAME> [#<ERROR_MESSAGE>]}"
        return 1
    fi
    if [[ ! $name =~ ^$REG_VNAME$ ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "Invalid Validator Name:" "$name"
        return 1
    fi
    if [[ $type == f ]]; then
        [[ -n ${ZSH_VERSION-} ]] \
        && local _type=$(whence -w "$validator") \
        || local _type=$(type -t "$validator")
        if [[ ! ${_type#*:} =~ function ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "No Such Shell Function:" "$validator"
            return 1
        fi
    fi
    if [[ $LF$_ZETOPT_VALIDATOR_KEYS =~ $LF$name: ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "Duplicate Validator Name:" "$name"
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
    set -- ${BASH_REMATCH[$((1 + INIT_IDX))]}
    IFS=$' \t\n'

    while [[ $# -ne 0 ]]
    do
        declare -i validator_idx=$1
        shift 1

        if [[ ! ${_ZETOPT_VALIDATOR_DATA[$validator_idx]} =~ ^([^:]+):([rf]):([in]*):([0-9]+):(.*)$ ]]; then
            _zetopt::msg::script_error "Internal Error:" "Validator Broken"
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
            else
                local PATH=$_PATH LC_ALL=$_LC_ALL LANG=$_LANG
                if [[ ! $validator_flags =~ n ]]; then
                    printf -- "%s" "$(out=$("$validator" "$arg" 2>&1) && printf -- "%s" "true:" || printf -- "%s" "false:$out")"
                else
                    printf -- "%s" "$(out=$("$validator" "$arg" 2>&1) && printf -- "%s" "false:$out" || printf -- "%s" "true:")"
                fi
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
