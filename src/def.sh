#------------------------------------------------------------
# _zetopt::def
#------------------------------------------------------------
# reset(): Reset auto-defined variables to their defaults
# ** Must be executed in the current shell **
# def.) _zetopt::def::reset
# e.g.) _zetopt::def::reset
# STDOUT: NONE
_zetopt::def::reset()
{
    if [[ -z ${_ZETOPT_DEFINED:-} ]]; then
        return 0
    fi

    local lines line id args arg vars var settings dfnum df
    declare -i idx
    args=()
    vars=()
    local IFS=$'\n'
    lines=($_ZETOPT_DEFINED)
    IFS=$_IFS_DEFAULT

    for line in "${lines[@]}"
    do
        if [[ $line =~ ^([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*)$ ]]; then
            id=${BASH_REMATCH[$ZETOPT_DEFID_ID]}
            args=(${BASH_REMATCH[$ZETOPT_DEFID_ARG]})
            vars=(${BASH_REMATCH[$ZETOPT_DEFID_VARNAME]})
            settings=" ${BASH_REMATCH[$ZETOPT_DEFID_SETTINGS]} "
            for ((idx=0; idx<${#vars[@]}; idx++ ))
            do
                var=${vars[idx]}
                if [[ $idx -eq 0 ]]; then
                    if [[ $settings =~ \ d=([0-9]+)\  ]]; then
                        dfnum=${BASH_REMATCH[1]}
                        df=${_ZETOPT_DEFAULTS[dfnum]}
                        eval $var'=$df'
                    fi
                    continue
                fi

                arg=${args[idx-1]}
                [[ $arg =~ \=([1-9][0-9]*) ]] \
                    && dfnum=${BASH_REMATCH[1]} \
                    || dfnum=0
                
                df=${_ZETOPT_DEFAULTS[dfnum]}
                [[ $arg =~ [.]{3,3} ]] \
                    && eval $var'=("$df")' \
                    || eval $var'=$df'
            done
        fi
    done
}

# define(): Define options.
# ** Must be executed in the current shell **
# def.) _zetopt::def::define {DEFINITION-STRING}
# e.g.) _zetopt::def::define "ver:v:version"
# STDOUT: NONE
_zetopt::def::define()
{
    if $ZETOPT_CFG_AUTOVAR; then
        if [[ -z $ZETOPT_CFG_AUTOVAR_PREFIX || ! $ZETOPT_CFG_AUTOVAR_PREFIX =~ ^$_REG_VARNAME$ || $ZETOPT_CFG_AUTOVAR_PREFIX == _ ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Invalid Variable Name Prefix:" "ZETOPT_CFG_AUTOVAR_PREFIX=$ZETOPT_CFG_AUTOVAR_PREFIX"
            return 1
        fi
    fi

    if [[ -z ${_ZETOPT_DEFINED:-} ]]; then
        _ZETOPT_DEFINED="/:c:::%.0~0...=0:::0 0$_LF"
        _ZETOPT_OPTHELPS=("")
        _ZETOPT_DEFAULTS=("$ZETOPT_CFG_ARG_DEFAULT" "$ZETOPT_CFG_FLAG_DEFAULT" "$ZETOPT_CFG_FLAG_TRUE" "$ZETOPT_CFG_FLAG_FALSE")
    fi

    if [[ -z $@ ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "No Definition Given"
        return 1
    fi

    local IFS=$_IFS_DEFAULT args
    declare -i arglen=$#
    args=("$@")
    declare -i idx=0 maxloop=$arglen
    local namespace= id= short= long= namedef= deftype=o helpdef= global= helpidx=0 helpidx_cmd=0 flags=
    local help_only=false has_param=false
    local settings=

    local arg="${args[$idx]}"
    if [[ $arglen -eq 1 ]]; then
        # param only
        if [[ $arg =~ ^-{0,2}[@%] ]]; then
            namedef=/
            has_param=true
        # help only
        elif [[ $arg =~ ^\# ]]; then
            namedef=/
            helpdef=${arg###}
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
            namedef=/
            IFS=
            helpdef="${args[*]}"
            IFS=$_IFS_DEFAULT
            helpdef=${helpdef###}
            help_only=true
        else
            namedef=$arg
            idx+=1
            arg=${args[$idx]}
            if [[ $arg =~ ^-{0,2}[@%] ]]; then
                has_param=true
            elif [[ $arg =~ ^\# ]]; then
                help_only=true
            fi
        fi
    fi

    # exclusive flag
    local caret="\^"
    if [[ $namedef =~ ^$caret(.*)$ ]]; then
        namedef=${BASH_REMATCH[1]}
        flags+="x"
    fi

    # add an omittable root /
    if [[ ! $namedef =~ ^/ ]]; then
        namedef="/$namedef"
    fi

    # regard as a subcommand
    if [[ ! $namedef =~ : ]]; then
        [[ ! $namedef =~ /$ ]] && namedef="$namedef/" ||:
        deftype=c
    fi

    IFS=:
    \set -- $namedef
    IFS=$_IFS_DEFAULT
    if [[ $# -gt 3 ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "Invalid Definition"
        return 1
    fi

    id=${1-}
    namespace=${id%/*}/
    [[ $id != / ]] && id=${id%/} ||:

    # global flag
    if [[ $id =~ [+]$ ]]; then
        flags+="g"
        id=${id//+/}
    fi

    settings=flags=$flags

    # can not determine whether it is a subcommand or an option
    if [[ $namedef =~ : && $id =~ /$ ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "Invalid Definition"
        return 1
    fi

    if [[ ! $id =~ ^(/|/[a-zA-Z_][a-zA-Z0-9_]*((-[a-zA-Z0-9_]+)*(/[a-zA-Z_][a-zA-Z0-9_]*(-[a-zA-Z0-9_]+)*)*)?)$ ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "Invalid Identifier:" "$id"
        return 1
    fi
    
    # namespace(subcommand) definition
    if [[ $deftype == c ]]; then
        if [[ $flags =~ g ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Command Difinition with Global Option Flag +"
            return 1
        fi

        if [[ $flags =~ x ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Command Difinition with Exclusive Flag ^"
            return 1
        fi

        # command has two help indexes for itself and its argument
        helpidx="0 0"

        if [[ $_ZETOPT_DEFINED =~ (^|.*$_LF)((${id}:c:[^$_LF]+:)([0-9]+)\ ([0-9]+)$_LF)(.*) ]]; then
            local head_lines="${BASH_REMATCH[1]}"
            local tmp_line="${BASH_REMATCH[2]}"
            local tmp_line_nohelp="${BASH_REMATCH[3]}"
            helpidx_cmd="${BASH_REMATCH[4]}"
            local helpidx_cmdarg="${BASH_REMATCH[5]}"
            local tail_lines="${BASH_REMATCH[6]}"

            # remove auto defined namespace
            if [[ $tmp_line == "${id}:c:::%.0~0...=0:::0 0$_LF" ]]; then
                if [[ $has_param == false && $help_only == false ]]; then
                    return 0
                fi
                _ZETOPT_DEFINED="$head_lines$tail_lines"
            
            elif [[ $has_param == true && $tmp_line =~ [@%] ]] || [[ $help_only == true && $tmp_line =~ :[1-9][0-9]*\ [0-9]+$_LF$ ]]; then
                _ZETOPT_DEF_ERROR=true
                _zetopt::msg::script_error "Already Defined:" "$id"
                return 1

            # help only definition: rewrite help reference number part of existing definition
            elif [[ $help_only == true && $tmp_line =~ :0\ ([0-9]+)$_LF$ ]]; then
                _ZETOPT_OPTHELPS+=("$helpdef")
                helpidx=$((${#_ZETOPT_OPTHELPS[@]} - 1))
                _ZETOPT_DEFINED="$head_lines$tmp_line_nohelp$helpidx $helpidx_cmdarg$_LF$tail_lines"
                return 0

            # remove help only definition and continue parsing
            else
                _ZETOPT_DEFINED="$head_lines$tail_lines"
            fi
        fi
    fi
    
    if [[ $_LF$_ZETOPT_DEFINED =~ $_LF${id}: ]]; then
        _ZETOPT_DEF_ERROR=true
        _zetopt::msg::script_error "Duplicate Identifier:" "$id"
        return 1
    fi

    # options
    if [[ $namedef =~ : ]]; then
        shift
        IFS=,
        \set -- $*
        local optname
        while [[ $# -ne 0 ]]
        do
            if [[ -z $1 ]]; then
                shift
                continue
            fi
            optname=$1
            if [[ $optname =~ ^-*(.*) ]]; then
                optname=${BASH_REMATCH[1]}
            fi

            # short option
            if [[ ${#optname} -eq 1 ]]; then
                if [[ -n $short ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "2 Short Options at once:" "$optname"
                    return 1
                fi

                if [[ ! $optname =~ ^[a-zA-Z0-9_]$ ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Invalid Short Option Name:" "$optname"
                    return 1
                fi
                
                # subcommand scope option
                if [[ $_LF$_ZETOPT_DEFINED =~ $_LF${namespace}[a-zA-Z0-9_]*:o:$optname: ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Already Defined:" "-$optname"
                    return 1
                fi
                short=$optname

            # long option
            else
                if [[ -n $long ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "2 Long Options at once:" "$optname"
                    return 1
                fi

                if [[ ! $optname =~ ^[a-zA-Z0-9_]+(-[a-zA-Z0-9_]*)*$ ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Invalid Long Option Name:" "$optname"
                    return 1
                fi

                # subcommand scope option
                if [[ $_LF$_ZETOPT_DEFINED =~ $_LF${namespace}[a-zA-Z0-9_]*:o:[^:]?:$optname: ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Already Defined:" "--$optname"
                    return 1
                fi
                long=$optname
            fi
            shift
        done

        # Not short option nor long option
        if [[ -z $short$long ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Invalid Definition"
            return 1
        fi
    fi
    
    # build base name of variable to store the last value
    local var_name var_name_list=
    local var_base_name=${ZETOPT_CFG_AUTOVAR_PREFIX}${id:1}
    var_base_name=${var_base_name//[\/\-]/_}
    if [[ -z $var_base_name ]]; then
        var_base_name=_
    fi

    # parameters
    local param_def=
    if [[ $has_param == true ]]; then
        local param_optional=false param params default_is_set=false
        declare -i param_idx=0 param_default_idx
        local param_validator_idxs param_validator_separator param_validator= param_validator_name=
        local param_hyphens param_type param_name param_varlen param_varlen_max param_default param_has_default param_names=
        local var_param_name var_param_default
        params=()
        for ((; idx<maxloop; idx++))
        do
            arg=${args[$idx]}
            if [[ ! $arg =~ ^(-{0,2})([@%])($_REG_VARNAME)?(([~]$_REG_VARNAME(,$_REG_VARNAME)*)|([\[]=[~]$_REG_VARNAME(,$_REG_VARNAME)*[\]])|([~]))?([.]{3,3}([1-9][0-9]*)?)?(=.*)?$ ]]; then
                _ZETOPT_DEF_ERROR=true
                _zetopt::msg::script_error "Invalid Parameter Definition:" "$arg"
                return 1
            fi
            
            param_default_idx=0
            param_hyphens=${BASH_REMATCH[1]}
            param_type=${BASH_REMATCH[2]}
            param_name=${BASH_REMATCH[3]}
            param_validator=${BASH_REMATCH[4]}
            param_varlen=${BASH_REMATCH[10]}
            param_varlen_max=${BASH_REMATCH[11]}
            param_default=${BASH_REMATCH[12]}

            if [[ $param_type == @ ]]; then
                if [[ $param_optional == true ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Required Parameter after Optional"
                    return 1
                fi
            else
                param_optional=true
            fi

            if [[ -n $param_varlen && ($((idx + 1)) -ne $maxloop && ${args[$(($idx + 1))]} =~ ^-{0,2}[@%] ) ]]; then
                _ZETOPT_DEF_ERROR=true
                _zetopt::msg::script_error "Variable-length parameter must be the last parameter"
                return 1
            fi

            # check if parameter names are duplicated
            var_param_name=$param_idx
            if [[ -n $param_name ]]; then
                if [[ $param_names =~ \ $param_name\  ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Duplicate Parameter Name:" "$param_name"
                    return 1
                fi
                param_names+=" $param_name "
                var_param_name=$param_name
            fi

            # define choice-validator automatically
            if [[ $param_validator == '~' ]]; then
                local choice_note="Note: If a validator is specified with \"~\" and no name is given like \"~vldt_name\", then comma-separated words after \"=\" are used as choices. However, if there is only one choice, it is treated as an array variable containing the choices. The first choice is used as the default value."
                if [[ -z $param_default ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "No Choice Defined:" "$param\n $choice_note"
                    return 1
                fi

                param_validator="__AUTO_VLDT_${#_ZETOPT_VALIDATOR_DATA[*]}"
                local choice_str=${param_default#*=} choice_help choice_arr
                IFS=,
                choice_arr=($choice_str)
                if [[ ${#choice_arr[*]} -ge 2 ]]; then
                    param_default=${choice_arr[0]} #the first choice is the default value
                    choice_help="#Choose from: [$(IFS=\| && echo "${choice_arr[*]}")]"
                    _zetopt::validator::def -c "$param_validator" "$choice_str" "$choice_help"
                else
                    if [[ ! ${choice_arr[0]} =~ ^$_REG_VARNAME$ || -z $(eval 'echo ${'${choice_arr[0]}'+x}') ]]; then
                        _ZETOPT_DEF_ERROR=true
                        _zetopt::msg::script_error "\"${choice_arr[0]}\" is not an array variable.\n $choice_note"
                        return 1
                    fi
                    eval 'param_default=${'${choice_arr[0]}'[0]}' #the first choice is the default value
                    eval 'choice_help="#Choose from: [$(IFS=\| && echo "${'${choice_arr[0]}'[*]}")]"'
                    _zetopt::validator::def -a "$param_validator" "$choice_str" "$choice_help"
                fi
            fi

            # translate validator name to indexes
            param_validator_idxs=0
            if [[ $param_validator =~ ($_REG_VARNAME(,$_REG_VARNAME)*) ]]; then
                param_validator_separator=
                param_validator_idxs=
                IFS=,
                set -- ${BASH_REMATCH[1]}
                while [[ $# -ne 0 ]]
                do
                    param_validator_name=$1
                    # check the validator exists
                    if [[ ! $_LF${_ZETOPT_VALIDATOR_KEYS-} =~ $_LF$param_validator_name:([0-9]+)$_LF ]]; then
                        # define validator with blank data
                        if ! _zetopt::validator::def "$param_validator_name"; then
                            _ZETOPT_DEF_ERROR=true
                            return 1
                        fi
                        # re-matching to get the reference number of the validator just defined with blank data
                        [[ $_LF${_ZETOPT_VALIDATOR_KEYS-} =~ $_LF$param_validator_name:([0-9]+)$_LF ]]
                    fi
                    param_validator_idxs="$param_validator_idxs$param_validator_separator${BASH_REMATCH[1]}"
                    param_validator_separator=,
                    shift 1
                done
            fi

            # save default value
            var_param_default=$ZETOPT_CFG_ARG_DEFAULT
            if [[ -n $param_default ]]; then
                var_param_default=${param_default#*=}
                _ZETOPT_DEFAULTS+=("$var_param_default")
                param_default_idx=$((${#_ZETOPT_DEFAULTS[@]} - 1))
                default_is_set=true
            elif [[ $default_is_set == true ]]; then
                _ZETOPT_DEF_ERROR=true
                _zetopt::msg::script_error "Non-default Argument Following Default Argument:" "$param_name"
                return 1
            fi
            params+=("$param_hyphens$param_type$param_name.$param_idx~$param_validator_idxs$param_varlen=$param_default_idx")
            param_idx+=1

            # autovar
            if $ZETOPT_CFG_AUTOVAR; then
                # build variable name
                [[ $deftype == c ]] \
                    && var_name=${var_base_name}$([[ $id != / ]] && echo _||:)$var_param_name \
                    || var_name=${var_base_name}_$var_param_name
                var_name=$(_zetopt::def::apply_case_config "$var_name")
                
                # check variable name conflict
                if [[ -n $(eval 'echo ${'$var_name'+x}') ]]; then
                    _ZETOPT_DEF_ERROR=true
                    _zetopt::msg::script_error "Variable name \"$var_name\" is already in use"
                    return 1
                fi
                _ZETOPT_VARIABLE_NAMES+=($var_name)

                # subsititue default value to variable
                [[ -n $param_varlen ]] \
                && eval $var_name'=("$var_param_default")' \
                || eval $var_name'=$var_param_default'
                var_name_list+="$var_name "
            fi

            # no more parameter
            if [[ $((idx + 1)) -ne $maxloop && ! ${args[$(($idx + 1))]} =~ ^-{0,2}[@%] ]]; then
                : $((idx++))
                break
            fi
        done
        IFS=" "
        param_def="${params[*]}"
    fi
    IFS=$_IFS_DEFAULT

    # settings
    local flag_default=$ZETOPT_CFG_FLAG_DEFAULT
    local flag_default_idx=$ZETOPT_IDX_FLAG_DEFAULT
    local flag_true_idx=$ZETOPT_IDX_FLAG_TRUE
    local flag_false_idx=$ZETOPT_IDX_FLAG_FALSE
    for ((; idx<maxloop; idx++))
    do
        arg=${args[$idx]}
        
        # no more settings
        if [[ $arg =~ ^\# ]]; then
            break
        fi

        if [[ ! $arg =~ ^-{0,2}(d|default|t|true|f|false)=(.*)$ ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Invalid Definition"
            return 1
        fi

        _ZETOPT_DEFAULTS+=("${BASH_REMATCH[2]}")
        case ${BASH_REMATCH[1]} in
            d | default)
                flag_default=${BASH_REMATCH[2]}
                flag_default_idx=$((${#_ZETOPT_DEFAULTS[@]} - 1));;
            t | true)
                flag_true_idx=$((${#_ZETOPT_DEFAULTS[@]} - 1));;
            f | false)
                flag_false_idx=$((${#_ZETOPT_DEFAULTS[@]} - 1));;
        esac
    done
    settings+=" d=$flag_default_idx t=$flag_true_idx f=$flag_false_idx"

    # autovar
    if $ZETOPT_CFG_AUTOVAR; then
        var_name=$(_zetopt::def::apply_case_config "$var_base_name")

        # check variable name conflict
        if [[ -n $(eval 'echo ${'$var_name'+x}') ]]; then
            _ZETOPT_DEF_ERROR=true
            _zetopt::msg::script_error "Variable name \"$var_name\" is already in use"
            return 1
        fi
        _ZETOPT_VARIABLE_NAMES+=($var_name)
        eval $var_name'=$flag_default'
        var_name_list=$(echo $var_name $var_name_list) #trim spaces
    fi

    divided_help=false
    for ((; idx<maxloop; idx++))
    do
        arg=${args[$idx]}
        if [[ $divided_help == false && $arg =~ ^\# ]]; then
            divided_help=true
            helpdef=$arg
            helpdef=${helpdef###}
            continue
        fi
        if $divided_help; then
            helpdef+=$arg
            continue
        fi
    done

    if [[ -n "$helpdef" ]]; then
        _ZETOPT_OPTHELPS+=("$helpdef")
        helpidx=$((${#_ZETOPT_OPTHELPS[@]} - 1))
        if [[ $deftype == c ]]; then
            [[ $has_param == true ]] \
            && helpidx="$helpidx_cmd $helpidx" \
            || helpidx+=" 0"
        fi
    fi

    # store definition data as a string line
    _ZETOPT_DEFINED+="$id:$deftype:$short:$long:$param_def:$var_name_list:$settings:$helpidx$_LF"

    # defines parent subcommands automatically
    IFS=" "
    local ns= curr_ns=
    for ns in ${namespace//\// }
    do
        curr_ns="${curr_ns%*/}/$ns"
        [[ $_LF$_ZETOPT_DEFINED =~ $_LF${curr_ns}:c: ]] && return 0
        _ZETOPT_DEFINED+="${curr_ns}:c:::%.0~0...=0:::0 0$_LF"
    done
}

# Change the case of variable name accroding to ZETOPT_CFG_AUTOVAR_CASE
# def.) _zetopt::def::apply_case_config {AUTOVAR_NAME}
# e.g.) _zetopt::def::apply_case_config zv_foo
# STDOUT: string of case changed variable name
_zetopt::def::apply_case_config()
{
    local name=${1-}
    case $ZETOPT_CFG_AUTOVAR_CASE in
        none) :;;
        lower) [[ $name =~ [A-Z] ]] && name=$(_zetopt::utils::lowercase "$name") ||:;;
        upper) [[ $name =~ [a-z] ]] && name=$(_zetopt::utils::uppercase "$name") ||:;;
    esac
    echo "$name"
}

# prepare_parse(): Is definition data ready for parse?
# def.) _zetopt::def::prepare_parse
# e.g.) _zetopt::def::prepare_parse
# STDOUT: NONE
_zetopt::def::prepare_parse()
{
    _zetopt::validator::is_ready || return 1

    if [[ $_ZETOPT_DEF_ERROR == true ]]; then
        _zetopt::msg::script_error "Invalid Definition Data:" "Fix definition error before parse"
        return 1
    fi
    
    if [[ -z ${_ZETOPT_DEFINED:-} ]]; then
        _ZETOPT_DEFINED="/:c:::%.0~0...=0:::0 0$_LF"
    fi
    return 0
}

# defined(): Print the defined data. Print all if ID not given.
# def.) _zetopt::def::defined [ID]
# e.g.) _zetopt::def::defined /foo
# STDOUT: strings separated with $'\n'
_zetopt::def::defined()
{
    if [[ -z ${_ZETOPT_DEFINED-} ]]; then
        _ZETOPT_DEFINED="/:c:::%.0~0...=0::0 0$_LF"
    fi
    if [[ -z ${1-} ]]; then
        printf -- "%s" "$_ZETOPT_DEFINED"
        return 0
    fi
    _zetopt::def::field "$1" $ZETOPT_DEFID_ALL
}

# field(): Search and print the definition.
# def.) _zetopt::def::field {ID} [FIELD-DEF-NUMBER-TO-PRINT]
# e.g.) _zetopt::def::field /foo $ZETOPT_DEFID_ARG
# STDOUT: string
_zetopt::def::field()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1" && [[ ! $id =~ ^/ ]] && id="/$id"
    if [[ ! $_LF$_ZETOPT_DEFINED$_LF =~ .*$_LF(($id):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*))$_LF.* ]]; then
        return 1
    fi
    local field="${2:-$ZETOPT_DEFID_ALL}"
    case "$field" in
        $ZETOPT_DEFID_ALL)      printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_ALL))]}";;
        $ZETOPT_DEFID_ID)       printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_ID))]}";;
        $ZETOPT_DEFID_TYPE)     printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_TYPE))]}";;
        $ZETOPT_DEFID_SHORT)    printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_SHORT))]}";;
        $ZETOPT_DEFID_LONG)     printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_LONG))]}";;
        $ZETOPT_DEFID_ARG)      printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_ARG))]}";;
        $ZETOPT_DEFID_VARNAME)  printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_VARNAME))]}";;
        $ZETOPT_DEFID_SETTINGS)    printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_SETTINGS))]}";;
        $ZETOPT_DEFID_HELP)     printf -- "%s\n" "${BASH_REMATCH[$((1 + $ZETOPT_DEFID_HELP))]}";;
        *) return 1;;
    esac
}

