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
