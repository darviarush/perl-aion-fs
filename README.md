# NAME

Aion::Fs - utilities for filesystem: read, write, find, replace files, etc

# VERSION

0.0.0-prealpha

# SYNOPSIS

```perl
use Aion::Fs;

lay mkpath "hello/world.txt", "hi!";
lay mkpath "hello/moon.txt", "noreplace";
lay mkpath "hello/big/world.txt", "hellow!";
lay mkpath "hello/small/world.txt", "noenter";

mtime "hello"  # ~> \d+

my @noreplaced = replace { s/h/${\ PATH} H/ }
    find "hello", "-f", "*.txt", qr/\.txt$/,
        noenter { PATH =~ wildcard "*small*" };

\@noreplaced # --> ["hello/moon.txt"]

cat "hello/world.txt"       # => hello/world.txt Hi!
cat "hello/moon.txt"        # => noreplace
cat "hello/big/world.txt"   # => hello/big/world.txt Hellow!
cat "hello/small/world.txt" # => noenter

scalar find "hello"  # -> 7

[find "hello", "*.txt"]  # --> [qw!  hello/moon.txt  hello/world.txt  hello/big/world.txt  hello/small/world.txt  !]
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
local $Aion::Fs::PATH = "path1";
{
    local $Aion::Fs::PATH = "path2";
    PATH  # => path2
}
PATH  # => path1
```

## cat ($file)

Read file. If file not specified, then use `PATH`.

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

* If `$file` not specified, then use `PATH`.
* If `$content` not specified, then use `$_`.
* `lay` using layer `:utf8`. For set layer using:

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

## erase (@paths)

Remove files and empty catalogs. Returns the `@paths`.

## noenter (&sub)

No enter to catalogs. Using in `find`.

## mkpath ($path)

As **mkdir -p**, but consider last path-part (after last slash) as filename, and not create this catalog.

* If `$path` not specified, then use `PATH`.
* If `$path` is array ref, then use path as first and permission as second element.
* Default permission is `0755`.
* Returns `$path`.

```perl
$Aion::Fs::PATH = ["A", 0755];
mkpath   # => A

eval { mkpath "/A/" }; $@   # ~> mkpath : No such file or directory
```

## mtime ($file)

Time modification the `$file` in unixtime.

Raise exeception if file not exists, or not permissions:

```perl
local $Aion::Fs::PATH = "nofile";
eval { mtime }; $@  # ~> mtime nofile: No such file or directory
```

## replace (&sub, @files)

Replacing each the file if `&sub` replace `$_`. Returns files in which there were no replacements.

`@files` can contain arrays of two elements. The first one is treated as a path, and the second one is treated as a layer. Default layer is `:utf8`.

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
local $Aion::Fs::PATH = "catonce.txt";
local $_ = "result";
lay;
catonce  # -> $_
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
wildcard "*.{pm,pl}"  # \> (?^us:^.*?\.(pm|pl)$)
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
```

Default the editor is `vscodium`.

# AUTHOR

Yaroslav O. Kosmina [dart@cpan.org](dart@cpan.org)

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

The Aion::Fs is copyright © 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.
