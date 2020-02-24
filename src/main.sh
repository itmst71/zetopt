#------------------------------------------------------------
# Main
#------------------------------------------------------------
# zetopt(): Interface for shell script programmer
# def.) zetopt {SUB-COMMAND} [ARGS]
# e.g.) zetopt def ver:v,version
# STDOUT: depending on each sub-commands
zetopt()
{
    declare -r _PATH=$PATH
    declare -r _LC_ALL="${LC_ALL-}" _LANG="${LANG-}"
    local PATH="/usr/bin:/bin"
    local LC_ALL=C LANG=C
    local IFS=$' \t\n'
    declare -r LF=$'\n'
    declare -r INIT_IDX=$ZETOPT_ARRAY_INITIAL_IDX
    declare -r REG_VNAME='[a-zA-Z_][a-zA-Z0-9_]*'

    # setup for zsh
    if [[ -n ${ZSH_VERSION-} ]]; then
        \setopt localoptions SH_WORD_SPLIT
        \setopt localoptions BSD_ECHO
        \setopt localoptions NO_NOMATCH
        \setopt localoptions NO_GLOB_SUBST
        \setopt localoptions NO_EXTENDED_GLOB
        \setopt localoptions BASH_REMATCH
    fi

    # save whether the stdin/out/err of the main function is TTY or not.
    [[ -t 0 ]] \
    && declare -r TTY_STDIN=0 \
    || declare -r TTY_STDIN=1

    [[ -t 1 ]] \
    && declare -r TTY_STDOUT=0 \
    || declare -r TTY_STDOUT=1

    [[ -t 2 ]] \
    && declare -r TTY_STDERR=0 \
    || declare -r TTY_STDERR=1

    declare -r FD_STDOUT=1
    declare -r FD_STDERR=2

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
            \echo $ZETOPT_APPNAME $ZETOPT_VERSION;;
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
        def-validator | define-validator)
            _zetopt::validator::def "$@";;
        paramidx | pidx)
            _zetopt::def::paramidx "$@";;
        paramlen | plen)
            _zetopt::def::paramlen "$@";;
        default)
            _zetopt::def::default "$@";;
        defined)
            _zetopt::def::defined "$@";;

        # parser
        parse)
            _zetopt::parser::parse "$@";;

        # data
        isset)
            _zetopt::data::isset "$@";;
        setids)
            _zetopt::data::setids;;
        argv | value | val)
            _zetopt::data::print $ZETOPT_DATAID_ARGV "$@";;
        argc | length | len)
            _zetopt::data::print $ZETOPT_DATAID_ARGC "$@";;
        type)
            _zetopt::data::print $ZETOPT_DATAID_TYPE "$@";;
        pseudo)
            _zetopt::data::print $ZETOPT_DATAID_PSEUDO "$@";;
        status)
            _zetopt::data::print $ZETOPT_DATAID_STATUS "$@";;
        count)
            _zetopt::data::print $ZETOPT_DATAID_COUNT "$@";;
        hasarg | hasval)
            _zetopt::data::hasarg "$@";;
        isvalid | isok)
            _zetopt::data::isvalid "$@";;
        parsed)
            _zetopt::data::parsed "$@";;
        iterate)
            _zetopt::data::iterate "$@";;

        # help
        def-help | define-help)
            _zetopt::help::define "$@";;
        show-help)
            _zetopt::help::show "$@";;

        *)
            _zetopt::msg::script_error "Undefined Sub-Command:" "$subcmd"
            return 1;;
    esac
}