# exists(): Check if the ID exists
# def.) _zetopt::def::exists {ID}
# e.g.) _zetopt::def::exists /foo
# STDOUT: NONE
_zetopt::def::exists()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local id="$1"
    [[ ! $id =~ ^/ ]] && id=/$id ||:
    [[ $_LF$_ZETOPT_DEFINED =~ $_LF${id}: ]]
}

# has_subcmd(): Check if the current namespace has subcommands
# def.) _zetopt::def::has_subcmd {NAMESPACE}
# e.g.) _zetopt::def::has_subcmd /sub
# STDOUT: NONE
_zetopt::def::has_subcmd()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1"
    [[ ! $ns =~ ^/ ]] && ns=/$ns ||:
    [[ ! $ns =~ /$ ]] && ns=$ns/ ||:
    [[ $_LF$_ZETOPT_DEFINED =~ $_LF${ns}[a-zA-Z0-9_-]+:c: ]]
}

# has_options(): Check if the current namespace has options
# def.) _zetopt::def::has_options {NAMESPACE}
# e.g.) _zetopt::def::has_options /sub
# STDOUT: NONE
_zetopt::def::has_options()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1"
    [[ ! $ns =~ ^/ ]] && ns=/$ns ||:
    [[ ! $ns =~ /$ ]] && ns=$ns/ ||:
    [[ $_LF$_ZETOPT_DEFINED =~ $_LF${ns}[a-zA-Z0-9_]+:o: ]]
}

