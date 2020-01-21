#------------------------------------------------------------
# _zetopt::data
#------------------------------------------------------------
# Initialize variables concerned with the parsed data. 
# ** Must be executed in the current shell **
# def.) _zetopt::data::init
# STDOUT: NONE
_zetopt::data::init()
{
    _ZETOPT_PARSED=
    local IFS=$LF line=
    for line in ${_ZETOPT_DEFINED//+/} # remove global signs
    do
        IFS=:
        set -- $line
        _ZETOPT_PARSED+="$1::::0$LF"
    done
    _ZETOPT_OPTVALS=()
    ZETOPT_ARGS=()
}

# Print the parsed data. Print all if ID not given
# def.) _zetopt::data::parsed [ID]
# STDOUT: strings separated with $'\n'
_zetopt::data::parsed()
{
    if [[ -z ${1-} ]]; then
        \echo "${_ZETOPT_PARSED-}"
        return 0
    fi
    _zetopt::data::field "$1" $ZETOPT_FIELD_DATA_ALL
}

# Search and print the parsed data
# def.) _zetopt::data::field {ID} [FILED-DATA-NUMBER]
# e.g.) _zetopt::data::field /foo $ZETOPT_FIELD_DATA_ARG
# STDOUT: string
_zetopt::data::field()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if [[ ! $LF${_ZETOPT_PARSED-}$LF =~ .*$LF(($id):([^:]*):([^:]*):([^:]*):([^:]*))$LF.* ]]; then
        return 1
    fi
    local field="${2:-$ZETOPT_FIELD_DATA_ALL}"
    case "$field" in
        $ZETOPT_FIELD_DATA_ALL)    \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_ALL))]}";;
        $ZETOPT_FIELD_DATA_ID)     \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_ID))]}";;
        $ZETOPT_FIELD_DATA_ARG)    \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_ARG))]}";;
        $ZETOPT_FIELD_DATA_TYPE)   \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_TYPE))]}";;
        $ZETOPT_FIELD_DATA_STATUS) \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_STATUS))]}";;
        $ZETOPT_FIELD_DATA_COUNT)  \printf -- "%s" "${BASH_REMATCH[$((1 + $INIT_IDX + $ZETOPT_FIELD_DATA_COUNT))]}";;
        *) return 1;;
    esac
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
    [[ $LF${_ZETOPT_PARSED-} =~ $LF$id: && ! $LF${_ZETOPT_PARSED-} =~ $LF$id:[^:]*:[^:]*:[^:]*:0 ]]
}

