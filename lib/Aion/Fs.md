# NAME

Aion::Fs - utilities for filesystem: read, write, find, replace files, etc

# VERSION

0.0.1

# SYNOPSIS

```perl
use Aion::Fs;

lay mkpath "hello/world.txt", "hi!";
lay mkpath "hello/moon.txt", "noreplace";
lay mkpath "hello/big/world.txt", "hellow!";
lay mkpath "hello/small/world.txt", "noenter";

mtime "hello"  # ~> ^\d+$

[map cat, grep -f, find ["hello/big", "hello/small"]]  # --> [qw/ hellow! noenter /]

my @noreplaced = replace { s/h/$a $b H/ }
    find "hello", "-f", "*.txt", qr/\.txt$/, sub { /\.txt$/ },
        noenter "*small*",
            errorenter { die "find $_: $!" };

\@noreplaced # --> ["hello/moon.txt"]

cat "hello/world.txt"       # => hello/world.txt :utf8 Hi!
cat "hello/moon.txt"        # => noreplace
cat "hello/big/world.txt"   # => hello/big/world.txt :utf8 Hellow!
cat "hello/small/world.txt" # => noenter

[find "hello", "*.txt"]  # --> [qw!  hello/moon.txt  hello/world.txt  hello/big/world.txt  hello/small/world.txt  !]
[find "hello", "-d"]  # --> [qw!  hello  hello/big hello/small  !]

erase reverse find "hello";

-e "hello"  # -> undef
```

# DESCRIPTION

This module provide light entering to filesystem.

Modules `File::Path`, `File::Slurper` and
`File::Find` are quite weighted with various features that are rarely used, but take time to get acquainted and, thereby, increases the entry threshold.

In `Aion::Fs` used the programming principle KISS - Keep It Simple, Stupid.

Supermodule `IO::All` provide OOP, and `Aion::Fs` provide FP.

* OOP - object oriented programming.
* FP - functional programming.

# SUBROUTINES/METHODS

## cat ($file)

Read file. If file not specified, then use `$_`.

```perl
cat "/etc/passwd"  # ~> root
```

`cat` read with layer `:utf8`. But you can set the level like this:

```perl
lay "unicode.txt", "↯";
length cat "unicode.txt"            # -> 1
length cat["unicode.txt", ":raw"]   # -> 3
```

`cat` raise exception by error on io operation:

```perl
eval { cat "A" }; $@  # ~> cat A: No such file or directory
```

## lay ($file, $content)

Write `$content` in `$file`.

* If one parameter specified, then use `$_` as `$file`.
* `lay` using layer `:utf8`. For set layer using two elements array for `$file`:

```perl
lay "unicode.txt", "↯"  # => unicode.txt
lay ["unicode.txt", ":raw"], "↯"  # => unicode.txt

eval { lay "/", "↯" }; $@ # ~> lay /: Is a directory
```

## find ($path, @filters)

Finded files and returns array paths from start path or paths if `$path` is array ref.

Filters may be:

* Subroutine - the each path fits to `$_` and test with subroutine.
* Regexp - test the each path on the regexp.
* String as "-Xxx", where `Xxx` - one or more symbols. Test on the perl file testers. Example "-fr" test the path on `-f` and `-r` file testers.
* Any string interpret function `wildcard` to regexp and the each path test on it.

The paths that have not passed testing by `@filters` are not returned.

If filter -X is unused, then throw exception:

```perl
eval { find "example", "-h" }; $@   # ~> Undefined subroutine &Aion::Fs::h called
```

If `find` is impossible to enter the subdirectory, then call errorenter with set variable `$_` and `$!`.

```perl
mkpath ["example/", 0];

[find "example"]    # --> ["example"]
[find "example", noenter "-d"]    # --> ["example"]

eval { find "example", errorenter { die "find $_: $!" } }; $@   # ~> find example: Permission denied
```

## noenter (@filters)

No enter to catalogs. Using in `find`. `@filters` same as in `find`.

## errorenter (&block)

Call `&block` for each error on open catalog.

## erase (@paths)

Remove files and empty catalogs. Returns the `@paths`.

```perl
eval { erase "/" }; $@  # ~> erase dir /: Device or resource busy
eval { erase "/dev/null" }; $@  # ~> erase file /dev/null: Permission denied
```

## mkpath ($path)

As **mkdir -p**, but consider last path-part (after last slash) as filename, and not create this catalog.

* If `$path` not specified, then use `PATH`.
* If `$path` is array ref, then use path as first and permission as second element.
* Default permission is `0755`.
* Returns `$path`.
cpanm --local-lib=~/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
```perl
local $_ = ["A", 0755];
mkpath   # => A

eval { mkpath "/A/" }; $@   # ~> mkpath : No such file or directory
```

## mtime ($file)

Time modification the `$file` in unixtime.

Raise exeception if file not exists, or not permissions:

```perl
local $_ = "nofile";
eval { mtime }; $@  # ~> mtime nofile: No such file or directory

mtime ["/"]   # ~> ^\d+$
```

## replace (&sub, @files)

Replacing each the file if `&sub` replace `$_`. Returns files in which there were no replacements.

`@files` can contain arrays of two elements. The first one is treated as a path, and the second one is treated as a layer. Default layer is `:utf8`.

```perl
local $_ = "replace.ex";
lay "abc";
replace { $b = ":utf8"; y/a/¡/ } [$_, ":raw"];
cat  # => ¡bc
```

## include ($pkg)

Require `$pkg` and returns it.

File lib/A.pm:
```perl
package A;
sub new { bless {@_}, shift }
1;
```

File lib/N.pm:
```perl
package N;
sub ex { 123 }
1;
```

```perl
use lib "lib";
include("A")->new               # ~> A=HASH\(0x\w+\)
[map include, qw/A N/]          # --> [qw/A N/]
{ local $_="N"; include->ex }   # -> 123
```

## catonce ($file)

Read the file in first call with this file. Any call with this file return `undef`. Using for insert js and css modules in the resulting file.

```perl
local $_ = "catonce.txt";
lay "result";
catonce  # -> "result"
catonce  # -> undef

eval { catonce[] }; $@ # ~> catonce not use ref path!
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
wildcard "*.{pm,pl}"  # \> (?^usn:^.*?\.(pm|pl)$)
wildcard "?_??_**"  # \> (?^usn:^._[^/]_[^/]*?$)
```

Using in filters the function `find`.

## goto_editor ($path, $line)

Open the file in editor from config on the line.

File .config.pm:
```perl
package config;

config_module 'Aion::Fs' => {
    EDITOR => 'echo %p:%l > ed.txt',
};

1;
```

```perl
goto_editor "mypath", 10;
cat "ed.txt"  # => mypath:10\n

eval { goto_editor "`", 1 }; $@  # ~> `:1 --> 512
```

Default the editor is `vscodium`.

# AUTHOR

Yaroslav O. Kosmina [dart@cpan.org](dart@cpan.org)

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

The Aion::Fs is copyright © 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.
