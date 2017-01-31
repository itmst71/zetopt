#!/usr/bin/env bash
export PATH="/usr/bin:/bin"
export IFS=$' \t\n'
export LC_ALL=C LANG=C

if [[ -n ${ZSH_VERSION-} ]]; then
    setopt NO_EXTENDED_GLOB
    setopt KSHARRAYS
fi

# source zetopt.sh in the parent directory
if ! . "${0%/*}/../zetopt.sh"; then
    exit 1
fi

zetopt init
zetopt def "ver:v:version"            # -v --version
zetopt def "opt:o @foo @bar %baz"     # -o {foo} {bar} [baz]
zetopt def "/remote/add/ @NAME @URL"  # remote add {NAME} {URL}
zetopt def "/commit/msg:m @MSG"       # commit -m {MSG}
zetopt parse "$@"

# -v --version
if zetopt isset ver; then
    echo version 1.0.0
fi

# -o {foo} {bar} [baz]
if zetopt isok opt @; then
    echo "zetopt val opt       :" $(zetopt val opt)
    echo "zetopt val opt foo   :" $(zetopt val opt foo)
    echo "zetopt val opt 0:0   :" $(zetopt val opt 0:0)
    echo "zetopt val opt 1:$   :" $(zetopt val opt 1:$)
    echo "zetopt val opt 2:bar :" $(zetopt val opt 2:bar)
    echo "zetopt val opt @:^   :" $(zetopt val opt @:^)
    echo "zetopt val opt @:@   :" $(zetopt val opt @:@)
fi

# remote add {NAME} {URL}
if zetopt isok /remote/add/; then
    zetopt val /remote/add/ NAME
    zetopt val /remote/add/ URL
fi

# commit -m {MSG}
if zetopt isok /commit/msg; then
    zetopt val /commit/msg MSG
fi
