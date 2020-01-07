[![Build Status](https://travis-ci.com/itmst71/zetopt.svg?branch=develop)](https://travis-ci.com/itmst71/zetopt)

# zetopt
An option parser for shell scripts.


# Description
`zetopt` is a command-line option parser for all `Bash`/`Zsh` scriptors who are not satisfied with `getopt`/`getopts`.  
It is no longer necessary to handle troublesome processing using `for/while-loop` or `case` statements to analyze complicated options,
or prepare variables to store flags and arguments.  
In addition to almost all option formats, `zetopt` also supports sub-commands.

# Demo

```bash
$ cat ./examples/demo.sh
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
```
```console
$ cd ./examples/
$ ./demo.sh -v
version 1.0.0
$ ./demo.sh --version
version 1.0.0
$ ./demo.sh -o A B C -o D E -o F G H
zetopt val opt       : F G H
zetopt val opt foo   : F
zetopt val opt 0:0   : A
zetopt val opt 1:$   : E
zetopt val opt 2:bar : G
zetopt val opt @:^   : A D F
zetopt val opt @:@   : A B C D E F G H
$ ./demo.sh remote add origin https://github.com/itmst71/zetopt.git
origin
https://github.com/itmst71/zetopt.git
$ ./demo.sh commit -m "first commit"
first commit
```

# Features
* Implemented as a `Bash` function.
* Supports `Bash 3.2+` and `Zsh 5.0+`.
* Supports long and short options. (e.g. `--long` and `-s`)
* Supports handling short and long options in a pair. (e.g. `-v` and `--version`)
* Supports specifying optargs by =. (e.g. `--long=foo` and `-a=foo`)
* Supports clustered short options. (e.g. `-abcdef`)
* Supports placing optargs after clustered short options. (e.g. `-abc foo -def=bar`)
* Supports short options with + sign. (e.g. `+o foo` `+exuo=foo`)
* Supports long options with a single hyphen. (e.g. `-type f`)
* Supports placing options after arguments. (e.g. `cmd arg1 arg2 -o --option`)
* Supports required optargs. (e.g. `-r foo` : Error occures if "foo" not given)
* Supports optional optargs. (e.g. `-o foo` : No error occures even if "foo" not given)
* Supports multiple optargs. (e.g. `-m A B C`)
* Supports counting the number of use times of an option. (e.g. `-VVVV`)
* Supports saving and getting all optargs of an option used more than once. (e.g. `-a A -a B`)
* Supports two-dimensional keys to access all values of an option used more than once. (e.g. `0:@`)
* Supports getting argument values by names. (e.g. `zetopt val foo name1 name2`)
* Supports variable length optargs. (e.g. `--fibo 0 1 1 2 3 5 8 13 21 34`)
* Supports optargs begining with `-`. (e.g. `--negative-number -1777771`)
* Supports sub-commands. (e.g. `cmd remote add <NAME> <URL>`)
* Supports sub-command options. (e.g. `cmd commit -m "first commit"`)
* Supports global options and overriding them in a sub-command namespace.
* Supports configuring how to handle special arguments `""` and `--` by environment variables.
* External commands and their options used in `zetopt` are only those defined by `POSIX`.

# Requirements
* `Bash 3.2+` / `Zsh 5.0+`
* Some `POSIX` commands

# Installation
1. `git clone`
```console
$ git clone https://github.com/itmst71/zetopt.git
```

2. `. zetopt.sh` in your script.
```bash
#!/usr/bin/env bash
. /path/to/zetopt.sh
```

# Usage
## Synopsys
```
zetopt [-v | --version | -h | --help]
zetopt {SUB-COMMAND} [ARGUMENTS]
```

## Flow
1. Source zetopt.sh
2. Define options
3. Parse arguments
4. Use parsed data

```bash
#!/usr/bin/env bash
. /path/to/zetopt.sh        # 1. Source zetopt.sh
zetopt def "ver:v:version"  # 2. Define options
zetopt parse "$@"           # 3. Parse arguments
if zetopt isset ver; then   # 4. Use parsed data
    echo version 1.0.0
fi
```

# Tutorial
See **[Tutorial](./docs/tutorial.md)**

# Reference
See **[Reference](./docs/reference.md)**

# Todo
* Documentation
* Adding test code
* Improving and adding sub-commands
* Improving performance
* Better error message

```bash
zetopt def "/remote/add/ @NAME @URL"
```
```console
$ cmd remote add
zetopt: Error: Missing Required Argument(s): remote add 2 Argument(s) Required  # current
zetopt: Error: Missing Required Argument(s): remote add {NAME} {URL}            # better
```

* Supporting defining help text to display like the following simple help.  

```bash
zetopt def "help:h:help     #Show help and exit."
zetopt def "ver:v:version   #Show version and exit."
if zetopt isset help; then
    zetopt help
    exit 0
fi
```
```console
$ cmd -h
Name
  cmd -- The awesome command

Description
  The awesome command to show version.

Options
  -h, --help      Show help and exit.
  -v, --version   Show version and exit.
```

# License
MIT
