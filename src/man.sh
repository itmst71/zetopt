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
SUB-COMMANDS
    version help init reset define defined
    parse data get isset count status index

Type \`zetopt help\` to show more help 
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

    parse

    isset

    isvalid

    hasval

    value, val

    length, len
    
    index, idx

    paramidx, pidx

    paramlen, plen

    status, stat

    count, cnt
    
__EOHELP__
}
