#------------------------------------------------------------
# _zetopt::parser
#------------------------------------------------------------

# init(): Initialize variables concerned with the parser. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::init
# e.g.) _zetopt::parser::init
# STDOUT: NONE
_zetopt::parser::init()
{
    ZETOPT_OPTERR_INVALID=()
    ZETOPT_OPTERR_MISSING_REQUIRED=()
    ZETOPT_OPTERR_UNDEFINED=()
    ZETOPT_OPTERR_MISSING_OPTIONAL=()
    ZETOPT_PARSE_ERRORS=$ZETOPT_STATUS_NORMAL
    ZETOPT_LAST_COMMAND=/
    ZETOPT_EXCLUSIVE_OPTION_ID=
}

# parse(): Parse arguments. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::parse {ARGUMENTS}
# e.g.) _zetopt::parser::parse "$@"
# STDOUT: NONE
_zetopt::parser::parse()
{
    if $ZETOPT_CFG_AUTOVAR; then
        if [[ -z $ZETOPT_CFG_AUTOVAR_PREFIX || ! $ZETOPT_CFG_AUTOVAR_PREFIX =~ ^$REG_VNAME$ || $ZETOPT_CFG_AUTOVAR_PREFIX == _ ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Invalid Variable Prefix:" "ZETOPT_CFG_AUTOVAR_PREFIX=$ZETOPT_CFG_AUTOVAR_PREFIX"
            return 1
        fi
    fi

    if [[ $_ZETOPT_DEF_ERROR == true ]]; then
        _zetopt::msg::script_error "Invalid Definition Data:" "Fix definition error before parse"
        return 1
    fi

    if [[ -z ${_ZETOPT_DEFINED:-} ]]; then
        _ZETOPT_DEFINED="/:c:::%.0~0...=0:::0 0$LF"
    fi
    _zetopt::parser::init
    _zetopt::data::init
    
    local optname= optnames_len= optarg= idx= opt_prefix= pseudoname=
    local additional_args_count=0 consumed_args_count= args
    local namespace=/ ns=/ check_subcmd=true error_subcmd_name=
    
    # internal global variables
    declare -i _CONSUMED_ARGS_COUNT=0

    args=()
    while [[ $# -ne 0 ]]
    do
        _CONSUMED_ARGS_COUNT=0
        
        # Double Hyphen Only
        if [[ $1 == -- ]]; then
            if [[ $ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN != true ]]; then
                shift
                _ZETOPT_TEMP_ARGV+=("$@")
                break
            else
                _ZETOPT_TEMP_ARGV+=("$1")
                shift
            fi
            check_subcmd=false

        # Single Prefix Only
        elif [[ $1 =~ ^[-+]$ ]]; then
            _ZETOPT_TEMP_ARGV+=("$1")
            shift
            check_subcmd=false

        # Blank String
        elif [[ $1 == "" ]]; then
            if [[ $ZETOPT_CFG_IGNORE_BLANK_STRING == true ]]; then
                shift
                continue
            fi
            _ZETOPT_TEMP_ARGV+=("$1")
            shift
            check_subcmd=false

        # Long option
        elif [[ $1 =~ ^(--|[+][+])[^+-] || ($ZETOPT_CFG_SINGLE_PREFIX_LONG == true && ($1 =~ ^-[^-]. || $1 =~ ^[+][^+]. )) ]]; then
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
            [[ -n $ZETOPT_EXCLUSIVE_OPTION_ID ]] && return 0 ||:
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
                    if [[ $ZETOPT_CFG_PSEUDO_OPTION == true && ${optnames:$((idx+1)):1} == : ]]; then
                        pseudoname=${optnames:$((idx+2)):$(($optnames_len - $idx - 1))}
                        _zetopt::parser::setopt $namespace $opt_prefix $optname "$pseudoname" "$@" ||:
                        [[ -n $ZETOPT_EXCLUSIVE_OPTION_ID ]] && return 0 ||:
                        break
                    else
                        if [[ $ZETOPT_CFG_CONCATENATED_OPTARG == true ]]; then
                            _zetopt::parser::setopt $namespace $opt_prefix $optname "" "${optnames:$((idx+1)):$(($optnames_len - $idx - 1))}" "$@" ||:
                            [[ -n $ZETOPT_EXCLUSIVE_OPTION_ID ]] && return 0 ||:
                            if [[ $consumed_args_count -ne $_CONSUMED_ARGS_COUNT ]]; then
                                additional_args_count=1
                                break
                            fi
                        else
                            _zetopt::parser::setopt $namespace $opt_prefix $optname "" "$@"||:
                            [[ -n $ZETOPT_EXCLUSIVE_OPTION_ID ]] && return 0 ||:
                        fi
                    fi
                else
                    _zetopt::parser::setopt $namespace $opt_prefix $optname "" "$@" ||:
                    [[ -n $ZETOPT_EXCLUSIVE_OPTION_ID ]] && return 0 ||:
                fi
            done
            check_subcmd=false

        # Positional Arguments or Subcommand
        else
            # Subcommand
            if [[ $check_subcmd == true ]] && _zetopt::def::has_subcmd "$namespace"; then
                ns="${namespace%/}/$1"
                if ! _zetopt::def::exists "$ns"; then
                    check_subcmd=false
                    if [[ $ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR == true ]]; then
                        _ZETOPT_TEMP_ARGV+=("$1")
                        shift
                        continue
                    fi
                    error_subcmd_name="${ns//\// }"
                    _zetopt::msg::user_error Error "Undefined Sub-Command:" "$error_subcmd_name"
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_SUBCMD))
                    break
                fi

                # Change namespace
                namespace=$ns
                ZETOPT_LAST_COMMAND=$namespace

                shift
                continue
            fi

            # Positional Arguments
            _ZETOPT_TEMP_ARGV+=("$1")
            shift
        fi

        # shift
        if [[ $(($_CONSUMED_ARGS_COUNT - $additional_args_count)) -gt 0 ]]; then
            shift $(($_CONSUMED_ARGS_COUNT - $additional_args_count))
        fi
    done

    # update command count
    _zetopt::parser::setcmd $ZETOPT_LAST_COMMAND ||:

    # assign positional args
    _zetopt::parser::assign_args "$namespace" ||:
    
    # show errors
    if [[ $ZETOPT_CFG_ERRMSG_USER_ERROR == true && $ZETOPT_PARSE_ERRORS -ne 0 ]]; then
        IFS=$' \t\n'
        local subcmdstr="$ZETOPT_CALLER_NAME${namespace//\// }" msg=
        subcmdstr=${subcmdstr% }

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
        if [[ $(($ZETOPT_PARSE_ERRORS & $ZETOPT_STATUS_EXTRA_ARGS)) -ne 0 ]]; then
            msg=("\"$subcmdstr\" can take up to $(_zetopt::def::paramlen $namespace max) arguments. But ${#_ZETOPT_TEMP_ARGV[@]} were given.")
            _zetopt::msg::user_error Warning "Too Match Arguments:" "${msg[*]}"
        fi
    fi

    [[ $ZETOPT_PARSE_ERRORS -le $ZETOPT_STATUS_ERROR_THRESHOLD ]]
}

# setcmd(): Increment the set count of a sub-command. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::setcmd {NAMESPACE}
# e.g.) _zetopt::parser::setcmd /sub
# STDOUT: NONE
_zetopt::parser::setcmd()
{
    local id=${1-}
    if [[ ! $LF$_ZETOPT_PARSED =~ (.*$LF)(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))($LF.*) ]]; then
        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_SUBCMD))
        return 1
    fi

    local head_lines="${BASH_REMATCH[$((1 + $INIT_IDX))]:1}"
    local tail_lines="${BASH_REMATCH[$((10 + $INIT_IDX))]}"
    local offset=2

    local IFS=:
    set -- ${BASH_REMATCH[$(($offset + $INIT_IDX + $ZETOPT_DATAID_ALL))]}
    local cnt=$(($7 + 1))
    local pseudoidx=$INIT_IDX
    _ZETOPT_PARSED=$head_lines$1:$2:$3:$ZETOPT_TYPE_CMD:$pseudoidx:$ZETOPT_STATUS_NORMAL:$cnt$tail_lines
}

