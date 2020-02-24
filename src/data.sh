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
    if [[ $_ZETOPT_DEFAULT_COUNT -ne 0 ]]; then
        # remove data other than default values
        _ZETOPT_DATA=("${_ZETOPT_DATA[@]:0:$_ZETOPT_DEFAULT_COUNT}")
    else
        _ZETOPT_DATA=()
    fi
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
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    local field="${2:-$ZETOPT_DATAID_ALL}"

    if [[ $field == $ZETOPT_DATAID_DEFAULT ]]; then
        if ! _zetopt::def::exists $id; then
            return 1
        fi
        \printf -- "%s" "$(_zetopt::def::default $id)"
        return 0
    fi

    if [[ ! $LF${_ZETOPT_PARSED-}$LF =~ .*$LF(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))$LF.* ]]; then
        return 1
    fi
    case "$field" in
        $ZETOPT_DATAID_ALL)    \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_ALL))]}";;
        $ZETOPT_DATAID_ID)     \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_ID))]}";;
        $ZETOPT_DATAID_ARGV)   \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_ARGV))]}";;
        $ZETOPT_DATAID_ARGC)   \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_ARGC))]}";;
        $ZETOPT_DATAID_TYPE)   \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_TYPE))]}";;
        $ZETOPT_DATAID_PSEUDO) \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_PSEUDO))]}";;
        $ZETOPT_DATAID_STATUS) \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_STATUS))]}";;
        $ZETOPT_DATAID_COUNT)  \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_DATAID_COUNT))]}";;
        $ZETOPT_DATAID_EXTRA_ARGV) \printf -- "%s" "$(_zetopt::data::extra_field $id)";;
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
        \echo "${_ZETOPT_EXTRA_ARGV[@]-}"
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
        [[ $LF${_ZETOPT_PARSED-} =~ $LF$id && ! $LF${_ZETOPT_PARSED-} =~ $LF$id:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:0 ]] && continue ||:
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
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if ! _zetopt::def::exists "$id"; then
        return 1
    fi
    if [[ $LF$_ZETOPT_PARSED =~ $LF$id:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:0 ]]; then
        return 1
    fi

    shift
    local status_list="$(_zetopt::data::print $ZETOPT_DATAID_STATUS "$id" "$@")"
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
                _zetopt::msg::script_error "Session Index Out of Range ($INIT_IDX~$lists_last_idx)" "Translate \"$tmp_list_idx\" -> $translated_idx"
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
                    _zetopt::msg::script_error "Value Index Out of Range ($INIT_IDX~$maxidx):" "Translate \"$tmp_val_idx\" -> $translated_idx"
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
    local argc_str="$(_zetopt::data::print $ZETOPT_DATAID_ARGC "$@")"
    [[ -n "$argc_str" && ! "$argc_str" =~ ^[0\ ]+$ ]]
}