# Check if the option is set and its status is OK
# def.) _zetopt::data::isvalid {ID} [ONE-DIMENSIONAL-KEYS]
# e.g.) _zetopt::data::isvalid /foo @
# STDOUT: NONE
_zetopt::data::isvalid()
{
    if [[ -z ${_ZETOPT_PARSED:-} || $# -eq 0 || -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if ! _zetopt::def::exists "$id"; then
        return 1
    fi
    if [[ $LF$_ZETOPT_PARSED =~ $LF$id:[^:]*:[^:]*:[^:]*:0 ]]; then
        return 1
    fi

    shift
    local stat="$(_zetopt::data::status "$id" "${@-}")"
    if [[ -z $stat ]]; then
        return 1
    fi
    # 0 $ZETOPT_STATUS_NORMAL, 1 $ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS, 2 $ZETOPT_STATUS_MISSING_OPTIONAL_ARGS
    [[ ! $stat =~ [^012\ ] ]]
}

# Print option arguments/status index list
# def.) _zetopt::data::validx {ID} {[$ZETOPT_FILED_DATA_ARGS|$ZETOPT_FILED_DATA_STATUS|$ZETOPT_FIELD_DATA_TYPE]} [TWO-DIMENSIONAL-KEYS]
# e.g.) _zetopt::data::validx /foo $ZETOPT_FILED_DATA_ARGS 0 @ 0:1 0:@ 1:@ name 0:1,-1 @:foo,baz 
# STDOUT: integers separated with spaces
_zetopt::data::validx()
{
    if [[ -z ${_ZETOPT_PARSED:-} || $# -lt 2 || -z ${1-} ]]; then
        return 1
    fi
    case $2 in
        $ZETOPT_FIELD_DATA_ARG | $ZETOPT_FIELD_DATA_TYPE | $ZETOPT_FIELD_DATA_STATUS) :;;
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
        if [[ $field -eq $ZETOPT_FIELD_DATA_ARG ]]; then
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
    if [[ $LF$_ZETOPT_PARSED =~ $LF$id: && $LF$_ZETOPT_PARSED =~ $LF$id::[^:]*:[^:]*:[^:]* ]]; then
        return 1
    fi
    local len=$(_zetopt::data::arglength "$@")
    if [[ -z $len ]]; then
        return 1
    fi
    [[ $len -ne 0 ]]
}

# Print option arguments index list to refer $_ZETOPT_OPTVALS
# def.) _zetopt::data::argidx {ID} [TWO-DIMENSIONAL-KEYS]
# e.g.) _zetopt::data::argidx /foo $ZETOPT_FILED_ARGS 0 @ 0:1 0:@ 1:@ name 0:1,-1 @:foo,baz
# STDOUT: integers separated with spaces
_zetopt::data::argidx()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    shift
    
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
                shift;
                if [[ $# -eq 0 ]]; then
                    _zetopt::msg::debug "Missing Required Argument:" "-a, --array <ARRAY_NAME>"
                    return 1
                fi
                __arrname=$1
                shift
                ;;
            --) shift; __args+=("$@"); break;;
            *)  __args+=("$1"); shift;;
        esac
    done

    if [[ $__array_mode == true ]]; then
        # check the user defined array name before eval to avoid overwriting local variables
        if [[ ! $__arrname =~ ^[a-zA-Z_]([0-9a-zA-Z_]+)*$ ]] || [[ $__arrname =~ ((^_$)|(^__[0-9a-zA-Z][0-9a-zA-Z_]*$)|(^IFS$)) ]]; then
            _zetopt::msg::debug "Invalid Array Name:" "$__arrname"
            return 1
        fi
        \eval "$__arrname=()"
    fi

    local IFS=' '
    if [[ -z ${__args[$((0 + $INIT_IDX))]-} ]]; then
        return 1
    fi
    local __id="${__args[$((0 + $INIT_IDX))]}" && [[ ! $__id =~ ^/ ]] && __id="/$__id"
    __args=(${__args[@]:1})
    
    local __list_str="$(_zetopt::data::validx "$__id" $ZETOPT_FIELD_DATA_ARG "${__args[@]-@}")"
    if [[ -z "$__list_str" ]]; then
        return 1
    fi
    
    # for subcommands
    __args=()
    if [[ $__id =~ ^/(.*/)?$ ]]; then
        __args=("${ZETOPT_ARGS[@]}")

    # for options
    else
        __args=("${_ZETOPT_OPTVALS[@]}")
    fi

    declare -i __idx= __i=$INIT_IDX
    local __ifs=${ZETOPT_CFG_VALUE_IFS-$' '}
    \set -- $__list_str
    local __max=$(($# + INIT_IDX - 1))
    for __idx in "$@"
    do
        if [[ $__array_mode == true ]]; then
            \eval $__arrname'[$__i]=${__args[$__idx]}'
        else
            if [[ $__i -eq $__max ]]; then
                __ifs=
            fi
            \printf -- "%s$__ifs" "${__args[$__idx]}"
        fi
        __i+=1
    done
}

# Print the actual length of arguments of the option/subcommand
# def.) _zetopt::data::arglength {ID} [ONE-DIMENSIONAL-KEYS]
# e.g.) _zetopt::data::arglength /foo 1
# STDOUT: an integer
_zetopt::data::arglength()
{
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if ! _zetopt::def::exists "$id"; then
        return 1
    fi
    shift

    local idxarr
    idxarr=()
    if [[ $# -eq 0 || -z ${@-} ]]; then
        idxarr=($:@)
    else
        local idx=
        for idx in "$@"
        do 
            if [[ $idx =~ [^@$\^,0-9-] ]]; then
                _zetopt::msg::debug "Bad Key:" "$idx"
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
    if ! _zetopt::def::exists "$id"; then
        return 1
    fi
    shift

    local idxarr
    idxarr=()
    if [[ $# -eq 0 || -z ${@-} ]]; then
        idxarr=($)
    else
        local idx=
        for idx in "$@"
        do
            if [[ $idx =~ [^@$\^,0-9-] ]]; then
                _zetopt::msg::debug "Bad Key:" "$idx"
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
    if ! _zetopt::def::exists "$id"; then
        return 1
    fi
    shift

    local idxarr
    idxarr=()
    if [[ $# -eq 0 || -z ${@-} ]]; then
        idxarr=($)
    else
        local idx=
        for idx in "$@"
        do 
            if [[ $idx =~ [^@$\^,0-9-] ]]; then
                _zetopt::msg::debug "Bad Key:" "$idx"
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
    _zetopt::data::field "${1-}" $ZETOPT_FIELD_DATA_COUNT || echo 0
}

# Print the list of IDs set
# def.) _zetopt::data::setids
# e.g.) _zetopt::data::setids
# STDOUT: string separated with \n
_zetopt::data::setids()
{
    <<< "$_ZETOPT_PARSED" \grep -E ':[1-9][0-9]*$' | \sed -e 's/:.*//'
}