# setopt(): Set option data. 
# ** Must be executed in the current shell **
# def.) _zetopt::parser::setopt {NAMESPACE} {PREFIX} {OPTNAME} {PSEUDO} [ARGUMENTS]
# e.g.) _zetopt::parser::setopt /sub/cmd - version "$@"
# STDOUT: NONE
_zetopt::parser::setopt()
{
    local namespace="${1-}" opt_prefix="${2-}" opt="${3-}" pseudoname="${4-}" args
    shift 4
    args=("$@")
    local is_short=$( [[ ${#opt_prefix} -eq 1 && $ZETOPT_CFG_SINGLE_PREFIX_LONG != true ]] && echo true || echo false)
    local id="$(_zetopt::def::opt2id "$namespace" "$opt" "$is_short" || echo ERROR:$?)"
    if [[ $id =~ ^ERROR:[0-9]+$ ]]; then
        ZETOPT_OPTERR_UNDEFINED+=("$opt_prefix$opt")
        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_UNDEFINED_OPTION))
        return 1
    fi

    # exclusive option
    if [[ "$(_zetopt::def::field "$id" $ZETOPT_DEFID_FLAGS)" =~ x ]]; then
        local lc=$ZETOPT_LAST_COMMAND
        _zetopt::def::reset
        _zetopt::data::init
        _zetopt::parser::init
        ZETOPT_LAST_COMMAND=$lc
        ZETOPT_EXCLUSIVE_OPTION_ID=$id
    fi

    if [[ ! $LF$_ZETOPT_PARSED =~ (.*$LF)(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))($LF.*) ]]; then
        return 1
    fi
    local head_lines="${BASH_REMATCH[$((1 + $INIT_IDX))]:1}"
    local tail_lines="${BASH_REMATCH[$((10 + $INIT_IDX))]}"
    local IFS=:
    set -- ${BASH_REMATCH[$((2 + $INIT_IDX + $ZETOPT_DATAID_ALL))]}
    local id="$1" refs_str="$2" argcs="$3" types="$4" pseudo_idexs="$5" stat="$6" cnt="$7"
    local curr_stat=$ZETOPT_STATUS_NORMAL

    local ref_arr paramdef_str="$(_zetopt::def::field "$id" $ZETOPT_DEFID_ARG)"
    declare -i optarg_idx=$((${#_ZETOPT_DATA[@]} + $INIT_IDX))
    declare -i arg_cnt=0
    ref_arr=()

    if $ZETOPT_CFG_AUTOVAR; then
        local var_name var_names var_names_str="$(_zetopt::def::field "$id" $ZETOPT_DEFID_VARNAME)"
    fi

    # options requiring NO argument
    if [[ -z $paramdef_str ]]; then
        [[ $opt_prefix =~ ^--?$ ]] \
        && _ZETOPT_DATA+=("$ZETOPT_CFG_FLAGVAL_TRUE") \
        || _ZETOPT_DATA+=("$ZETOPT_CFG_FLAGVAL_FALSE")
        ref_arr=($optarg_idx)

        # autovar
        if $ZETOPT_CFG_AUTOVAR; then
            var_name=$var_names_str
            eval $var_name'=true'
        fi

    # options requiring arguments
    else
        local arg def def_arr varlen_mode=false no_avail_args=false
        IFS=$' '
        def_arr=($paramdef_str)
        declare -i def_len=$((${#def_arr[@]} + INIT_IDX)) def_idx=$INIT_IDX
        declare -i arg_def_max arg_idx=$INIT_IDX arg_max_idx=$((${#args[@]} + $INIT_IDX))

        # autovar
        if $ZETOPT_CFG_AUTOVAR; then
            var_names=($var_names_str)
        fi

        while [[ $def_idx -lt $def_len ]]
        do
            def=${def_arr[$def_idx]}

            # autovar
            if $ZETOPT_CFG_AUTOVAR; then
                var_name=${var_names[$def_idx]}
            fi

            # there are available args
            if [[ $arg_idx -lt $arg_max_idx ]]; then
                arg="${args[$arg_idx]}"
                if [[ $arg == "" && $ZETOPT_CFG_IGNORE_BLANK_STRING == true ]]; then
                    arg_idx+=1
                    continue
                fi

                # check arg format
                if [[ $arg =~ ^[^-+]
                    || $arg =~ ^[-+]$
                    || $arg == ""
                    || ($arg =~ ^-[^-] && $def =~ ^-[^-])
                    || ($arg != "--" && $arg =~ ^- && $def =~ ^--)
                    || ($arg =~ ^[+] && $def =~ ^--? && $ZETOPT_CFG_OPTTYPE_PLUS == true)
                    || ($arg == "--" && $ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN -eq 0)
                ]]; then
                    # validate
                    if ! _zetopt::validator::validate "$def" "$arg"; then
                        ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | ZETOPT_STATUS_VALIDATOR_FAILED))
                        return 1
                    fi

                    if [[ $varlen_mode == false && $def =~ [.]{3,3} ]]; then
                        varlen_mode=true
                        arg_def_max=$(_zetopt::def::paramlen $id max)

                        # autovar
                        if $ZETOPT_CFG_AUTOVAR; then
                            eval $var_name'=()'
                        fi
                    fi

                    _ZETOPT_DATA+=("$arg")

                    # autovar
                    if $ZETOPT_CFG_AUTOVAR; then
                        [[ $varlen_mode == true ]] \
                        && eval $var_name'+=("$arg")' \
                        || eval $var_name'=$arg'
                    fi

                    ref_arr+=($optarg_idx)
                    arg_cnt+=1
                    _CONSUMED_ARGS_COUNT+=1

                    arg_idx+=1
                    optarg_idx+=1

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
                curr_stat=$ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | curr_stat))
                ZETOPT_OPTERR_MISSING_OPTIONAL+=("$opt_prefix$opt")

                while [[ $def_idx -lt $def_len ]]
                do
                    def=${def_arr[$def_idx]}

                    # autovar
                    if $ZETOPT_CFG_AUTOVAR; then
                        var_name=${var_names[$def_idx]}
                    fi

                    # has default value
                    if [[ $def =~ ([.]{3,3}([1-9][0-9]*)?)?=([1-9][0-9]*) ]]; then
                        arg=${_ZETOPT_DATA[${BASH_REMATCH[$((3 + INIT_IDX))]}]}
                        #ref_arr+=(${BASH_REMATCH[$((3 + INIT_IDX))]})
                    else
                        arg=${_ZETOPT_DATA[$INIT_IDX]}
                        #ref_arr+=($INIT_IDX)
                    fi

                    # autovar
                    if $ZETOPT_CFG_AUTOVAR; then
                        eval $var_name'=$arg'
                    fi
                    def_idx+=1
                done
            fi
        fi
    fi

    local type=$ZETOPT_TYPE_CMD
    case $opt_prefix in
        -)  type=$ZETOPT_TYPE_SHORT;;
        --) type=$ZETOPT_TYPE_LONG;;
        +)  type=$ZETOPT_TYPE_PLUS;;
        ++) type=$ZETOPT_TYPE_PLUS;;
    esac

    _ZETOPT_DATA+=("$pseudoname")
    local pseudoidx=$((${#_ZETOPT_DATA[@]} - 1 + $INIT_IDX))

    IFS=$' '
    if [[ $cnt -eq 0 ]]; then
        stat="$curr_stat"
        refs_str="${ref_arr[*]-}"
        argcs="$arg_cnt"
        types="$type"
        pseudo_idexs="$pseudoidx"
    else
        stat="$stat $curr_stat"
        refs_str="$refs_str,${ref_arr[*]-}"
        argcs="$argcs $arg_cnt"
        types="$types $type"
        pseudo_idexs="$pseudo_idexs $pseudoidx"
    fi
    cnt=$(($cnt + 1))

    _ZETOPT_PARSED="$head_lines$id:$refs_str:$argcs:$types:$pseudo_idexs:$stat:$cnt$tail_lines"
    [[ $curr_stat -le $ZETOPT_STATUS_ERROR_THRESHOLD ]]
}


# assign_args(): Assign indices to subcommand parameters. 
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
    local arg def_arr def ref_arr
    local IFS=' '
    def_arr=($(_zetopt::def::field "$id" $ZETOPT_DEFID_ARG))
    ref_arr=()
    declare -i def_len=${#def_arr[@]} arg_len=${#_ZETOPT_TEMP_ARGV[@]} rtn=$ZETOPT_STATUS_NORMAL idx maxloop
    local var_name var_names var_names_str="$(_zetopt::def::field "$id" $ZETOPT_DEFID_VARNAME)"
    if [[ -z $var_names_str ]]; then
        var_names_str=${ZETOPT_CFG_AUTOVAR_PREFIX}${ZETOPT_LAST_COMMAND:1}
        var_names_str=${var_names_str//[\/\-]/_}$INIT_IDX
    fi
    var_names=($var_names_str)

    # enough
    if [[ $arg_len -ge $def_max_len ]]; then
        ref_arr=($(eval "echo {$INIT_IDX..$((def_max_len - 1 + INIT_IDX))}"))
        maxloop=$def_len+$INIT_IDX
        # explicit defined arguments
        for ((idx=INIT_IDX; idx<maxloop; idx++))
        do
            def=${def_arr[idx]}
            arg=${_ZETOPT_TEMP_ARGV[ref_arr[idx]]}
            
            # validate
            if ! _zetopt::validator::validate "$def" "$arg"; then
                rtn=$((rtn | ZETOPT_STATUS_VALIDATOR_FAILED))
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                continue
            fi
            _ZETOPT_DATA+=("$arg")
            ref_arr[$idx]=$((${#_ZETOPT_DATA[@]} - 1 + $INIT_IDX))
            
            # autovar
            if $ZETOPT_CFG_AUTOVAR; then
                var_name=${var_names[idx]}
                if [[ $def =~ [.]{3,3} ]]; then
                    eval $var_name'=("$arg")'
                else
                    eval $var_name'=$arg'
                fi
            fi
        done
        
        # variable length arguments
        for ((; idx<$((def_max_len+INIT_IDX)); idx++))
        do
            arg=${_ZETOPT_TEMP_ARGV[ref_arr[idx]]}
            _ZETOPT_DATA+=("$arg")
            ref_arr[$idx]=$((${#_ZETOPT_DATA[@]} - 1 + $INIT_IDX))

            # autovar
            if $ZETOPT_CFG_AUTOVAR; then
                eval $var_name'+=("$arg")'
            fi
        done

        # too match arguments
        if [[ $arg_len -gt $def_max_len ]]; then
            local start_idx=$((${#_ZETOPT_DATA[@]} - 1 + $INIT_IDX + 1))
            _ZETOPT_DATA+=("${_ZETOPT_TEMP_ARGV[@]:$def_max_len}")
            local end_idx=$((${#_ZETOPT_DATA[@]} - 1 + $INIT_IDX))
            _ZETOPT_EXTRA_ARGV=($(eval 'echo {'$start_idx'..'$end_idx'}'))
            rtn=$((rtn | ZETOPT_STATUS_EXTRA_ARGS))
            ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
        fi

    # not enough
    else
        # has some args
        declare -i ref_idx=$INIT_IDX
        local varlen_mode=false
        if [[ $arg_len -ne 0 ]]; then
            ref_idx=$arg_len-1+$INIT_IDX
            ref_arr=($(eval "echo {$INIT_IDX..$ref_idx}"))
            ref_idx+=1

            maxloop=$arg_len+$INIT_IDX
            local def=
            for ((idx=INIT_IDX; idx<maxloop; idx++))
            do
                # validate
                if [[ $idx -lt $((${#def_arr[@]} + INIT_IDX)) ]]; then
                    def=${def_arr[idx]}

                    # autovar
                    if $ZETOPT_CFG_AUTOVAR; then
                        var_name=${var_names[idx]}
                    fi
                else
                    def=${def_arr[$((${#def_arr[@]} - 1 + $INIT_IDX))]}

                    # autovar
                    if $ZETOPT_CFG_AUTOVAR; then
                        var_name=${var_names[$((${#def_arr[@]} - 1 + $INIT_IDX))]}
                    fi
                fi
                
                arg=${_ZETOPT_TEMP_ARGV[ref_arr[idx]]}
                if ! _zetopt::validator::validate "$def" "$arg"; then
                    rtn=$((rtn | ZETOPT_STATUS_VALIDATOR_FAILED))
                    ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                fi

                _ZETOPT_DATA+=("$arg")
                ref_arr[$idx]=$((${#_ZETOPT_DATA[@]} - 1 + $INIT_IDX))

                if [[ $varlen_mode == false && $def =~ [.]{3,3} ]]; then
                    varlen_mode=true

                    # autovar
                    if $ZETOPT_CFG_AUTOVAR; then
                        eval $var_name'=()'
                    fi
                fi

                # autovar
                if $ZETOPT_CFG_AUTOVAR; then
                    if [[ $def =~ [.]{3,3} ]]; then
                        eval $var_name'+=("$arg")'
                    else
                        eval $var_name'=$arg'
                    fi
                fi
            done
        fi

        maxloop=$def_len+$INIT_IDX
        declare -i default_idx
        for ((; ref_idx<maxloop; ref_idx++))
        do
            # missing required
            if [[ ${def_arr[ref_idx]} =~ @ ]]; then
                rtn=$((rtn | ZETOPT_STATUS_MISSING_REQUIRED_ARGS))
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                break
            fi
            if [[ ! ${def_arr[ref_idx]} =~ \=([1-9][0-9]*)$ ]]; then
                rtn=$((rtn | ZETOPT_STATUS_MISSING_OPTIONAL_ARGS))
                ZETOPT_PARSE_ERRORS=$((ZETOPT_PARSE_ERRORS | rtn))
                break
            fi
            arg=${_ZETOPT_DATA[${BASH_REMATCH[$((1 + INIT_IDX))]}]}
            _ZETOPT_DATA+=("$arg")
            ref_arr+=($((${#_ZETOPT_DATA[@]} - 1 + $INIT_IDX)))
        done
    fi

    # update parsed data
    if [[ ! $LF$_ZETOPT_PARSED =~ (.*$LF)(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))($LF.*) ]]; then
        return 1
    fi
    local head_lines="${BASH_REMATCH[$((1 + INIT_IDX))]:1}"
    local tail_lines="${BASH_REMATCH[$((10 + INIT_IDX))]}"
    local offset=2
    local line="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_DATAID_ALL))]}"
    local id="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_DATAID_ID))]}"
    #local argv="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_DATAID_ARGV))]}"
    #local argc="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_DATAID_ARGC))]}"
    local type="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_DATAID_TYPE))]}"
    local pseudoname="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_DATAID_PSEUDO))]}"
    #local status="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_DATAID_STATUS))]}"
    local count="${BASH_REMATCH[$((offset + INIT_IDX + ZETOPT_DATAID_COUNT))]}"
    IFS=' '
    local refs_str="${ref_arr[*]-}"
    local argcs=${#ref_arr[@]}
    _ZETOPT_PARSED="$head_lines$id:$refs_str:$argcs:$type:$pseudoname:$rtn:$count$tail_lines"
    return $rtn
}