# print(): Print field data with keys.
# -a/-v enables to store data in user specified array/variable.
# def.) _zetopt::data::print {FIELD_NUMBER} {ID} [1D/2D-KEY...] [-a,--array <ARRAY_NAME> | -v,--variable <VARIABLE_NAME>] [-I,--IFS <IFS_VALUE>]
# e.g.) _zetopt::data::print $ZETOPT_DATAID_ARGV /foo @:@ --array myarr
# STDOUT: data option names separated with $ZETOPT_CFG_VALUE_IFS or --IFS value
_zetopt::data::print()
{
    if [[ $# -eq 0 ]]; then
        return 1
    fi
    local __field=$1
    shift
    local __out_mode=stdout __var_name= __newline=$LF __fallback=true
    local __args __ifs=${ZETOPT_CFG_VALUE_IFS-$' '}
    __args=()

    while [[ $# -ne 0 ]]
    do
        case "$1" in
            -a | --array)
                __out_mode=array
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-a, --array <ARRAY_NAME>"
                    return 1
                fi
                __var_name=$1
                shift
                ;;
            -v | --variable)
                __out_mode=variable
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-v, --variable <VARIABLE_NAME>"
                    return 1
                fi
                __var_name=$1
                shift
                ;;
            -I | --IFS)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-I, --IFS <IFS_VALUE>"
                    return 1
                fi
                __ifs=$1
                shift
                ;;
            -E | --extra) __field=$ZETOPT_DATAID_EXTRA_ARGV; shift;;
            -N | --no-fallback) __fallback=false; shift;;
            -n | --no-newline) __newline=; shift;;
            --) shift; __args+=("$@"); break;;
            --*|-[a-zA-Z])
                _zetopt::msg::script_error "Undefined Option:" "$1"
                return 1;;
            *)  __args+=("$1"); shift;;
        esac
    done

    if [[ $__out_mode =~ ^(array|variable)$ ]]; then
        # check the user defined variable name before eval to avoid overwriting local variables
        if [[ ! $__var_name =~ ^$REG_VNAME$ ]] || [[ $__var_name =~ ((^_$)|(^__[a-zA-Z0-9][a-zA-Z0-9_]*$)|(^IFS$)) ]]; then
            _zetopt::msg::script_error "Invalid Variable Name:" "$__var_name"
            return 1
        fi
        case $__out_mode in
            array) \eval "$__var_name=()";;
            variable) \eval "$__var_name=";;
        esac
    fi

    local IFS=' '
    local __id="${__args[$((0 + $INIT_IDX))]=$ZETOPT_LAST_COMMAND}"
    if ! _zetopt::def::exists "$__id"; then
        _zetopt::msg::script_error "No Such ID:" "$__id" 
        return 1
    fi
    [[ ! $__id =~ ^/ ]] && __id="/$__id" ||:

    if [[ ! $__field =~ ^[$ZETOPT_DATAID_ARGV-$ZETOPT_DATAID_DEFAULT]$ ]]; then
        _zetopt::msg::script_error "Invalid Data ID:" "$__field" 
        return 1
    fi

    local __data
    __data=($(_zetopt::data::field "$__id" $__field))

    # argv fallback default
    if [[ $__field == $ZETOPT_DATAID_ARGV && $__fallback == true ]]; then
        local __default_data
        __default_data=($(_zetopt::def::default $__id))

        # merge parsed data with default data if parsed is short
        if [[ ${#__data[@]} -lt ${#__default_data[@]} ]]; then
            __data=$(echo "${__data[@]}" "${__default_data[@]:${#__data[@]}:$((${#__default_data[@]} - ${#__data[@]}))}")
        fi
    fi

    if [[ -z ${__data[*]-} ]]; then
        _zetopt::msg::script_error "No Data"
        return 1
    fi

    # complement pickup-key
    local __keys="${__args[@]:1}"
    if [[ -z $__keys ]]; then
        [[ $__field =~ ^[$ZETOPT_DATAID_ARGV$ZETOPT_DATAID_EXTRA_ARGV$ZETOPT_DATAID_DEFAULT]$ ]] \
        && __keys=@ \
        || __keys=$
    fi

    # translate param names in key to the numeric index
    __keys=$(_zetopt::def::keyparams2idx $__id "$__keys")

    # pickup data with pickup-keys
    local __list_str="$(_zetopt::data::pickup "${__data[*]}" $__keys)"
    if [[ -z "$__list_str" ]]; then
        return 1
    fi

    declare -i __idx= __i=$INIT_IDX
    \set -- $__list_str
    local __max=$(($# + INIT_IDX - 1))
    local __nl=

    # indexes to refer target data in array
    if [[ $__field =~ ^[$ZETOPT_DATAID_ARGV$ZETOPT_DATAID_PSEUDO$ZETOPT_DATAID_EXTRA_ARGV$ZETOPT_DATAID_DEFAULT]$ ]]; then
        for __idx in "$@"
        do
            # store data in user specified array
            if [[ $__out_mode == array ]]; then
                \eval $__var_name'[$__i]=${_ZETOPT_DATA[$__idx]}'
            else
                if [[ $__i -eq $__max ]]; then
                    __ifs= __nl=$__newline
                fi
                
                # print to STDOUT
                if [[ $__out_mode == stdout ]]; then
                    \printf -- "%s$__ifs$__nl" "${_ZETOPT_DATA[$__idx]}"

                # store data in user specified variable
                else
                    \eval $__var_name'="$'$__var_name'${_ZETOPT_DATA[$__idx]}$__ifs"'
                fi
            fi
            __i+=1
        done

    # target data is itself
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
    local __args__ __action__= __field__=$ZETOPT_DATAID_ARGV
    local __user_value__=ZV_VALUE __user_index__= __user_last_index__= __user_array__= __user_count__=
    local __itr_id__= __null_value__=NULL __null_index__=NULL
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
                __user_value__=$1
                shift;;
            -i | --index)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-i, --index <VARIABLE_NAME_FOR_KEY,...>"
                    return 1
                fi
                __user_index__=$1
                shift;;
            -l | --last-key)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-l, --last-index <VARIABLE_NAME_FOR_LAST_KEY>"
                    return 1
                fi
                __user_last_index__=$1
                shift;;
            -a | --array)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-a, --array <VARIABLE_NAME_FOR_ARRAY>"
                    return 1
                fi
                __user_array__=$1
                shift;;
            -c | --count)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-c, --count <VARIABLE_NAME_FOR_COUNT>"
                    return 1
                fi
                __user_count__=$1
                shift;;
            --nv | --null-value)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-V, --null-value <NULL_VALUE>"
                    return 1
                fi
                __null_value__=$1
                shift;;
            --ni | --null-index)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "-K, --null-key <NULL_KEY>"
                    return 1
                fi
                __null_index__=$1
                shift;;
            --id)
                shift
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::script_error "Missing Required Option Argument:" "--id <ITERATOR_ID>"
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
            -E | --extra | --extra-argv)
                __field__=$ZETOPT_DATAID_EXTRA_ARGV
                shift;;
            --* | -[a-zA-Z])
                _zetopt::msg::script_error "Undefined Option:" "$1"
                return 1;;
            --) shift; __args__+=("$@"); break;;
            *)  __args__+=("$1"); shift;;
        esac
    done
    
    local __id__="${__args__[$((0 + $INIT_IDX))]=${ZETOPT_LAST_COMMAND}}"
    local __complemented_id__=
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

    # make variable names based on ID, KEY or --id <ITERATOR_ID>
    local __var_id_suffix__
    if [[ -n $__itr_id__ ]]; then
        if [[ ! $__itr_id__ =~ ^[a-zA-Z0-9_]+$ ]]; then
            _zetopt::msg::script_error "Invalid Iterator ID:" "$__itr_id__"
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
    set -- $__user_value__ $__user_index__ $__user_last_index__ $__user_array__ $__user_count__
    for __tmp_var_name__ in $@
    do
        [[ -z $__tmp_var_name__ ]] && continue ||:
        if [[ ! $__tmp_var_name__ =~ ^$REG_VNAME$ ]] || [[ $__tmp_var_name__ =~ ((^_$)|(^__[a-zA-Z0-9][a-zA-Z0-9_]*__$)|(^IFS$)) ]]; then
            _zetopt::msg::script_error "Invalid Variable Name:" "$__tmp_var_name__"
            return 1
        fi
    done
    local __user_value_names__ __user_index_names__
    __user_value_names__=($__user_value__)
    __user_index_names__=($__user_index__)
    if [[ (-n $__user_value__ && -n $__user_index__) && (${#__user_value_names__[@]} -ne ${#__user_index_names__[@]}) ]]; then
        _zetopt::msg::script_error "Number of Variables Mismatch :" "--value=$__user_value__ --key=$__user_index__"
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

    # last-index / array / count
    [[ -n $__user_last_index__ ]] && eval $__user_last_index__'=$((${#'$__array__'[@]} - 1 + $INIT_IDX))' ||:
    [[ -n $__user_array__ ]] && eval $__user_array__'=("${'$__array__'[@]}")' ||:
    [[ -n $__user_count__ ]] && eval $__user_count__'=${#'$__array__'[@]}' ||:

    # value / index : Iterate with multiple values/indexs
    if [[ -n $__user_value__ || -n $__user_index__ ]]; then
        local __idx__=
        local __max_idx__=$(($([[ -n $__user_value__ ]] && echo ${#__user_value_names__[@]} || echo ${#__user_index_names__[@]}) + $INIT_IDX))
        for (( __idx__=INIT_IDX; __idx__<__max_idx__; __idx__++ ))
        do
            # value
            if [[ -n $__user_value__ ]]; then
                eval ${__user_value_names__[$__idx__]}'="${'$__array__'[$'$__index__']}"' ||:
            fi

            # index
            if [[ -n $__user_index__ ]]; then
                eval ${__user_index_names__[$__idx__]}'=$'$__index__ ||:
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
            if [[ -n $__user_index__ ]]; then
                eval ${__user_index_names__[$__idx__]}'=$__null_index__' ||:
            fi
        done
    else
        # increment for using last-key / array / count only
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
