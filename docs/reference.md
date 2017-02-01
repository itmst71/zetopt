
# Reference
**Sorry, documentation is inadequate.**  

## Contents
* [1. Sub-commands](#1-sub-commands)
    * [init](#init)
    * [reset](#reset)
    * [define, def](#define-def)
    * [defined](#defined)
    * [load](#load)
    * [parse](#parse)
    * [parsed](#parsed)
    * [isset](#isset)
    * [count, cnt](#count-cnt)
    * [status, stat](#status-stat)
    * [isok](#isok)
    * [hasval](#hasval)
    * [value, val](#value-val)
    * [length, len](#length-len)
    * [index, idx](#index-idx)
    * [paramidx](#paramidx)
    * [paramlen](#paramlen)
    * [type](#type)
    * [help](#help)
* [2. Value Keys](#2-value-keys)
    * [2-1. Overview](#2-1-overview)
    * [2-2. One-dimensional keys](#2-2-one-dimensional-keys)
    * [2-3. One-dimensional keys for the option that is used more than once](#2-3-one-dimensional-keys-for-the-option-that-is-used-more-than-once)
    * [2-4. One-dimensional keys with a range](#2-4-one-dimensional-keys-with-a-range)
    * [2-5. Two-dimensional keys](#2-5-two-dimensional-keys)
    * [2-6. Sub-commands that can receive valkey](#2-6-sub-commands-that-can-receive-valkey)
* [3. Data Variables](#3-data-variables)
    * [ZETOPT_ARGS](#zetopt_args)
    * [ZETOPT_OPTVALS](#zetopt_optvals)
    * [ZETOPT_DEFINED](#zetopt_defined)
    * [ZETOPT_PARSED](#zetopt_parsed)
* [4. Config Variables](#4-config-variables)
    * [ZETOPT_CFG_VALUE_IFS](#zetopt_cfg_value_ifs)
    * [ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN](#zetopt_cfg_escape_double_hyphen)
    * [ZETOPT_CFG_CLUSTERED_AS_LONG](#zetopt_cfg_clustered_as_long)
    * [ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR](#zetopt_cfg_ignore_subcmd_undeferr)
    * [ZETOPT_CFG_TYPE_PLUS](#zetopt_cfg_type_plus)
    * [ZETOPT_CFG_FLAGVAL_TRUE](#zetopt_cfg_flagval_true)
    * [ZETOPT_CFG_FLAGVAL_FALSE](#zetopt_cfg_flagval_false)
    * [ZETOPT_CFG_ERRMSG](#zetopt_cfg_errmsg)
    * [ZETOPT_CFG_ERRMSG_APPNAME](#zetopt_cfg_errmsg_appname)
    * [ZETOPT_CFG_ERRMSG_COL_MODE](#zetopt_cfg_errmsg_col_mode)
    * [ZETOPT_CFG_ERRMSG_COL_DEFAULT](#zetopt_cfg_errmsg_col_default)
    * [ZETOPT_CFG_ERRMSG_COL_ERROR](#zetopt_cfg_errmsg_col_error)
    * [ZETOPT_CFG_ERRMSG_COL_WARNING](#zetopt_cfg_errmsg_col_warning)
* [5. Status Flags](#5-status-flags)
* [6. Types](#6-types)

## 1. Sub-commands
### init
Initializes internal veriables.
```bash
zetopt init
```

### reset
Resets variables to the state before parsing arguments.
```bash
zetopt reset
```

### define, def
Defines options, sub-commands and positional arguments. (cf. [Tutorial](./tutorial.md))
```bash
zetopt def "ver:v:version"
```

### defined
Prints defined data (cf. [ZETOPT_DEFINED](#zetopt_defined)).
```bash
zetopt def "ver:v:version"
zetopt defined
```
```console
$ cmd
/:::
/ver:v:version:
```

### load
Loads definition data from a file.   
**NOTE: Validation will not be executed**

```bash
# zetopt def "ver:v:version"
# zetopt defined > options.txt
zetopt load options.txt
zetopt parse "$@"
if zetopt isset ver; then
    echo version 1.0.0
fi
```
```console
$ cmd -v
version 1.0.0
```

Substituting directly into the ZETOPT_DEFIND variable is faster.
```bash
zetopt def "ver:v:version"
zetopt defined
```
```console
$ cmd
/:::
/ver:v:version:
```
```bash
# zetopt def "ver:v:version"
# zetopt defined
ZETOPT_DEFINED="
/:::
/ver:v:version:
"
zetopt parse "$@"
if zetopt isset ver; then
    echo version 1.0.0
fi
```


### parse
Parses command-line arguments.
```bash
zetopt parse "$@"
```

### parsed
Prints parsed data (cf. [ZETOPT_PARSED](#zetopt_parsed)).
```bash
zetopt def "foo:f @"
zetopt parse "$@"
zetopt parsed
```
```console
$ cmd -f foo
/:::::0:1
/foo:f::0:1:0:1
```

### isset
Checks if an option was set
```bash
zetopt def "opt:o"
zetopt parse "$@"
if zetopt isset opt; then
    echo "the -o option is set"
fi
```
```console
$ cmd -o
the -o option is set
```

### count, cnt
Counts the number of use times of an option.
```bash
zetopt def "verbose:V"
zetopt parse "$@"
if zetopt isset verbose; then
    echo "the -V option is set $(zetopt cnt verbose) times."
fi
```
```console
$ cmd -VVVVV
the -V option is set 5 times.
```

### status, stat
Checks the status of an option.  
Supports only the one-dementional keys (cf. [2. Value Keys](#2-value-keys)).
```bash
zetopt def "foo:f @ %"
zetopt parse "$@"
if zetopt isset foo; then
    case $(zetopt stat foo) in
        $ZETOPT_STATUS_NORMAL)
            echo "Status is normal";;
        $ZETOPT_STATUS_MISSING_REQUIRED_OPTARGS)
            echo "The first argument is required.";;
        $ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS)
            echo "The second argument is not set. But it's optional.";;
    esac
fi
```
```console
$ cmd -f
zetopt: Error: Missing Required Option Argument(s): -f
The first argument is required.
$ cmd -f A
The second argument is not set. But it's optional.
$ cmd -f A B
Status is normal
```

### isok
Checks if the status is OK. Ignores that an optional argument is not set.  
Supports only the one-dementional keys (cf. [2. Value Keys](#2-value-keys)).
```bash
zetopt def "foo:f @ %"
zetopt parse "$@"
if zetopt isok foo; then
    echo "OK"
fi
```
```console
$ cmd -f A B
OK
$ cmd -f A
OK
$ cmd -f
zetopt: Error: Missing Required Option Argument(s): -f
```

If no value key is specified, it is judged only by whether the last status is OK.
```console
$ cmd -f A -f B
OK
$ cmd -f -f B
zetopt: Error: Missing Required Option Argument(s): -f
OK
```

If you want to process only when all statuses are OK, you can use `@` as follows
```bash
zetopt def "foo:f @ %"
zetopt parse "$@"
if zetopt isok foo @; then
    echo "All OK"
fi
```
```console
$ cmd -f A -f B
All OK
$ cmd -f -f B
zetopt: Error: Missing Required Option Argument(s): -f
```

### hasval
Checks if the option has any value.
Supports only the one-dementional keys (cf. [2. Value Keys](#2-value-keys)).
```bash
zetopt def "foo:f %"
zetopt parse "$@"
if zetopt hasval foo; then
    zetopt val foo
fi
```
```console
$ cmd -f A
A
$ cmd -f
```

### value, val
Gets the value of the option or sub-command that has arguments.  
Supports the two-dementional keys (cf. [2. Value Keys](#2-value-keys)).
```bash
zetopt def "foo:f @ @ @"
zetopt parse "$@"
if zetopt isok foo; then
    echo "the values of the -f option are "$(zetopt val foo)
fi
```
```console
$ cmd -f A B C
the values of the -f option are A B C
```

### length, len
Gets the length of arguments actually set.  
Supports only the one-dementional keys (cf. [2. Value Keys](#2-value-keys)).
```bash
zetopt def "foo:f % % %"
zetopt parse "$@"
if zetopt isset foo; then
    echo "Length=$(zetopt len foo)"
fi
```
```console
$ cmd -f A B C
Length=3
$ cmd -f A B
Length=2
$ cmd -f A
Length=1
$ cmd -f
Length=0
```

### index, idx
Gets the index list for referring to the array `$ZETOPT_OPTVALS`.  
Supports the two-dementional keys (cf. [2. Value Keys](#2-value-keys)).
```bash
zetopt def "foo:f @ @ @"
zetopt def "bar:b @ @ @"
zetopt parse "$@"
if zetopt isok foo; then
    echo "Indexes of -f :" $(zetopt idx foo @:@)
fi

if zetopt isok bar; then
    echo "Indexes of -b :" $(zetopt idx bar @:@)
fi

if zetopt isok foo && zetopt isok bar; then
    for value in "${ZETOPT_OPTVALS[@]}"
    do
        echo "ZETOPT_OPTVALS[$i]=$value"
        : $((${i:-0}++))
    done
fi
```
```console
$ cmd -f A B C
Indexes of -f : 0 1 2
$ cmd -b A B C -f D E F -b G H I -f J K L
Indexes of -f : 3 4 5 9 10 11
Indexed of -b : 0 1 2 6 7 8
ZETOPT_OPTVALS[0]=A
ZETOPT_OPTVALS[1]=B
ZETOPT_OPTVALS[2]=C
ZETOPT_OPTVALS[3]=D
ZETOPT_OPTVALS[4]=E
ZETOPT_OPTVALS[5]=F
ZETOPT_OPTVALS[6]=G
ZETOPT_OPTVALS[7]=H
ZETOPT_OPTVALS[8]=I
ZETOPT_OPTVALS[9]=J
ZETOPT_OPTVALS[10]=K
ZETOPT_OPTVALS[11]=L
```

### paramidx
Gets the index of the parameter name.
```bash
zetopt def "foo:f @foo @bar @baz"
zetopt parse "$@"
echo "foo=$(zetopt paramidx foo foo)"
echo "bar=$(zetopt paramidx foo bar)"
echo "baz=$(zetopt paramidx foo baz)"
```
```console
$ cmd
foo=0
bar=1
baz=2
```

### paramlen
Gets the length of the parameters.
```bash
zetopt def "foo:f @foo @bar %baz"
zetopt parse "$@"
echo "zetopt paramlen foo all      : $(zetopt paramlen foo all)"
echo "zetopt paramlen foo required : $(zetopt paramlen foo required)"
echo "zetopt paramlen foo optional : $(zetopt paramlen foo optional)"
echo "zetopt paramlen foo          : $(zetopt paramlen foo)"
echo "zetopt paramlen foo @        : $(zetopt paramlen foo @)"
echo "zetopt paramlen foo %        : $(zetopt paramlen foo %)"
```
```console
$ cmd
zetopt paramlen foo all      : 3
zetopt paramlen foo required : 2
zetopt paramlen foo optional : 1
zetopt paramlen foo          : 3
zetopt paramlen foo @        : 2
zetopt paramlen foo %        : 1
```

### type
Gets the option type that was used with in command-line.  
Supports only the one-dementional keys (cf. [2. Value Keys](#2-value-keys)).
```bash
ZETOPT_CFG_TYPE_PLUS=true
zetopt def "opt:o:option"
zetopt parse "$@"
if zetopt isset opt; then
    case in $(zetopt type opt)
        $ZETOPT_TYPE_SHORT)  echo "-";;
        $ZETOPT_TYPE_LONG)   echo "--";;
        $ZETOPT_TYPE_PLUS)   echo "+";;
    esac
fi
```
```console
$ cmd -o
-
$ cmd --option
--
$ cmd +o
+
```

### help
***Sorry, not implemented yet.***  
See [ToDo](../README.md#todo)


## 2. Value Keys
### 2-1. Overview
Value key is a key for getting arguments, exit status, parameter names etc. from parsed data and definition data.  
As a value key, `zetopt` supports positive integers(e.g. `0 2 3`), negative integers(e.g. `-1 -3`), meta characters(e.g. `@ $ ^`) and parameter names.   
They can be formed two-dimensional key by a colon `:` separator to access all arguments and status etc. of an option used more than once.  
Comma `,` works as a range separator.

### 2-2. One-dimensional keys
```bash
zetopt def foo:f "@foo @bar @baz"
zetopt parse "$@"
if zetopt isok foo @; then
    echo "zetopt val foo              :" $(zetopt val foo            )
    echo "zetopt val foo 0            :" $(zetopt val foo 0          )
    echo "zetopt val foo 1            :" $(zetopt val foo 1          )
    echo "zetopt val foo 2 1 0        :" $(zetopt val foo 2 1 0      )
    echo "zetopt val foo -3 -2 -1     :" $(zetopt val foo -3 -2 -1   )
    echo "zetopt val foo foo          :" $(zetopt val foo foo        )
    echo "zetopt val foo bar          :" $(zetopt val foo bar        )
    echo "zetopt val foo baz foo      :" $(zetopt val foo baz foo    )
    echo "zetopt val foo ^            :" $(zetopt val foo ^          )
    echo "zetopt val foo $            :" $(zetopt val foo $          )
    echo "zetopt val foo $ bar ^      :" $(zetopt val foo $ bar ^    )
    echo "zetopt val foo @            :" $(zetopt val foo @          )
fi
```
```console
$ cmd -f A B C
zetopt val foo              : A B C
zetopt val foo 0            : A
zetopt val foo 1            : B
zetopt val foo 2 1 0        : C B A
zetopt val foo -3 -2 -1     : A B C
zetopt val foo foo          : A
zetopt val foo bar          : B
zetopt val foo baz foo      : C A
zetopt val foo ^            : A
zetopt val foo $            : C
zetopt val foo $ bar ^      : C B A
zetopt val foo @            : A B C
```

**NOTE**  
If `EXTENDED_GLOB` is enabled in `zsh` you need to escape or quote `^`.  

### 2-3. One-dimensional keys for the option that is used more than once
If the target option is used more than once, the one-dimensional key always refers to the last data.
```console
$ cmd -f A B C -f D E F -f G H I
zetopt val foo              : G H I
zetopt val foo 0            : G
zetopt val foo 1            : H
zetopt val foo 2 1 0        : I H G
zetopt val foo foo          : G
zetopt val foo bar          : H
zetopt val foo baz foo      : I G
zetopt val foo ^            : G
zetopt val foo $            : I
zetopt val foo $ bar ^      : I H G
zetopt val foo @            : G H I
```

### 2-4. One-dimensional keys with a range
Comma `,` works as a range separator.

```bash
zetopt def foo:f "@foo @bar @baz"
zetopt parse "$@"
if zetopt isok foo @; then
    echo "zetopt val foo 0,2          :" $(zetopt val foo 0,2        )
    echo "zetopt val foo 2,-2         :" $(zetopt val foo 2,-2       )
    echo "zetopt val foo ^,$          :" $(zetopt val foo ^,$        )
    echo "zetopt val foo 1,baz        :" $(zetopt val foo 1,baz      )
    echo "zetopt val foo bar,^        :" $(zetopt val foo bar,^      )
fi
```
```console
$ cmd -f A B C
zetopt val foo 0,2          : A B C
zetopt val foo 2,-2         : C B
zetopt val foo ^,$          : A B C
zetopt val foo 1,baz        : B C
zetopt val foo bar,^        : B A
```

### 2-5. Two-dimensional keys
Connecting a one-dimensional key with a colon becomes a two-dimensional key.  
However, since the left side of the colon represents the session number, parameter names can not be used.
```bash
zetopt def foo:f "@foo @bar @baz"
zetopt parse "$@"
if zetopt isok foo @; then
    echo "zetopt val foo 0:0          :" $(zetopt val foo 0:0        )
    echo "zetopt val foo 1:$ 2:baz    :" $(zetopt val foo 1:$ 2:baz  )
    echo "zetopt val foo 2:@          :" $(zetopt val foo 2:@        )
    echo "zetopt val foo @:@          :" $(zetopt val foo @:@        )
    echo "zetopt val foo @:bar        :" $(zetopt val foo @:bar      )
    echo "zetopt val foo $,^:$,^      :" $(zetopt val foo $,^:$,^    )
    echo "zetopt val foo -1,-3:@      :" $(zetopt val foo -1,-3:@    )
fi
```
```console
$ cmd -f A B C -f D E F -f G H I
zetopt val foo 0:0          : A
zetopt val foo 1:$ 2:baz    : F I
zetopt val foo 2:@          : G H I
zetopt val foo @:@          : A B C D E F G H I
zetopt val foo @:bar        : B E H
zetopt val foo $,^:$,^      : I H G F E D C B A
zetopt val foo -1,-3:@      : G H I D E F A B C
```

### 2-6. Sub-commands that can receive valkey
There are subcommands of the type that can accept two dimensional keys and one that can accept only one-dimensional keys.

Sub-commands supporting two-dementional keys.  
`index, idx` `value, val`

Sub-commands supporting only one-dementional keys.  
`isok` `length, len` `type` `status, stat`


## 3. Data Variables
#### ZETOPT_ARGS  
Stores all positional arguments in the array type.
```bash
zetopt parse "$@"
for arg in "${ZETOPT_ARGS[@]}"
do 
    echo "$arg"
done
```
```console
$ cmd A B C
A
B
C
```

#### ZETOPT_OPTVALS  
Stores all values of the option arguments in the array type.
```bash
zetopt def "foo:f @ @ @"
zetopt parse "$@"
if zetopt isok foo; then
    for optarg in "${ZETOPT_OPTVALS[@]}"
    do 
        echo "$optarg"
    done
fi
```
```console
$ cmd -f A B C
A
B
C
```

#### ZETOPT_DEFINED
Stores the definition data in the string type separated with a new line code `$'\n'` like below.  
This data must be sorted with `sort -t : -k 1,1` for binary search.  
The format is:
```
<ID>:<SHORT-OPTION>:<LONG-OPTION>:<ARG>
```
[defined](#defined) sub-command can print the sorted data like below.
```bash
/:::
/commit/:::
/commit/msg:m::@msg
/fibo:F::%...
/foo:f::@foo @bar @baz
/hyphen:h::-@var...
/optional:o::%optional
/remote/:::
/remote/add/:::@name @url
/required:r::@required
/ver+:v:version:
/verbose:V::
```

#### ZETOPT_PARSED
Stores the parsed data in the string type for fater searching.  
The format is:
```
<ID>:<SHORT-OPTION>:<LONG-OPTION>:<ARG>:<TYPE>:<STATUS>:<COUNT>
```
[parsed](#parsed) sub-command prints data like below.
```bash
/::::::0
/commit/::::::0
/commit/msg:m:::::0
/fibo:F:::::0
/foo:f::0 1 2:1:0:1
/hyphen:h:::::0
/optional:o:::::0
/remote/::::::0
/remote/add/::::::0
/required:r:::::0
/ver:v:version::::0
/verbose:V:::::0
```

## 4. Config Variables
For boolean-like variables, set one of the following values.  
They are not case sensitive.  
  
Truthy values:
```
0, true, yes, y, enabled, enable, on
```
Falsy values:
```
1, false, no, n, disabled, disable, off
 ```


#### ZETOPT_CFG_VALUE_IFS
`IFS` when `val` sub-command outputs values.  

**Default**
```bash
ZETOPT_CFG_VALUE_IFS=$'\n'
```

**Example**
```bash
zetopt def "foo:f @ @ @"
zetopt parse "$@"
if zetopt isok foo; then
    zetopt val foo
    ZETOPT_CFG_VALUE_IFS=,
    zetopt val foo
fi
```
```console
$ cmd -f A B C
A
B
C
A,B,C
```

#### ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN
Escape `--` and regard as an argument.  

**Default**
```bash
ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN=false
```

**Example**
```bash
zetopt def "foo:f @ % %"
zetopt parse "$@"
if zetopt isok foo; then
    echo "ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN=false"
    echo $(zetopt val foo)
fi

ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN=true
zetopt reset

zetopt parse "$@"
if zetopt isok foo; then
    echo "ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN=true"
    echo $(zetopt val foo)
fi
```
```console
$ cmd -f A -- B
ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN=false
A
ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN=true
A -- B
```

#### ZETOPT_CFG_CLUSTERED_AS_LONG
Accept `-type`. Incompatible with clustered short options.  

**Default**
```bash
ZETOPT_CFG_CLUSTERED_AS_LONG=false
```

**Example**
```bash
zetopt def "opt:abcdefg"

ZETOPT_CFG_CLUSTERED_AS_LONG=false
echo "ZETOPT_CFG_CLUSTERED_AS_LONG=false"

zetopt parse "$@"
if zetopt isset opt; then
    echo "the option -abcdefg is set"
fi

ZETOPT_CFG_CLUSTERED_AS_LONG=true
echo "ZETOPT_CFG_CLUSTERED_AS_LONG=true"
zetopt reset

zetopt parse "$@"
if zetopt isset opt; then
    echo "the option -abcdefg is set"
fi
```
```console
$ cmd -abcdefg
ZETOPT_CFG_CLUSTERED_AS_LONG=false
zetopt: Warning: Undefined Option(s): -a -b -c -d -e -f -g
ZETOPT_CFG_CLUSTERED_AS_LONG=true
the option -abcdefg is set
```

#### ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR
Ignore the undefined sub-command error and regard the argument as a positional argument.  

**Default**
```bash
ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR=false
```

**Example**  
If any sub-command is defined, passing an argument that does not match the sub-command name will result in an error.
```bash
zetopt def /subcmd/
zetopt parse "$@"
if zetopt isset /subcmd/; then
    echo "subcmd is used"
fi
```
```console
$ cmd subcmd
subcmd is used
$ cmd foo
zetopt: Error: Undefined Sub-Command:  foo
```

When `ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR` is enabled, if there is no sub-command name that matches the argument, it is treated as a positional argument.
```bash
zetopt def /subcmd/
ZETOPT_CFG_IGNORE_SUBCMD_UNDEFERR=true
zetopt parse "$@"
if zetopt isset /subcmd/; then
    echo "subcmd is used"
fi
if [[ ${#ZETOPT_ARGS[@]} -ne 0 ]]; then
    echo "${ZETOPT_ARGS[*]}"
fi
```
```console
$ cmd subcmd
subcmd is used
$ cmd foo
foo
```

#### ZETOPT_CFG_TYPE_PLUS  
Accept `+o` type options.

**Default**
```bash
ZETOPT_CFG_TYPE_PLUS=false
```

**Example**
```bash
zetopt def "opt:o"
ZETOPT_CFG_TYPE_PLUS=true
zetopt parse "$@"
if zetopt isset opt; then
    case $(zetopt type opt) in
        $ZETOPT_TYPE_SHORT)
            echo "-o is set";;
        $ZETOPT_TYPE_PLUS)
            echo "+o is set";;
    esac
fi
```
```console
$ cmd -o
-o is set
$ cmd +o
+o is set
```

#### ZETOPT_CFG_FLAGVAL_TRUE
#### ZETOPT_CFG_FLAGVAL_FALSE  

**Default**
```bash
ZETOPT_CFG_FLAGVAL_TRUE=0
ZETOPT_CFG_FLAGVAL_FALSE=1
```

**Example**
```bash
zetopt def "opt:o"
ZETOPT_CFG_TYPE_PLUS=true

ZETOPT_CFG_FLAGVAL_TRUE=0
ZETOPT_CFG_FLAGVAL_FALSE=1
zetopt parse "$@"
if zetopt isset opt; then
    zetopt val opt
fi

zetopt reset

ZETOPT_CFG_FLAGVAL_TRUE=true
ZETOPT_CFG_FLAGVAL_FALSE=false
zetopt parse "$@"
if zetopt isset opt; then
    zetopt val opt
fi
```
```console
$ cmd -o
0
true
$ cmd +o
1
false
```


#### ZETOPT_CFG_ERRMSG
Print error messages.  

**Default**
```bash
ZETOPT_CFG_ERRMSG=true
```

#### ZETOPT_CFG_ERRMSG_APPNAME
Application name showed in error message.  

**Default**
```bash
ZETOPT_CFG_ERRMSG_APPNAME=zetopt
```

#### ZETOPT_CFG_ERRMSG_COL_MODE
The mode of coloring message.  

**Default**
```bash
ZETOPT_CFG_ERRMSG_COL_MODE=auto
```
* `auto`  : colors message depending on whether `stderr` is connected to `TTY`
* `never` : never colors message.  
* `always`: always colors message.   

#### ZETOPT_CFG_ERRMSG_COL_DEFAULT
Default message text color with ANSI escape color code.  

**Default**
```bash
ZETOPT_CFG_ERRMSG_COL_DEFAULT="0;0;39"
```

#### ZETOPT_CFG_ERRMSG_COL_ERROR
Error message text color with ANSI escape color code.  

**Default**
```bash
ZETOPT_CFG_ERRMSG_COL_ERROR="0;1;31"
```

#### ZETOPT_CFG_ERRMSG_COL_WARNING
Warning message text color with ANSI escape color code.  

**Default**
```bash
ZETOPT_CFG_ERRMSG_COL_WARNING="0;0;33"
```


## 5. Status Flags
See [status](#status-stat) sub-command.

```bash
ZETOPT_STATUS_NORMAL=0
ZETOPT_STATUS_MISSING_OPTIONAL_OPTARGS=$((1 << 0))
ZETOPT_STATUS_MISSING_OPTIONAL_ARGS=$((1 << 1))
ZETOPT_STATUS_MISSING_REQUIRED_OPTARGS=$((1 << 2))
ZETOPT_STATUS_MISSING_REQUIRED_ARGS=$((1 << 3))
ZETOPT_STATUS_UNDEFINED_OPTION=$((1 << 4))
ZETOPT_STATUS_UNDEFINED_SUBCMD=$((1 << 5))
ZETOPT_STATUS_INVALID_OPTFORMAT=$((1 << 6))
```

## 6. Types
See [type](#type) sub-command.
```bash
ZETOPT_TYPE_CMD=0
ZETOPT_TYPE_SHORT=1
ZETOPT_TYPE_LONG=2
ZETOPT_TYPE_PLUS=3
```
