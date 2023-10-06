use common::sense; use open qw/:std :utf8/; use Test::More 0.98; sub _mkpath_ { my ($p) = @_; length($`) && !-e $`? mkdir($`, 0755) || die "mkdir $`: $!": () while $p =~ m!/!g; $p } BEGIN { use Scalar::Util qw//; use Carp qw//; $SIG{__DIE__} = sub { my ($s) = @_; if(ref $s) { $s->{STACKTRACE} = Carp::longmess "?" if "HASH" eq Scalar::Util::reftype $s; die $s } else {die Carp::longmess defined($s)? $s: "undef" }}; my $t = `pwd`; chop $t; $t .= '/' . __FILE__; my $s = '/tmp/.liveman/perl-aion-fs!aion!fs/'; `rm -fr '$s'` if -e $s; chdir _mkpath_($s) or die "chdir $s: $!"; open my $__f__, "<:utf8", $t or die "Read $t: $!"; read $__f__, $s, -s $__f__; close $__f__; while($s =~ /^#\@> (.*)\n((#>> .*\n)*)#\@< EOF\n/gm) { my ($file, $code) = ($1, $2); $code =~ s/^#>> //mg; open my $__f__, ">:utf8", _mkpath_($file) or die "Write $file: $!"; print $__f__ $code; close $__f__; } } # # NAME
# 
# Aion::Fs - utilities for filesystem: read, write, find, replace files, etc
# 
# # VERSION
# 
# 0.0.0-prealpha
# 
# # SYNOPSIS
# 
subtest 'SYNOPSIS' => sub { 
use Aion::Fs;

lay mkpath "hello/world.txt", "hi!";
lay mkpath "hello/moon.txt", "noreplace";
lay mkpath "hello/big/world.txt", "hellow!";
lay mkpath "hello/small/world.txt", "noenter";

::like scalar do {mtime "hello"}, qr!\d+!, 'mtime "hello"  # ~> \d+';

my @noreplaced = replace { s/h/${\ PATH} H/ }
    find "hello", "-f", "*.txt", qr/\.txt$/,
        noenter { PATH =~ wildcard "*small*" };

::is_deeply scalar do {\@noreplaced}, scalar do {["hello/moon.txt"]}, '\@noreplaced # --> ["hello/moon.txt"]';

::is scalar do {cat "hello/world.txt"}, "hello/world.txt Hi!", 'cat "hello/world.txt"       # => hello/world.txt Hi!';
::is scalar do {cat "hello/moon.txt"}, "noreplace", 'cat "hello/moon.txt"        # => noreplace';
::is scalar do {cat "hello/big/world.txt"}, "hello/big/world.txt Hellow!", 'cat "hello/big/world.txt"   # => hello/big/world.txt Hellow!';
::is scalar do {cat "hello/small/world.txt"}, "noenter", 'cat "hello/small/world.txt" # => noenter';

::is scalar do {scalar find ["hello/big", "hello/small"]}, scalar do{4}, 'scalar find ["hello/big", "hello/small"]  # -> 4';

::is_deeply scalar do {[find "hello", "*.txt"]}, scalar do {[qw!  hello/moon.txt  hello/world.txt  hello/big/world.txt  hello/small/world.txt  !]}, '[find "hello", "*.txt"]  # --> [qw!  hello/moon.txt  hello/world.txt  hello/big/world.txt  hello/small/world.txt  !]';
::is_deeply scalar do {[find "hello", "-d"]}, scalar do {[qw!  hello  hello/big hello/small  !]}, '[find "hello", "-d"]  # --> [qw!  hello  hello/big hello/small  !]';

erase reverse find "hello";

::is scalar do {-e "hello"}, scalar do{undef}, '-e "hello"  # -> undef';

# 
# # DESCRIPTION
# 
# This module provide light entering to filesystem.
# 
# Modules File::Path, File::Slurper and
# File::Find are quite weighted with various features that are rarely used, but take time to get acquainted and, thereby, increases the entry threshold.
# 
# In Aion::Fs used the programming principle KISS - Keep It Simple, Stupid.
# 
# # SUBROUTINES/METHODS
# 
# ## PATH ()
# 
# The current path in `replace` and `noenter` blocks. It use if not specified in `mkpath`, `mtime`, `cat`, `lay`, etc.
# 
# It is modifiable:
# 
done_testing; }; subtest 'PATH ()' => sub { 
local $Aion::Fs::PATH = "path1";
{
    local $Aion::Fs::PATH = "path2";
::is scalar do {PATH}, "path2", '    PATH  # => path2';
}
::is scalar do {PATH}, "path1", 'PATH  # => path1';

# 
# ## cat ($file)
# 
# Read file. If file not specified, then use `PATH`.
# 
done_testing; }; subtest 'cat ($file)' => sub { 
::like scalar do {cat "/etc/passwd"}, qr!root!, 'cat "/etc/passwd"  # ~> root';

# 
# `cat` read with layer `:utf8`. But you can set the level like this:
# 

lay "unicode.txt", "↯";
::is scalar do {length cat "unicode.txt"}, scalar do{1}, 'length cat "unicode.txt"            # -> 1';
::is scalar do {length cat["unicode.txt", ":raw"]}, scalar do{3}, 'length cat["unicode.txt", ":raw"]   # -> 3';

# 
# `cat` raise exception by error on io operation:
# 

::like scalar do {eval { cat "A" }; $@}, qr!cat A: No such file or directory!, 'eval { cat "A" }; $@  # ~> cat A: No such file or directory';

# 
# ## lay ($file, $content)
# 
# Write `$content` in `$file`.
# 
# * If `$file` not specified, then use `PATH`.
# * If `$content` not specified, then use `$_`.
# * `lay` using layer `:utf8`. For set layer using:
# 
done_testing; }; subtest 'lay ($file, $content)' => sub { 
::is scalar do {lay "unicode.txt", "↯"}, "unicode.txt", 'lay "unicode.txt", "↯"  # => unicode.txt';
::is scalar do {lay ["unicode.txt", ":raw"], "↯"}, "unicode.txt", 'lay ["unicode.txt", ":raw"], "↯"  # => unicode.txt';

::like scalar do {eval { lay "/", "↯" }; $@}, qr!lay /: Is a directory!, 'eval { lay "/", "↯" }; $@ # ~> lay /: Is a directory';

# 
# ## find ($path, @filters)
# 
# Finded files and returns array paths from start path or paths if `$path` is array ref.
# 
# Filters may be:
# 
# * Subroutine - the each path fits to `$_` and test with subroutine.
# * Regexp - test the each path on the regexp.
# * String as "-Xxx", where `Xxx` - one or more symbols. Test on the perl file testers. Example "-fr" test the path on `-f` and `-r` file testers.
# * Any string interpret function `wildcard` to regexp and the each path test on it.
# 
# The paths that have not passed testing by `@filters` are not returned.
# 
# If filter -X is unused, then throw exception:
# 
done_testing; }; subtest 'find ($path, @filters)' => sub { 
::like scalar do {eval { find "example", "-h" }; $@}, qr!Undefined subroutine &Aion::Fs::h called!, 'eval { find "example", "-h" }; $@   # ~> Undefined subroutine &Aion::Fs::h called';

# 
# ## erase (@paths)
# 
# Remove files and empty catalogs. Returns the `@paths`.
# 
# ## noenter (&sub)
# 
# No enter to catalogs. Using in `find`.
# 
# ## mkpath ($path)
# 
# As **mkdir -p**, but consider last path-part (after last slash) as filename, and not create this catalog.
# 
# * If `$path` not specified, then use `PATH`.
# * If `$path` is array ref, then use path as first and permission as second element.
# * Default permission is `0755`.
# * Returns `$path`.
# 
done_testing; }; subtest 'mkpath ($path)' => sub { 
$Aion::Fs::PATH = ["A", 0755];
::is scalar do {mkpath}, "A", 'mkpath   # => A';

::like scalar do {eval { mkpath "/A/" }; $@}, qr!mkpath : No such file or directory!, 'eval { mkpath "/A/" }; $@   # ~> mkpath : No such file or directory';

# 
# ## mtime ($file)
# 
# Time modification the `$file` in unixtime.
# 
# Raise exeception if file not exists, or not permissions:
# 
done_testing; }; subtest 'mtime ($file)' => sub { 
local $Aion::Fs::PATH = "nofile";
::like scalar do {eval { mtime }; $@}, qr!mtime nofile: No such file or directory!, 'eval { mtime }; $@  # ~> mtime nofile: No such file or directory';

# 
# ## replace (&sub, @files)
# 
# Replacing each the file if `&sub` replace `$_`. Returns files in which there were no replacements.
# 
# `@files` can contain arrays of two elements. The first one is treated as a path, and the second one is treated as a layer. Default layer is `:utf8`.
# 
# ## include ($pkg)
# 
# Require `$pkg` and returns it.
# 
# File lib/A.pm:
#@> lib/A.pm
#>> package A;
#>> sub new { bless {@_}, shift }
#>> 1;
#@< EOF
# 
# File lib/N.pm:
#@> lib/N.pm
#>> package N;
#>> sub ex { 123 }
#>> 1;
#@< EOF
# 
done_testing; }; subtest 'include ($pkg)' => sub { 
use lib "lib";
::like scalar do {include("A")->new}, qr!A=HASH\(0x\w+\)!, 'include("A")->new               # ~> A=HASH\(0x\w+\)';
::is_deeply scalar do {[map include, qw/A N/]}, scalar do {[qw/A N/]}, '[map include, qw/A N/]          # --> [qw/A N/]';
::is scalar do {{ local $_="N"; include->ex }}, scalar do{123}, '{ local $_="N"; include->ex }   # -> 123';

# 
# ## catonce ($file)
# 
# Read the file in first call with this file. Any call with this file return `undef`. Using for insert js and css modules in the resulting file.
# 
done_testing; }; subtest 'catonce ($file)' => sub { 
local $Aion::Fs::PATH = "catonce.txt";
local $_ = "result";
lay;
::is scalar do {catonce}, scalar do{$_}, 'catonce  # -> $_';
::is scalar do {catonce}, scalar do{undef}, 'catonce  # -> undef';

::like scalar do {eval { catonce[] }; $@}, qr!catonce not use ref path\!!, 'eval { catonce[] }; $@ # ~> catonce not use ref path!';

# 
# ## wildcard ($wildcard)
# 
# Translate the wildcard to regexp.
# 
# * `**` - `[^/]*`
# * `*` - `.*`
# * `?` - `.`
# * `??` - `[^/]`
# * `{` - `(`
# * `}` - `)`
# * `,` - `|`
# * Any symbols translate by `quotemeta`.
# 
done_testing; }; subtest 'wildcard ($wildcard)' => sub { 
::is scalar do {wildcard "*.{pm,pl}"}, '(?^us:^.*?\.(pm|pl)$)', 'wildcard "*.{pm,pl}"  # \> (?^us:^.*?\.(pm|pl)$)';

# 
# Using in filters the function `find`.
# 
# ## goto_editor ($path, $line)
# 
# Open the file in editor from config on the line.
# 
# File .config.pm:
#@> .config.pm
#>> package config;
#>> 
#>> config_module 'Aion::Fs' => {
#>>     EDITOR => 'echo %p:%l > ed.txt',
#>> };
#>> 
#>> 1;
#@< EOF
# 
done_testing; }; subtest 'goto_editor ($path, $line)' => sub { 
goto_editor "mypath", 10;
::is scalar do {cat "ed.txt"}, "mypath:10\n", 'cat "ed.txt"  # => mypath:10\n';

# 
# Default the editor is `vscodium`.
# 
# # AUTHOR
# 
# Yaroslav O. Kosmina [dart@cpan.org](dart@cpan.org)
# 
# # LICENSE
# 
# ⚖ **GPLv3**
# 
# # COPYRIGHT
# 
# The Aion::Fs is copyright © 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.

	done_testing;
};

done_testing;
