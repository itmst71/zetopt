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

    if [[ ! $LF${_ZETOPT_PARSED-}$LF =~ .*$LF((${id}[+/]?):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))$LF.* ]]; then
        return 1
    fi
    case "$field" in
        $ZETOPT_DATAID_ALL)    printf -- "%s\n" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_ALL))]}";;
        $ZETOPT_DATAID_ID)     printf -- "%s\n" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_ID))]}";;
        $ZETOPT_DATAID_ARGV)   printf -- "%s\n" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_ARGV))]}";;
        $ZETOPT_DATAID_ARGC)   printf -- "%s\n" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_ARGC))]}";;
        $ZETOPT_DATAID_TYPE)   printf -- "%s\n" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_TYPE))]}";;
        $ZETOPT_DATAID_PSEUDO) printf -- "%s\n" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_PSEUDO))]}";;
        $ZETOPT_DATAID_STATUS) printf -- "%s\n" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_STATUS))]}";;
        $ZETOPT_DATAID_COUNT)  printf -- "%s\n" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_COUNT))]}";;
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
        [[ $LF${_ZETOPT_PARSED-} =~ $LF$id && ! $LF${_ZETOPT_PARSED-} =~ $LF${id}[+/]?:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:0 ]] && continue ||:
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
    if [[ $LF$_ZETOPT_PARSED =~ $LF${id}[+/]?:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:0 ]]; then
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
    local lists_last_idx="$((${#lists[@]} - 1 + $INIT_IDX))"
    
    IFS=' '
    if [[ $# -eq 0 ]]; then
        output_list=(${lists[$lists_last_idx]})
    else
        local list_last_vals
        list_last_vals=(${lists[$lists_last_idx]})
        local val_lastlist_lastidx=$((${#list_last_vals[@]} - 1 + $INIT_IDX))

        local input_idx= tmp_list
        for input_idx in "$@"
        do
            if [[ ! $input_idx =~ ^(@|([$\^$INIT_IDX]|-?[1-9][0-9]*)?(,([$\^$INIT_IDX]|-?[1-9][0-9]*)?)?)?(:?(@|(([$\^$INIT_IDX]|-?[1-9][0-9]*)?(,([$\^$INIT_IDX]|-?[1-9][0-9]*)?)?)?)?)?$ ]]; then
                _zetopt::msg::script_error "Bad Key:" "$input_idx"
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
                tmp_list_start_idx=${tmp_list_start_idx:-^}
                tmp_list_end_idx="${tmp_list_end_idx:-$}"
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
                _zetopt::msg::script_error "List Index Out of Range ($INIT_IDX~$lists_last_idx)" "Translate \"$tmp_list_idx\" -> $translated_idx"
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

            local list_idx= val_idx= maxidx= val_start_idx= val_end_idx=
            tmp_list=()
            for list_idx in $(eval "echo {$list_start_idx..$list_end_idx}")
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
                    _zetopt::msg::script_error "Value Index Out of Range ($INIT_IDX~$maxidx):" "Translate \"$tmp_val_idx\" -> $translated_idx"
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
    local __out_mode__=stdout __usrvar_name__= __newline__=$LF __fallback__=true
    local __args__ __ifs__=${ZETOPT_CFG_VALUE_IFS-$' '}
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
            if [[ ! $__tmp_varname__ =~ ^$REG_VNAME$ ]] || [[ $__tmp_varname__ =~ ((^_$)|(^__[a-zA-Z0-9][a-zA-Z0-9_]*__$)) ]]; then
                _zetopt::msg::script_error "Invalid Variable Name:" "$__tmp_varname__"
                return 1
            fi
        done
        __usrvar_names__=($@)
    fi

    local __id__="${__args__[$((0 + $INIT_IDX))]=$ZETOPT_LAST_COMMAND}"
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
        if [[ ${#__data__[@]} -lt ${#__default_data__[@]} ]]; then
            __data__=($(echo "${__data__[@]}" "${__default_data__[@]:${#__data__[@]}:$((${#__default_data__[@]} - ${#__data__[@]}))}"))
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
    declare -i __idx__= __i__=$INIT_IDX __max__=$(($# + INIT_IDX - 1))
    declare -i __vi__=$INIT_IDX __vmax__=$((${#__usrvar_names__[@]} + INIT_IDX - 1))
    local __varname__= __nl__=

    if [[ $__out_mode__ == array ]]; then
        __varname__=${__usrvar_names__[$INIT_IDX]}
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
            --init)
                __action__=init
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
        if [[ ! $__user_array__ =~ $REG_VNAME ]]; then
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
        __id__="${__args__[$((0 + $INIT_IDX))]=${ZETOPT_LAST_COMMAND}}"
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

    # already exists ?
    local __intlvar_exists__="$( [[ -n $(eval 'echo ${'$__intlvar_array__'+x}') || -n $(eval 'echo ${'$__intlvar_index__'+x}') ]] && echo true || echo false)"

    case $__action__ in
        # --reset resets index
        reset)
            if [[ $__intlvar_exists__ == true ]]; then
                eval $__intlvar_index__'=$INIT_IDX'
                return 0
            fi
            return 1;;

        # --unset unsets array and index
        unset)
            unset $__intlvar_array__ ||:
            unset $__intlvar_index__ ||:
            return 0;;

        # --has-next checks next item existence
        has-next)
            if [[ $__intlvar_exists__ == false ]]; then
                return 1
            fi
            local __max__=$(eval 'echo $((${#'$__intlvar_array__'[@]} - 1 + INIT_IDX))')
            if [[ $(($(eval 'echo $'$__intlvar_index__) + 1 )) -gt $__max__ ]]; then
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
        if [[ ! $__tmp_varname__ =~ ^$REG_VNAME$ ]] || [[ $__tmp_varname__ =~ ((^_$)|(^__[a-zA-Z0-9][a-zA-Z0-9_]*__$)|(^IFS$)) ]]; then
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
            local __end__=$(($(eval 'echo ${#'$__user_array__'[@]}') - 1 + $INIT_IDX))
            local __list_str__="$(_zetopt::data::pickup "$(eval 'echo {'$INIT_IDX'..'$__end__'}')" "${__args__[@]}")"
            if [[ -z "$__list_str__" ]]; then
                return 1
            fi
            declare -i __idx__= __i__=$INIT_IDX
            eval $__intlvar_index__'=$INIT_IDX'
            eval $__intlvar_array__'=()'
            set -- $__list_str__
            for __idx__ in "$@"
            do
                eval $__intlvar_array__'[$__i__]=${'$__user_array__'[$__idx__]}'
                __i__+=1
            done

        # use parsed data array
        else
            if _zetopt::data::output $__dataid__ $__complemented_id__ "${__args__[@]}" -a $__intlvar_array__ $__no_fallback_option__; then
                eval $__intlvar_index__'=$INIT_IDX'

            # unset and return error if failed
            else
                unset $__intlvar_array__ ||:
                unset $__intlvar_index__ ||:
                return 1
            fi
        fi

        # init returns at this point
        if [[ $__action__ == init ]]; then
            return 0
        fi
    else
        # increment index only if -v option specified and already initialized
        if [[ -n $__usrvar_value__ ]]; then
            eval $__intlvar_index__'=$(('$__intlvar_index__' + 1))'
        fi
    fi
    
    # has no next
    local __max__=$(eval 'echo $((${#'$__intlvar_array__'[@]} + INIT_IDX))')
    if [[ $(eval 'echo $'$__intlvar_index__) -ge $__max__ ]]; then
        unset $__intlvar_array__ ||:
        unset $__intlvar_index__ ||:
        return 1
    fi


    # last-index / array / count
    [[ -n $__usrvar_last_index__ ]] && eval $__usrvar_last_index__'=$((${#'$__intlvar_array__'[@]} - 1 + $INIT_IDX))' ||:
    [[ -n $__usrvar_array__ ]] && eval $__usrvar_array__'=("${'$__intlvar_array__'[@]}")' ||:
    [[ -n $__usrvar_count__ ]] && eval $__usrvar_count__'=${#'$__intlvar_array__'[@]}' ||:

    # value / index : Iterate with multiple values/indexs
    if [[ -n $__usrvar_value__ || -n $__usrvar_index__ ]]; then
        local __idx__= __first_loop__=true
        local __max_idx__=$(($([[ -n $__usrvar_value__ ]] && echo ${#__usrvar_value_names__[@]} || echo ${#__usrvar_index_names__[@]}) + $INIT_IDX))
        for (( __idx__=INIT_IDX; __idx__<__max_idx__; __idx__++ ))
        do
            # index
            if [[ -n $__usrvar_index__ ]]; then
                eval ${__usrvar_index_names__[$__idx__]}'=$'$__intlvar_index__ ||:
            fi

            # value
            if [[ -n $__usrvar_value__ ]]; then
                # increment index only when first loop
                if [[ $__first_loop__ == false ]]; then
                    eval $__intlvar_index__'=$(('$__intlvar_index__' + 1))'
                    if [[ $(eval 'echo $'$__intlvar_index__) -ge $__max__ ]]; then
                        break
                    fi
                fi
                eval ${__usrvar_value_names__[$__idx__]}'="${'$__intlvar_array__'[$'$__intlvar_index__']}"' ||:
                __first_loop__=false
            fi
        done

        # substitute NULL_VALUE/NULL_KEY if breaking the previous loop because of __intlvar_array__ being short
        for (( __idx__++; __idx__<__max_idx__; __idx__++ ))
        do
            # value
            if [[ -n $__usrvar_value__ ]]; then
                eval ${__usrvar_value_names__[$__idx__]}'=$__null_value__' ||:
            fi

            # key
            if [[ -n $__usrvar_index__ ]]; then
                eval ${__usrvar_index_names__[$__idx__]}'=$__null_index__' ||:
            fi
        done
    fi
    return 0
}

# setids(): Print the list of IDs set
# def.) _zetopt::data::setids
# e.g.) _zetopt::data::setids
# STDOUT: string separated with \n
_zetopt::data::setids()
{
    local lines="$_ZETOPT_PARSED"
    while [[ $LF$lines =~ $LF([^:]+):[^$LF]+:[1-9][0-9]*$LF(.*) ]]
    do
        printf -- "%s\n" "${BASH_REMATCH[$((1 + $INIT_IDX))]}"
        lines=${BASH_REMATCH[$((2 + $INIT_IDX))]}
    done
}