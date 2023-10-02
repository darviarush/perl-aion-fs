# NAME

Aion::Fs - utilities for filesystem: read, write, find, replace files, etc

# VERSION

0.0.0-prealpha

# SYNOPSIS

```perl
use Aion::Fs;

lay mkpath "hello/world.txt", "hi!";
lay mkpath "hello/big/world.txt", "hellow!";
lay mkpath "hello/small/world.txt", "hellow!";


my @noreplaced = replace { s/h/${\ PATH} H/ }
    find "hello", "-f", "**.txt",
        noenter { PATH =~ wildcard "*small*" };

\@noreplaced # --> ["hello/small/world.txt"]

cat "hello/world.txt"       # => hello/world.txt Hi!
cat "hello/big/world.txt"   # => hello/big/world.txt Hellow!
cat "hello/small/world.txt" # => hellow!

scalar find "hello"  # -> 6

[find "hello", "*.txt"]  # --> [qw!  hello/world.txt  hello/big/world.txt  hello/small/world.txt  !]
[find "hello", "-d"]  # --> [qw!  hello  hello/big hello/small  !]

erase reverse find "hello";

-e "hello"  # -> undef
```

# DESCRIPTION

This module provide light entering to filesystem.

Modules File::Path, File::Slurper and
File::Find are quite weighted with various features that are rarely used, but take time to get acquainted and, thereby, increases the entry threshold.

In Aion::Fs used the programming principle KISS - Keep It Simple, Stupid.

# SUBROUTINES/METHODS

## PATH ()

The current path in `replace` and `noenter` blocks. It use if not specified in `mkpath`, `mtime`, `cat`, `lay`, etc.

It is modifiable:

```perl
local PATH = "path1";
{
    local PATH = "path2";
    PATH  # => path2
}
PATH  # => path1
```

## cat ($file)

Read file. If file not specified, then use `PATH`.

```perl
cat "/etc/passwd"  # ~> root
```

`cat` using std-layers from `use open qw/:std/`. Example, if set layer `:utf8`, bat file need read in binary, then use `cat` in block with `:raw` std-layer:

```perl
lay "unicode.txt", "↯";
length cat "unicode.txt"    # -> 1
{use open IN => ':raw';
    length cat "unicode.txt"    # -> 2
}
```

## lay ($file, $content)

Write `$content` in `$file`.

* If `$file` not specified, then use `PATH`.
* If `$content` not specified, then use `$_`.
* `cat` using std-layers from `use open qw/:std/`. For set layer using `{use open OUT => ':raw'; lay $path }`.

## find ($path, @filters)

Finded files and returns array paths from start path or paths if `$path` is array ref.

Filters may be:

* Subroutine - the each path fits to `$_` and test with subroutine.
* Regexp - test the each path on the regexp.
* String as "-Xxx", where `Xxx` - one or more symbols. Test on the perl file testers. Example "-fr" test the path on `-f` and `-r` file testers.
* Any string interpret function `wildcard` to regexp and the each path test on it.

The paths that have not passed testing by `@filters` are not returned.

## erase (@paths)

Remove files and empty catalogs. Returns the `@paths`.

## noenter (&sub)

No enter to catalogs. Using in `find`.

## mkpath ($path, $mode)

As **mkdir -p**, but consider last path-part (after last slash) as filename, and not create this catalog.

* If `$path` not specified, then use `PATH`.
* If `$mode` not specified, then use permission `0755`.
* Returns `$path`.

## mtime ($file)

Time modification the `$file` in unixtime.

## replace (&sub, @files)

Replacing each the file if `&sub` replace `$_`. Returns files in which there were no replacements.

## include ($pkg)

Require `$pkg` and returns it.

File lib/A.pm:
```perl
package A;
sub new { bless {@_}, shift }
1;
```

```perl
include("A")->new  # ~> A=HASH\(0x\w+\)
```

## catonce ($file)

Read the file in first call with this file. Any call with this file return `undef`. Using for insert js and css modules in the resulting file.

```perl
local PATH = "catonce.txt";
local $_ = "result";
lay;
catonce  # -> $_
catonce  # -> undef
```

## wildcard ($wildcard)

Translate the wildcard to regexp.

* `**` - `[^/]*`
* `*` - `.*`
* `?` - `.`
* `??` - `[^/]`
* `{` - `(`
* `}` - `)`
* `,` - `|`
* Any symbols translate by `quotemeta`.

```perl
wildcard "*.[pm,pl]"  # \> ^.*\.(pm|pl)$
```

Using in filters the function `find`.

## goto_editor ($path, $line)

Open the file in editor from config on the line.

File .config.pm:
```perl
package config;

config_module 'Aion::Fs' => {
    EDITOR => 'echo %f:%l > ed.txt',
};

1;
```

```perl
goto_editor "mypath", 10;
cat "ed.txt"  # => mypath:10\n
```

Default the editor is `vscodium`.

# AUTHOR

Yaroslav O. Kosmina [dart@cpan.org](dart@cpan.org)

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

The Aion::Fs is copyright © 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.
