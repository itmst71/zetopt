#------------------------------------------------------------
# Main
#------------------------------------------------------------
# zetopt(): Interface for shell script programmer
# def.) zetopt {SUB-COMMAND} [ARGS]
# e.g.) zetopt def ver:v,version
# STDOUT: depending on each sub-commands
zetopt()
{
    local _PATH=$PATH
    local PATH="/usr/bin:/bin"
    local _LC_ALL="${LC_ALL-}"
    local LC_ALL=C
    local _LANG="${LANG-}"
    local LANG=C
    local _IFS_DEFAULT=$' \t\n'
    local IFS=$_IFS_DEFAULT
    local _LF=$'\n'
    local _REG_VARNAME='[a-zA-Z_][a-zA-Z0-9_]*'

    # setup for zsh
    if [[ -n ${ZSH_VERSION-} ]]; then
        setopt localoptions SH_WORD_SPLIT
        setopt localoptions BSD_ECHO
        setopt localoptions NO_NOMATCH
        setopt localoptions NO_GLOB_SUBST
        setopt localoptions NO_EXTENDED_GLOB
        setopt localoptions BASH_REMATCH
    fi

    # save whether the stdin/out/err of the main function is TTY or not.
    [[ -t 0 ]] \
    && local _TTY_STDIN=0 \
    || local _TTY_STDIN=1

    [[ -t 1 ]] \
    && local _TTY_STDOUT=0 \
    || local _TTY_STDOUT=1

    [[ -t 2 ]] \
    && local _TTY_STDERR=0 \
    || local _TTY_STDERR=1

    local _FD_STDOUT=1
    local _FD_STDERR=2

    # show help if subcommand not given
    if [[ $# -eq 0 ]]; then
        _zetopt::man::show short
        return 1
    fi

    local subcmd="$1"
    shift

    # sub-commands
    case "$subcmd" in
        # options
        -v | --version)
            echo $ZETOPT_APPNAME $ZETOPT_VERSION;;
        -h | --help)
            _zetopt::man::show;;

        # init
        init)
            _zetopt::init::init;;
        reset)
            _zetopt::init::reset;;

        # def
        define | def)
            _zetopt::def::define "$@";;
        paramidx | pidx)
            _zetopt::def::paramidx "$@";;
        paramlen | plen)
            _zetopt::def::paramlen "$@";;
        defined)
            _zetopt::def::defined "$@";;

        # validator
        validator)
            _zetopt::validator::def "$@";;

        # parser
        parse)
            _zetopt::parser::parse "$@";;

        # data
        isset)
            _zetopt::data::isset "$@";;
        setids)
            _zetopt::data::setids;;
        argv | value | val)
            _zetopt::data::output $ZETOPT_DATAID_ARGV "$@";;
        argc | length | len)
            _zetopt::data::output $ZETOPT_DATAID_ARGC "$@";;
        type)
            _zetopt::data::output $ZETOPT_DATAID_TYPE "$@";;
        pseudo)
            _zetopt::data::output $ZETOPT_DATAID_PSEUDO "$@";;
        status)
            _zetopt::data::output $ZETOPT_DATAID_STATUS "$@";;
        count)
            _zetopt::data::output $ZETOPT_DATAID_COUNT "$@";;
        default)
            _zetopt::data::output $ZETOPT_DATAID_DEFAULT "$@";;
        hasarg | hasval)
            _zetopt::data::hasarg "$@";;
        isvalid | isok)
            _zetopt::data::isvalid "$@";;
        parsed)
            _zetopt::data::parsed "$@";;
        iterate)
            _zetopt::data::iterate "$@";;

        # utils
        utils)
            _zetopt::utils::interface "$@";;
            
        # help
        help)
            case ${1-} in
                def|define)
                    shift
                    _zetopt::help::define "$@";;
                show)
                    shift
                    _zetopt::help::show "$@";;
                *)
                    _zetopt::msg::script_error "Undefined Sub-Command:" "help ${1-}"
                    return 1;;
            esac
            ;;

        *)
            _zetopt::msg::script_error "Undefined Sub-Command:" "$subcmd"
            return 1;;
    esac
}

