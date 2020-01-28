#------------------------------------------------------------
# _zetopt::man
#------------------------------------------------------------
_zetopt::man::show()
{
    if [[ ${1-} == "short" ]]; then
<< __EOHELP__ \cat
NAME
    $ZETOPT_APPNAME -- An option parser for shell scripts
VERSION
    $ZETOPT_VERSION
USAGE
    zetopt {SUB-COMMAND} {ARGS}
OPTIONS
    -v, --version, -h, --help
SUB-COMMANDS
    def def-validator paramidx paramlen default defined
    parse isset setids argv argc type pseudo status count
    hasarg isvalid parsed def-help show-help

Type \`zetopt -h\` to show more help 
__EOHELP__
        return 0
    fi

<< __EOHELP__ \cat
-------------------------------------------------------------
Name        : $ZETOPT_APPNAME -- An option parser for shell scripts
Version     : $ZETOPT_VERSION
License     : MIT License
Author      : itmst71@gmail.com
URL         : https://github.com/itmst71/zetopt
Required    : Bash 3.2+ / Zsh 5.0+, Some POSIX commands
-------------------------------------------------------------
DESCRIPTION
    An option parser for Bash/Zsh scripts.

SYNOPSYS
    $ZETOPT_APPNAME {SUB-COMMAND} {ARGS}

SUB-COMMANDS
    init

    reset
    
    define, def

    def-validator, define-validator

    paramidx, pidx

    paramlen, plen

    parse

    isset

    setids

    argv, value, val

    argc, length, len
    
    type

    pseudo
    
    status

    count

    hasarg, hasval

    isvalid, isok
    
    parsed

    def-help, define-help

    show-help

__EOHELP__
}
