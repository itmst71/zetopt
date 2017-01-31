
# Tutorial
I will explain how to define options and sub-commands and also briefly describe the `zetopt` sub-commands used in the sample code.  

## Contents
* [1. Defining Options](#1-defining-options)
    * [1-1. The basic format](#1-1-the-basic-format)
    * [1-2. Options that require NO argument](#1-2-options-that-require-no-argument)
    * [1-3. Options that require an argument](#1-3-options-that-require-an-argument)
    * [1-4. Options that require or do not require an argument](#1-4-options-that-require-or-do-not-require-an-argument)
    * [1-5. Options that require multiple arguments](#1-5-options-that-require-multiple-arguments)
    * [1-6. Options that can take arguments begining with -](#1-6-options-that-can-take-arguments-begining-with-)
    * [1-7. Option parameter names](#1-7-option-parameter-names)
    * [1-8. Variable length arguments](#1-8-variable-length-arguments)
    * [1-9. Multiple options at once](#1-9-multiple-options-at-once)
* [2. Defining Sub-commands](#2-defining-sub-commands)
    * [2-1. Namespace](#2-1-namespace)
    * [2-2. Namespace format](#2-2-namespace-format)
    * [2-3. Sub-commands](#2-3-sub-commands)
* [3. Defining Sub-command Options](#3-defining-sub-command-options)
* [4. Defining Global Options](#4-defining-global-options)
    * [4-1. Global options](#4-1-global-options)
    * [4-2. Overriding global options](#4-2-overriding-global-options)
* [5. Defining Positional Arguments](#5-defining-positional-arguments)

## 1. Defining options
### 1-1. The basic format
```
<ID>:<SHORT-OPTION>:<LONG-OPTION> <ARGUMENTS>
```
The `<ID>` and option names are separated by colons.  
Note that just before `<ARGUMENTS>` is a **SPACE**, not a colon.  

`<ID>` must be constructed with characters in `[a-zA-Z0-9_]`.  
You can omit parts that are not necessary except `<ID>`.

### 1-2. Options that require NO argument
Let's define `-v` and `--version` as flag options that just store true and do not require arguments.  
In the following code you can define both the `-v` and `--version` options in a pair.  
Use [def](./reference.md#define-def) sub-command to define options. `def` can be `define`.
```bash
zetopt def "ver:v:version"
```
`ver` is the ID to access the parsed data of the `-v` and `--version` options.  

**NOTE**  
It might not be necessary to quote the definitions if you use the current mainstream version of `Zsh`/`Bash` with the standard settings,
but it seems safe to quote them in the script to be distributed.

Either short option or long option can be omitted.
```bash
zetopt def "ver:version"  # short option omitted
zetopt def "ver:v"        # long option omitted
```

Now, we have defined the `-v` and `--version` options. See the complete code below.  
[parse](./reference.md#parse) sub-command can parse command-line arguments.  
[isset](./reference.md#isset) sub-command can check if the option is used.
```bash
#!/usr/bin/env bash
. /path/to/zetopt.sh
zetopt def "ver:v:version"
zetopt parse "$@"
if zetopt isset ver; then
    echo version 1.0.0
fi
```
```console
$ cmd -v
version 1.0.0
$ cmd --version
version 1.0.0
```

### 1-3. Options that require an argument
Next, let't define options that require an argument.
`@` means a required argument.  
[isok](./reference.md#isok) sub-command can check if exit code is `0`.  
[val](./reference.md#value-val) sub-command can get argument values. `val` can be `value`.
```bash
zetopt def "foo:f @"
zetopt parse "$@"
if zetopt isok foo; then
    zetopt val foo
fi
```
```console
$ cmd -f bar
bar
```
Error occures if no argument given.
```console
$ cmd -f 
zetopt: Error: Missing Required Option Argument(s): -f
```

### 1-4. Options that require or do not require an argument
`%` means an optional argument.
```bash
zetopt def "foo:f %"
```
Error doesn't occure even if no argument given. 
```console
$ cmd -f foo
foo
$ cmd -f
```

### 1-5. Options that require multiple arguments
To define options that require more than one argument, you simply place more than one `@` or `%`.  
```bash
zetopt def "foo:f @ @ % %"
zetopt parse "$@"
if zetopt isok foo; then
    zetopt val foo
fi
```
```console
$ cmd -f "A B C" "D   E   F" "    G H I"
A B C
D   E   F
    G H I
```
[val](./reference.md#value-val) sub-command gets values with `IFS=$'\n'` by default. 


### 1-6. Options that can take arguments begining with `-`
Just adding `-` before `@` or `%`, the option can take arguments beginning with `-`.
```bash
zetopt def "foo:f -@ -%"
zetopt parse "$@"
if zetopt isok foo; then
    zetopt val foo
fi
```
```console
$ cmd -f -1 -100
-1
-100
```
Adding `--`, the option can also take arguments beginning with `--`.
```bash
zetopt def "foo:f --@ --%"
zetopt parse "$@"
if zetopt isok foo; then
    zetopt val foo
fi
```
```console
$ cmd -f -1 --100
-1
--100
```
**NOTE**  
Enable [$ZETOPT_CFG_ESCAPE_DOUBLE_HYPHEN](./reference.md#zetopt_cfg_escape_double_hyphen) 
if you want to treat `--` itself representing the end of the options in the command-line as an argument.

### 1-7. Option parameter names
You can give the parameter names for each option arguments and get their values by the names.
```bash
zetopt def "foo:f @bar @baz -@qux"
zetopt parse "$@"
if zetopt isok foo; then
    zetopt val foo bar
    zetopt val foo qux baz
fi
```
```console
$ cmd -f 1 2 -3
1
-3
2
```

### 1-8. Variable length arguments
`...` means variable length arguments.  
[len](./reference.md#lenght-len) sub-command can get the length of arguments set.
```bash
zetopt def "numbers:n %num..."
zetopt parse "$@"
if zetopt isok numbers; then
    echo Length=$(zetopt len numbers)              # print the length of arguments
    echo Last 5 Values=$(zetopt val numbers -5,$)  # print the last 5 values
fi
```
```console
$ cmd -n 0 1 1 2 3 5 8 13 21 34
Length=10
Last 5 Values=5 8 13 21 34
```
BTW if you specify an index out of range for the `val` subcommand, an "`Index Out of Range`" error will occur.
```bash
$ cmd -n 1 3 7 15
Length=4
zetopt: Error: Index Out of Range: -5,$
Last 5 Values=
```

Please refer to [Value Keys](./reference.md#2-value-keys) for the index format that can be passed to the `val` subcommand.

### 1-9. Multiple options at once
`;` and a new line work as a definition separator.  
You can slightly reduce overhead by defining multiple options at once.
```bash
# -v, --version, -f
zetopt def "ver:v:version; foo:f @ @ @"
# -b, -z
zetopt def "
    bar:b @bar1 @bar2 %bar3 %bar4
    baz:z %baz...
"
```
**NOTE**  
Using the [load](./reference.md#load) sub-command will more reduce the overhead as you can omit the process to parse option definitions at runtime.

## 2. Defining sub-commands
### 2-1. Namespace
`zetopt` supports defining sub-commands by using namespace.  
The options that we have defined are actually defined in the root namespace `/`.  
  
`zetopt` can accept definitions with `/` omitted.  
If you do not omit the root namespace, the previous definitions are as follows.
```bash
zetopt def "/ver:v:version"
zetopt def "/foo:f @ @ @ % % %"
zetopt parse "$@"
if zetopt isset /ver; then
    echo version 1.0.0
fi
if zetopt isok /foo; then
    zetopt val /foo
fi
```

### 2-2. Namespace format
Namespace must begin with `/` and end with `/`.  
The characters between `/` and `/` must be constructed with characters in `[a-zA-Z0-9_-]`.  
`-` can not be at the beginning or end. Also, it can not be constructed only with `-`.  
Namespaces like following are valid.
```bash
/foo/
/foo-BAR/
/_foo0/012_bar-baz/
```

### 2-3. Sub-commands
Now, let's define a sub-command like `git remote add <NAME> <URL>` with using namespaces.  
Define namespaces with slash delimiters like a directory path.  
The other parts are almost the same as before.
```bash
zetopt def "/remote/add/ @NAME @URL"
zetopt parse "$@"
if zetopt isok /remote/add/; then
    echo NAME=$(zetopt val /remote/add/ NAME)
    echo URL=$(zetopt val /remote/add/ URL)
fi
```
```console
$ cmd remote add origin https://github.com/itmst71/zetopt.git
NAME=origin
URL=https://github.com/itmst71/zetopt.git
```

## 3. Defining Sub-command options
Next let's define a sub-command option like `git commit -m <msg>`.  
It just adds a namespace to the ID of the option definition.
```bash
zetopt def "/commit/msg:m @msg"
zetopt parse "$@"
if zetopt isok /commit/msg; then
    echo Message: $(zetopt val /commit/msg)
fi
```
```console
$ cmd commit -m "first commit"
Message: first commit
```

## 4. Defining global options
### 4-1. Global options
Normally options are defined as local options only visible from the same namespace.  
```bash
zetopt def "/ver:v:version"
zetopt def "/subcmd/flag:f"
zetopt parse "$@"
if zetopt isset ver; then
    echo version 1.0.0
fi
```
```console
$ cmd subcmd -v
zetopt: Warning: Undefined Option(s): subcmd -v
``` 

Now, let's define a global options that can be seen from sub-command namespaces.  
Just add `+` at the end of ID.
```bash
zetopt def "/ver+:v:version"
zetopt def "/subcmd/flag:f"
zetopt parse "$@"
if zetopt isset ver; then
    echo version 1.0.0
fi
```
```console
$ cmd subcmd -v
version 1.0.0
```

## 4-2. Overriding global options
Global options defined in the parent namespace can be overridden with the same name option in the sub-command namespace.
```bash
zetopt def "/ver+:v:version"
zetopt def "/subcmd/ver:v"
zetopt parse "$@"
if zetopt isset ver; then
    echo version 1.0.0
fi
if zetopt isset /subcmd/ver; then
    echo subcmd version 2.0.0
fi
```
```console
$ cmd -v
version 1.0.0
$ cmd subcmd -v
subcmd version 2.0.0
$ cmd subcmd --version
version 1.0.0
```

## 5. Defining positional arguments
The positional arguments are remaining command-line arguments not consumed when parsing options and stored automatically in `$ZETOPT_ARGS` array.
```bash
zetopt "foo:f @ @ @"
zetopt parse "$@"
if [[ ${#ZETOPT_ARGS[@]} -ne 0 ]]; then
    echo "${ZETOPT_ARGS[*]}"
fi
```
```console
$ cmd -f A B C D E F
D E F
```

`@NAME` and `@URL` when defining a `remote add` sub-command are also positional arguments.
```bash
zetopt def "/remote/add/ @NAME @URL"
zetopt parse "$@"
if zetopt isok /remote/add/; then
    for arg in "${ZETOPT_ARGS[@]}"
    do
        echo "$arg"
    done
fi
```
```console
$ cmd remote add origin https://github.com/itmst71/zetopt.git
origin
https://github.com/itmst71/zetopt.git
```


Let's define positional arguments in `/` as required arguments and give names to be able to access values by names.  
`/` can be omitted.
```bash
zetopt def "/ @foo @bar %baz"
zetopt parse "$@"
if zetopt isok /; then
    echo $(zetopt val / foo bar baz)
    echo "${ZETOPT_ARGS[*]}"
fi
```
```console
$ cmd A B C D E F G
A B C
A B C D E F G
$ cmd
zetopt: Error: Missing Required Argument(s): 2 Argument(s) Required
```