# has_arguments(): Check if the current namespace has arguments
# def.) _zetopt::def::has_arguments {NAMESPACE}
# e.g.) _zetopt::def::has_arguments /sub
# STDOUT: NONE
_zetopt::def::has_arguments()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1"
    [[ ! $ns =~ ^/ ]] && ns=/$ns ||:
    [[ $ns != / ]] && ns=${ns%/} ||:
    [[ $_LF$_ZETOPT_DEFINED =~ $_LF${ns}:c:::-?[@%] ]]
}

# options(): Print option definition
# def.) _zetopt::def::options {NS}
# e.g.) _zetopt::def::options /foo/bar
# STDOUT: option definition
_zetopt::def::options()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1"
    [[ ! $ns =~ ^/ ]] && ns=/$ns ||:
    [[ ! $ns =~ /$ ]] && ns=$ns/ ||:
    local lines=$_ZETOPT_DEFINED
    while :
    do
        if [[ $_LF$lines =~ $_LF(${ns}[a-zA-Z0-9_]+:o:[^$_LF]+$_LF)(.*) ]]; then
            printf -- "%s" "${BASH_REMATCH[1]}"
            lines=${BASH_REMATCH[2]}
        else
            break
        fi
    done
}

# is_cmd(): Check if ID is command
# def.) _zetopt::def::is_cmd {ID}
# e.g.) _zetopt::def::is_cmd /sub
# STDOUT: NONE
_zetopt::def::is_cmd()
{
    if [[ -z ${1-} ]]; then
        return 1
    fi
    local ns="$1"
    [[ ! $ns =~ ^/ ]] && ns=/$ns ||:
    [[ $ns != / ]] && ns=${ns%/} ||:
    [[ $_LF$_ZETOPT_DEFINED =~ $_LF${ns}:c: ]]
}

