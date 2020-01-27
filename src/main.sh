#------------------------------------------------------------
# Main
#------------------------------------------------------------
# zetopt {SUB-COMMAND} [ARGS]
# STDOUT: depending on each sub-commands
zetopt()
{
    declare -r _PATH=$PATH
    declare -r LF=$'\n'
    declare -r INIT_IDX=$ZETOPT_ARRAY_INITIAL_IDX
    local PATH="/usr/bin:/bin"
    local IFS=$' \t\n'
    local _LC_ALL="${LC_ALL-}" _LANG="${LANG-}"
    local LC_ALL=C LANG=C

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

    case "$subcmd" in
        -v | --version)
            \echo $ZETOPT_APPNAME $ZETOPT_VERSION;;
        -h | --help)
            _zetopt::man::show;;
        init)
            _zetopt::init::init;;
        reset)
            _zetopt::parser::init
            _zetopt::data::init
            ;;
        define | def)
            _zetopt::def::define "$@";;
        def-validator | define-validator)
            _zetopt::def::def_validator "$@";;
        parse)
            _zetopt::parser::parse "$@";;
        define-help | def-help)
            _zetopt::help::define "$@";;
        show-help)
            _zetopt::help::show "$@";;
        isset)
            _zetopt::data::isset "$@";;
        isvalid | isok)
            _zetopt::data::isvalid "$@";;
        count | cnt)
            _zetopt::data::count "$@";;
        pseudo)
            _zetopt::data::pseudo "$@";;
        status | stat)
            _zetopt::data::status "$@";;
        setids)
            _zetopt::data::setids;;
        index | idx)
            _zetopt::data::argidx "$@";;
        type)
            _zetopt::data::type "$@";;
        paramidx | pidx)
            _zetopt::def::paramidx "$@";;
        paramlen | plen)
            _zetopt::def::paramlen "$@";;
        hasval)
            _zetopt::data::hasvalue "$@";;
        value | val)
            _zetopt::data::argvalue "$@";;
        length | len)
            _zetopt::data::arglength "$@";;
        default)
            _zetopt::def::default "$@";;
        defined)
            _zetopt::def::defined "$@";;
        parsed)
            _zetopt::data::parsed "$@";;
        *)
            _zetopt::msg::debug "Undefined Sub-Command:" "$subcmd"
            return 1;;
    esac
}

