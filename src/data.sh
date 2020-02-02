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
    ZETOPT_ARGS=()
    ZETOPT_EXTRA_ARGV=()
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
        *) return 1;;
    esac
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
        $ZETOPT_FIELD_DATA_ARGV | $ZETOPT_FIELD_DATA_ARGC | $ZETOPT_FIELD_DATA_TYPE | $ZETOPT_FIELD_DATA_PSEUDO | $ZETOPT_FIELD_DATA_STATUS) :;;
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
    local __out_mode=stdout __var_name= __newline=
    local __args __ifs=${ZETOPT_CFG_VALUE_IFS-$' '}
    __args=()

    while [[ $# -ne 0 ]]
    do
        case "$1" in
            -a | --array)
                __out_mode=array
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Argument:" "-a, --array <ARRAY_NAME>"
                    return 1
                fi
                __var_name=$1
                shift
                ;;
            -v | --variable)
                __out_mode=variable
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Argument:" "-v, --variable <VARIABLE_NAME>"
                    return 1
                fi
                __var_name=$1
                shift
                ;;
            -I | --IFS)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Argument:" "-I, --IFS <IFS_VALUE>"
                    return 1
                fi
                __ifs=$1
                shift
                ;;
            -n) __newline=$LF; shift;;
            --) shift; __args+=("$@"); break;;
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
    if [[ -z ${__args[$((0 + $INIT_IDX))]-} ]]; then
        return 1
    fi

    local __id="${__args[$((0 + $INIT_IDX))]}"
    if ! _zetopt::def::exists "$__id"; then
        _zetopt::msg::debug "No Such ID:" "$__id" 
        return 1
    fi
    [[ ! $__id =~ ^/ ]] && __id="/$__id" ||:
    
    local __keys=${__args[@]:1}
    if [[ -z $__keys ]]; then
        [[ $__field == $ZETOPT_FIELD_DATA_ARGV ]] \
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
    if [[ $__field =~ ^[$ZETOPT_FIELD_DATA_ARGV$ZETOPT_FIELD_DATA_PSEUDO]$ ]]; then
        __args=("${_ZETOPT_DATA[@]}")
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
    local __args__ __reset__=false
    local __user_value__= __user_key__= __user_last_key__= __user_array__=
    __args__=()
    while [[ $# -ne 0 ]]
    do
        case "$1" in
            -v|--value)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Argument:" "-v, --value <VARIABLE_NAME_FOR_VALUE>"
                    return 1
                fi
                __user_value__=$1
                shift
                ;;
            -k|--key)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Argument:" "-k, --key <VARIABLE_NAME_FOR_KEY>"
                    return 1
                fi
                __user_key__=$1
                shift
                ;;
            -l|--last-key)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Argument:" "-l, --last-key <VARIABLE_NAME_FOR_LAST_KEY>"
                    return 1
                fi
                __user_last_key__=$1
                shift
                ;;
            -a|--array)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Argument:" "-a, --array <VARIABLE_NAME_FOR_ARRAY>"
                    return 1
                fi
                __user_array__=$1
                shift
                ;;
            --reset)
                __reset__=true
                shift
                ;;
            --*|-[a-zA-Z])
                _zetopt::msg::debug "Undefined Option:" "$1"
                return 1
                ;;
            --) shift; __args__+=("$@"); break;;
            *)  __args__+=("$1"); shift;;
        esac
    done

    # make variable names based on ID
    local __id__="${__args__[$((0 + $INIT_IDX))]}"
    if ! _zetopt::def::exists "$__id__"; then
        _zetopt::msg::debug "No Such ID:" "$__id__" 
        return 1
    fi
    [[ ! $__id__ =~ ^/ ]] && __id__="/$__id__" ||:

    __id__=${__id__:1}
    __id__=${__id__//[\/\-]/_}
    local __prefix__=_zetopt_iterator_$__id__
    local __array__=${__prefix__}_array__
    local __index__=${__prefix__}_index__
    if [[ $__reset__ == true ]]; then
        unset $__array__
        unset $__index__
        return 0
    fi

    # check the user defined variable name before eval to avoid overwriting local variables
    for __tmp_var_name__ in "$__user_value__" "$__user_key__" "$__user_last_key__" "$__user_array__"
    do
        [[ -z $__tmp_var_name__ ]] && continue ||:
        if [[ ! $__tmp_var_name__ =~ ^[a-zA-Z_]([0-9a-zA-Z_]+)*$ ]] || [[ $__tmp_var_name__ =~ ((^_$)|(^__[0-9a-zA-Z][0-9a-zA-Z_]*__$)|(^IFS$)) ]]; then
            _zetopt::msg::debug "Invalid Variable Name:" "$__tmp_var_name__"
            return 1
        fi
    done

    # initialize if unbound
    if [[ ! -n $(eval 'echo ${'$__array__'+x}') || ! -n $(eval 'echo ${'$__index__'+x}') ]]; then
        if _zetopt::data::print $ZETOPT_FIELD_DATA_ARGV "${__args__[@]}" -a $__array__; then
            eval $__index__'=$INIT_IDX'

        # unset and return error if failed
        else
            unset $__array__
            unset $__index__
            return 1
        fi
    fi

    # no next
    if [[ $__index__ -ge $(eval 'echo $((${#'$__array__'[@]} + INIT_IDX))') ]]; then
        unset $__array__
        unset $__index__
        return 1
    fi

    [[ -n $__user_value__ ]] && eval $__user_value__'="${'$__array__'[$'$__index__']}"' ||:
    [[ -n $__user_key__ ]] && eval $__user_key__'=$'$__index__ ||:
    [[ -n $__user_last_key__ ]] && eval $__user_last_key__'=$((${#'$__array__'[@]} - 1 + $INIT_IDX))' ||:
    [[ -n $__user_array__ ]] && eval $__user_array__'=("${'$__array__'[@]}")' ||:

    eval $__index__'=$(('$__index__' + 1))'
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