# namespaces(): Print namespace definition
# def.) _zetopt::def::namespaces
# e.g.) _zetopt::def::namespaces
# STDOUT: namespace definition
_zetopt::def::namespaces()
{
    local lines="$_ZETOPT_DEFINED"
    while :
    do
        if [[ $_LF$lines =~ $_LF([^:]+):c:[^$_LF]+$_LF(.*) ]]; then
            printf -- "%s\n" "${BASH_REMATCH[1]}"
            lines=${BASH_REMATCH[2]}
        else
            break
        fi
    done
}

# opt2id(): Print the identifier by searching with a namespace and a option name.
# If not found in the current namespace, search a global option in parent namespaces.
# def.) _zetopt::def::opt2id {NAMESPACE} {OPTION-NAME} {IS_SHORT}
# e.g.) _zetopt::def::opt2id /remote/add version
# STDOUT: an identifier
# RETURN: 0:No Error, 1:Not Found, 2:Ambiguous Name
_zetopt::def::opt2id()
{
    local ns="${1-}" opt="${2-}" is_short=${3-}
    if [[ -z $ns || -z $opt || -z $is_short ]]; then
        return 1
    fi

    [[ $ns != / && ! $ns =~ /$ ]] && ns=$ns/ ||:

    local regex= flags='[^:]*' tmpid=
    while :
    do
        # short
        if [[ $is_short == true ]]; then
            if [[ $_LF$_ZETOPT_DEFINED =~ $_LF(${ns}[a-zA-Z0-9_]+):o:$opt:[^:]*:[^:]*:[^:]*:${flags}: ]]; then
                printf -- "%s" "${BASH_REMATCH[1]}"
                return 0
            fi
        
        # long
        else
            if [[ $ZETOPT_CFG_ABBREVIATED_LONG == true ]]; then
                if [[ $_LF$_ZETOPT_DEFINED =~ $_LF(${ns}[a-zA-Z0-9_]+):o:[^:]?:${opt}[^:]*:[^:]*:[^:]*:${flags}:[^$_LF]+$_LF(.*) ]]; then
                    tmpid=${BASH_REMATCH[1]}

                    # reject ambiguous name
                    if [[ $_LF${BASH_REMATCH[2]} =~ $_LF(${ns}[a-zA-Z0-9_]+):o:[^:]?:${opt}[^:]*:[^:]*:[^:]*:${flags}: ]]; then
                        return 2
                    fi
                    printf -- "%s" "$tmpid"
                    return 0
                fi
            else
                if [[ $_LF$_ZETOPT_DEFINED =~ $_LF(${ns}[a-zA-Z0-9_]+):o:[^:]?:${opt}:[^:]*:[^:]*:${flags}: ]]; then
                    printf -- "%s" "${BASH_REMATCH[1]}"
                    return 0
                fi
            fi
        fi

        if [[ $ns == / ]]; then
            return 1
        fi
        ns=${ns%/*}  # remove the last /
        ns=${ns%/*}/ # parent ns
        flags="[^g:]*g[^g:]*"
    done
    return 1
}

# paramidx(): Print the index of the specified parameter name
# def.) _zetopt::def::paramidx {ID} {PARAM-NAME}
# e.g.) _zetopt::def::paramidx /foo name
# STDOUT: an integer
_zetopt::def::paramidx()
{
    if [[ $# -lt 2 ]]; then
        return 1
    fi
    if [[ ! $2 =~ ^$_REG_VARNAME$ ]]; then
        return 1
    fi
    local id="$1"
    [[ ! $id =~ ^/ ]] && id="/$id" ||:
    local def_str="$(_zetopt::def::field "$id" $ZETOPT_DEFID_ARG)"
    if [[ $def_str =~ [@%]${2}[.]([0-9]+) ]]; then
        printf -- "%s" ${BASH_REMATCH[1]}
        return 0
    fi
    return 1
}

# keyparams2idx(): translate parameter names to index numbers
# def.) _zetopt::def::keyparams2idx {ID} {KEYS}
# e.g.) _zetopt::def::keyparams2idx /foo FOO,BAR $,BAZ
# STDOUT: string of translated keys
_zetopt::def::keyparams2idx()
{
    if [[ ! $# -eq 2 ]]; then
        return 1
    fi
    local id="$1"
    [[ ! $id =~ ^/ ]] && id="/$id" ||:
    local key="$2" head tail name
    local def_args="$(_zetopt::def::field "$id" $ZETOPT_DEFID_ARG)"
    if [[ $def_args =~ [@%] ]]; then
        while true
        do
            if [[ $key =~ ^([0-9\^\$@,\ \-:]*)($_REG_VARNAME)(.*)$ ]]; then
                head=${BASH_REMATCH[1]}
                name=${BASH_REMATCH[2]}
                tail=${BASH_REMATCH[3]}
                if [[ ! $def_args =~ [@%]${name}[.]([0-9]+) ]]; then
                    _zetopt::msg::script_error "Parameter Name Not Found:" "$name"
                    return 1
                fi
                key=$head${BASH_REMATCH[1]}$tail
            else
                break
            fi
        done
    fi
    printf -- "%s" "$key"
}

# paramlen(): Print the length of parameters
# def.) _zetopt::def::paramlen {ID} [all | required | @ | optional | % | max]
# e.g.) _zetopt::def::paramlen /foo required
# STDOUT: an integer
_zetopt::def::paramlen()
{
    local id="$1"
    [[ ! $id =~ ^/ ]] && id="/$id" ||:
    if ! _zetopt::def::exists "$id"; then
        echo 0; return 1
    fi
    local def="$(_zetopt::def::field "$id" $ZETOPT_DEFID_ARG)"
    if [[ ! $def =~ [@%] ]]; then
        echo 0; return 0
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
            [[ $def =~ ([.]{3,3}([1-9][0-9]*)?)?=[0-9]+$ ]] ||:
            if [[ -n ${BASH_REMATCH[1]} ]]; then
                [[ -n ${BASH_REMATCH[2]} ]] \
                && out=$reqcnt+$optcnt+${BASH_REMATCH[2]}-1 \
                || out=$((1<<31)) #2147483648
            else
                out=$reqcnt+$optcnt
            fi
            ;;
        "" | all) out=$reqcnt+$optcnt;;
        *)        out=$reqcnt+$optcnt;;
    esac
    echo $out
}

# default(): Print default values
# def.) _zetopt::def::default {ID}
# e.g.) _zetopt::def::default /foo
# STDOUT: default ref numbers separated with space
_zetopt::def::default()
{
    if [[ -z ${_ZETOPT_DEFINED:-} || -z ${1-} ]]; then
        _zetopt::msg::script_error "Syntax Error"
        return 1
    fi

    local id="$1"
    [[ ! $id =~ ^/ ]] && id="/$id" ||:
    if ! _zetopt::def::exists "$id"; then
        _zetopt::msg::script_error "No Such Indentifier:" "${1-}"
        return 1
    fi
    shift

    local IFS=' ' params output_list
    output_list=()
    local def_args="$(_zetopt::def::field "$id" $ZETOPT_DEFID_ARG)"
    params=($def_args)
    if [[ ${#params[@]} -eq 0 ]]; then
        printf -- "%s\n" 0
        return 0
    elif [[ ! $def_args =~ [%@] ]]; then
        printf -- "%s\n" "${params[0]#d=}"
        return 0
    fi
    local defaults_idx_string="$(printf -- " %s " "${params[@]#*=}")"
    echo $defaults_idx_string
}
