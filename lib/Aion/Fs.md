# NAME

Aion::Fs - utilities for filesystem: read, write, find, replace files, etc

# VERSION

0.0.0-prealpha

# SYNOPSIS

```perl
use Aion::Fs;

lay mkpath "hello/world.txt", "hi!";
lay mkpath "hello/big/world.txt", "hellow!";

my $count = replace { s/h/${\ PATH} H/ }
    find "hello", "-f", "**.txt",
        noenter { PATH =~ wildcard "*small*" };

$count # -> 2

cat "hello/world.txt"       # => hello/world.txt Hi!
cat "hello/big/world.txt"   # => hello/big/world.txt Hellow!

scalar find "hello"  # -> 4

[find "hello", "*.txt"]  # -> [qw!  hello/world.txt  hello/big/world.txt  !]
[find "hello", "-d"]  # -> [qw!  hello  hello/big  !]

erase reverse find "hello";
```

# DESCRIPTION



# SUBROUTINES/METHODS

## PATH ()

.

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->PATH  # -> .3
```

## cat ($file)

{use open IN => ':raw'; cat }

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->cat($file)  # -> .3
```

## lay ($file, $content)

{use open OUT => ':raw'; lay $path }

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->lay($file, $s)  # -> .3
```

## find ()

Найти файлы

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->find  # -> .3
```

## erase ()

Стирает все указанные файлы. Возвращает переданные файлы

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->erase  # -> .3
```

## noenter ()

Не входить в подкаталоги

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->noenter  # -> .3
```


## mkpath ($path, $mode)

как mkdir -p

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->mkpath($path, $mode)  # -> .3
```

## mtime ($file)

Вернуть время модификации файла

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->mtime  # -> .3
```

## replace (&sub, @files)

Производит замену во всех указанных файлах. Возвращает количество файлов в которых были замены

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->replace  # -> .3
```

## include ($pkg)

Подключает модуль, если он ещё не подключён, и возвращает его

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->include($pkg)  # -> .3
```

## require_file ($file)

.

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->require_file($file)  # -> .3
```

## wildcard ($wildcard)

Переводит вилдкард в регулярку

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->wildcard($wildcard)  # -> .3
```

## goto_editor ($path, $line)

.

```perl
my $aion_fs = Aion::Fs->new;
$aion_fs->goto_editor($path, $line)  # -> .3
```

# AUTHOR

Yaroslav O. Kosmina [dart@cpan.org](mailto:dart@cpan.org)

# LICENSE

⚖ **GPLv3**

# COPYRIGHT
The Aion::Fs is copyright © 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.
