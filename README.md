!ru:en
# NAME

Aion::Fs - утилиты для файловой системы: чтение, запись, поиск, замена файлов и т.д.

# VERSION

0.0.6

# SYNOPSIS

```perl
use Aion::Fs;

lay mkpath "hello/world.txt", "hi!";
lay mkpath "hello/moon.txt", "noreplace";
lay mkpath "hello/big/world.txt", "hellow!";
lay mkpath "hello/small/world.txt", "noenter";

mtime "hello"  # ~> ^\d+(\.\d+)?$

[map cat, grep -f, find ["hello/big", "hello/small"]]  # --> [qw/ hellow! noenter /]

my @noreplaced = replace { s/h/$a $b H/ }
    find "hello", "-f", "*.txt", qr/\.txt$/, sub { /\.txt$/ },
        noenter "*small*",
            errorenter { warn "find $_: $!" };

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

Этот модуль облегчает использование файловой системы.

Модули `File::Path`, `File::Slurper` и
`File::Find` обременены различными возможностями, которые используются редко, но требуют времени на ознакомление и тем самым повышают порог входа.

В `Aion::Fs` же использован принцип программирования KISS - чем проще, тем лучше!

Супермодуль `IO::All` не является конкурентом `Aion::Fs`, т.к. использует ООП подход, а `Aion::Fs` – ФП.

* ООП — объектно-ориентированное программирование.
* ФП – функциональное программирование.

# SUBROUTINES/METHODS

## cat ($file)

Считывает файл. Если параметр не указан, использует `$_`.

```perl
cat "/etc/passwd"  # ~> root
```

`cat` читает со слоем `:utf8`. Но можно указать другой слой следующим образом:

```perl
lay "unicode.txt", "↯";
length cat "unicode.txt"            # -> 1
length cat["unicode.txt", ":raw"]   # -> 3
```

`cat` вызывает исключение в случае ошибки операции ввода-вывода:

```perl
eval { cat "A" }; $@  # ~> cat A: No such file or directory
```

**See also:**

* <File::Slurp> — `read_file('file.txt')`.
* <File::Slurper> — `read_text('file.txt')`, `read_binary('file.txt')`.
* <IO::All> — `io('file.txt') > $contents`.
* <IO::Util> — `$contents = ${ slurp 'file.txt' }`.
* <File::Util> — `File::Util->new->load_file(file => 'file.txt')`.

## lay ($file?, $content)

Записывает `$content` в `$file`.

* Если указан один параметр, использует `$_` вместо `$file`.
* `lay`, использует слой `:utf8`. Для указания иного слоя используется массив из двух элементов в параметре `$file`:

```perl
lay "unicode.txt", "↯"  # => unicode.txt
lay ["unicode.txt", ":raw"], "↯"  # => unicode.txt

eval { lay "/", "↯" }; $@ # ~> lay /: Is a directory
```

**See also:**

* <File::Slurp> — `write_file('file.txt', $contents)`.
* <File::Slurper> — `write_text('file.txt', $contents)`, `write_binary('file.txt', $contents)`.
* <IO::All> — `io('file.txt') < $contents`.
* <IO::Util> — `slurp \$contents, 'file.txt'`.
* <File::Util> — `File::Util->new->write_file(file => 'file.txt', content => $contents, bitmask => 0644)`.

## find (;$path, @filters)

Рекурсивно обходит и возвращает пути из указанного пути или путей, если `$path` является ссылкой на массив. Без параметров использует `$_` как `$path`.

Фильтры могут быть:

* Подпрограммой — путь к текущему файлу передаётся в `$_`, а подпрограмма должна вернуть истину или ложь, как они понимаются perl-ом.
* Regexp — тестирует каждый путь регулярным выражением.
* Строка в виде "-Xxx", где `Xxx` — один или несколько символов. Аналогична операторам perl-а для тестирования файлов. Пример: `-fr` проверяет путь файловыми тестировщиками [-f и -r](https://perldoc.perl.org/functions/-X).
* Остальные строки превращаются функцией `wildcard` (см. ниже) в регулярное выражение для проверки каждого пути.

Пути, не прошедшие проверку `@filters`, не возвращаются.

Если фильтр -X не является файловой функцией perl, то выбрасывается исключение:

```perl
eval { find "example", "-h" }; $@   # ~> Undefined subroutine &Aion::Fs::h called
```

В этом примере `find` не может войти в подкаталог и передаёт ошибку в функцию `errorenter` (см. ниже) с установленными переменными `$_` и `$!` (путём к каталогу и сообщением ОС об ошибке).

```perl
mkpath ["example/", 0];

[find "example"]    # --> ["example"]
[find "example", noenter "-d"]    # --> ["example"]

eval { find "example", errorenter { die "find $_: $!" } }; $@   # ~> find example: Permission denied
```

**See also:**

* <AudioFile::Find> — ищет аудиофайлы в указанной директории. Позволяет фильтровать их по атрибутам: названию, артисту, жанру, альбому и трэку.
* <Directory::Iterator> — `$it = Directory::Iterator->new($dir, %opts); push @paths, $_ while <$it>`.
* <IO::All> — `@paths = map { "$_" } grep { -f $_ && $_->size > 10*1024 } io(".")->all(0)`.
* <IO::All::Rule> — `$next = IO::All::Rule->new->file->size(">10k")->iter($dir1, $dir2); push @paths, "$f" while $f = $next->()`.
* <File::Find> — `find( sub { push @paths, $File::Find::name if /\.png/ }, $dir )`.
* <File::Find::utf8> — как <File::Find>, только пути файлов в _utf8_.
* <File::Find::Age> — сортирует файлы по времени модификации (наследует <File::Find::Rule>): `File::Find::Age->in($dir1, $dir2)`.
* <File::Find::Declare> — `@paths = File::Find::Declare->new({ size => '>10K', perms => 'wr-wr-wr-', modified => '<2010-01-30', recurse => 1, dirs => [$dir1] })->find`.
* <File::Find::Iterator> — имеет ООП интерфейс с итератором и функции `imap` и `igrep`.
* <File::Find::Match> — вызывает обработчик на каждый подошедший фильтр. Похож на `switch`.
* <File::Find::Node> — обходит иерархию файлов параллельно несколькими процессами: `tie @paths, IPC::Shareable, { key => "GLUE STRING", create => 1 }; File::Find::Node->new(".")->process(sub { my $f = shift; $f->fork(5); tied(@paths)->lock; push @paths, $f->path; tied(@paths)->unlock })->find; tied(@paths)->remove`.
* <File::Find::Fast> — `@paths = @{ find($dir) }`.
* <File::Find::Object> — имеет ООП интерфейс с итератором.
* <File::Find::Parallel> — умеет сравнивать два каталога и возвращать их объединение, пересечение и количественное пересечение.
* <File::Find::Random> — выбирает файл или директорию наугад из иерархии файлов.
* <File::Find::Rex> — `@paths = File::Find::Rex->new(recursive => 1, ignore_hidden => 1)->query($dir, qr/^b/i)`.
* <File::Find::Rule> — `@files = File::Find::Rule->any( File::Find::Rule->file->name('*.mp3', '*.ogg')->size('>2M'), File::Find::Rule->empty )->in($dir1, $dir2);`. Имеет итератор, процедурный интерфейс и расширения [::ImageSize](File::Find::Rule::ImageSize) и [::MMagic](File::Find::Rule::MMagic): `@images = find(file => magic => 'image/*', '!image_x' => '>20', in => '.')`.
* <File::Find::Wanted> — `@paths = find_wanted( sub { -f && /\.png/ }, $dir )`.
* <File::Hotfolder> — `watch( $dir, callback => sub { push @paths, shift } )->loop`. Работает на `AnyEvent`. Настраиваемый. Есть распараллеливание на несколько процессов.
* <File::Mirror> — формирует так же параллельный путь для копирования файлов: `recursive { my ($src, $dst) = @_; push @paths, $src } '/path/A', '/path/B'`.
* <File::Set> — `$fs = File::Set->new; $fs->add($dir); @paths = map { $_->[0] } $fs->get_path_list`.
* <File::Wildcard> — `$fw = File::Wildcard->new(exclude => qr/.svn/, case_insensitive => 1, sort => 1, path => "src///*.cpp", match => qr(^src/(.*?)\.cpp$), derive => ['src/$1.o','src/$1.hpp']); push @paths, $f while $f = $fw->next`.
* <File::Wildcard::Find> — `findbegin($dir); push @paths, $f while $f = findnext()` или  `findbegin($dir); @paths = findall()`.
* <File::Util> — `File::Util->new->list_dir($dir, qw/ --pattern=\.txt$ --files-only --recurse /)`.
* <Path::Find> — `@paths = path_find( $dir, "*.png" )`. Для сложных запросов использует _matchable_: `my $sub = matchable( sub { my( $entry, $directory, $fullname, $depth ) = @_; $depth <= 3 }`.
* <Path::Extended::Dir> — `@paths = Path::Extended::Dir->new($dir)->find('*.txt')`.
* <Path::Iterator::Rule> — `$i = Path::Iterator::Rule->new->file; @paths = $i->clone->size(">10k")->all(@dirs); $i->size("<10k")...`.
* <Path::Class::Each> — `dir($dir)->each(sub { push @paths, "$_" })`.
* <Path::Class::Iterator> — `$i = Path::Class::Iterator->new(root => $dir, depth => 2); until ($i->done) { push @paths, $i->next->stringify }`.
* <Path::Class::Rule> — `@paths = Path::Class::Rule->new->file->size(">10k")->all($dir)`.

## noenter (@filters)

Говорит `find` не входить в каталоги соответствующие фильтрам за ним.

## errorenter (&block)

Вызывает `&block` для каждой ошибки возникающей при невозможности войти в какой-либо каталог.

## erase (@paths)

Удаляет файлы и пустые каталоги. Возвращает `@paths`. При ошибке ввода-вывода выбрасывает исключение.

```perl
eval { erase "/" }; $@  # ~> erase dir /: Device or resource busy
eval { erase "/dev/null" }; $@  # ~> erase file /dev/null: Permission denied
```

**See also:**

* <unlink> + <rmdir>.
* <File::Path> — `remove_tree("dir")`.

## mkpath (;$path)

Как **mkdir -p**, но считает последнюю часть пути (после последней косой черты) именем файла и не создаёт её каталогом. Без параметра использует `$_`.

* Если `$path` не указан, использует `$_`.
* Если `$path` является ссылкой на массив, тогда используется путь в качестве первого элемента и права в качестве второго элемента.
* Права по умолчанию — `0755`.
* Возвращает `$path`.

```perl
local $_ = ["A", 0755];
mkpath   # => A

eval { mkpath "/A/" }; $@   # ~> mkpath /A: Permission denied

mkpath "A///./file";
-d "A"  # -> 1
```

**See also:**

* <File::Path> — `mkpath("dir1/dir2")`.

## mtime (;$file)

Время модификации `$file` в unixtime с дробной частью (из `Time::HiRes::stat`). Без параметра использует `$_`.

Выбрасывает исключение, если файл не существует или нет прав:

```perl
local $_ = "nofile";
eval { mtime }; $@  # ~> mtime nofile: No such file or directory

mtime ["/"]   # ~> ^\d+(\.\d+)?$
```

**See also:**

* <-M> — `-M "file.txt"`, `-M _` в днях от текущего времени.
* <stat> — `(stat "file.txt")[9]` в секундах (unixtime).
* <Time::HiRes> — `(Time::HiRes::stat "file.txt")[9]` в секундах с дробной частью.

## replace (&sub, @files)

Заменяет каждый файл на `$_`, если его изменяет `&sub`. Возвращает файлы, в которых не было замен.

`@files` может содержать массивы из двух элементов. Первый рассматривается как путь, а второй — как слой. Слой по умолчанию — `:utf8`.

`&sub` вызывается для каждого файла из `@files`. В неё передаются:

* `$_` — содержимое файла.
* `$a` — путь к файлу.
* `$b` — слой которым был считан файл и которым он будет записан.

В примере ниже файл "replace.ex" считывается слоем `:utf8`, а записывается слоем `:raw` в функции `replace`:

```perl
local $_ = "replace.ex";
lay "abc";
replace { $b = ":utf8"; y/a/¡/ } [$_, ":raw"];
cat  # => ¡bc
```

**See also:**

* <File::Edit>.
* <File::Edit::Portable>.
* <File::Replace>.
* <File::Replace::Inplace>.

## include (;$pkg)

Подключает `$pkg` (если он ещё не был подключён через `use` или `require`) и возвращает его. Без параметра использует `$_`.

Файл lib/A.pm:
```perl
package A;
sub new { bless {@_}, shift }
1;
```

Файл lib/N.pm:
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

## catonce (;$file)

Считывает файл в первый раз. Любая последующая попытка считать этот файл возвращает `undef`. Используется для вставки модулей js и css в результирующий файл. Без параметра использует `$_`.

* `$file` может содержать массивы из двух элементов. Первый рассматривается как путь, а второй — как слой. Слой по умолчанию — `:utf8`.
* Если `$file` не указан – использует `$_`.

```perl
local $_ = "catonce.txt";
lay "result";
catonce  # -> "result"
catonce  # -> undef

eval { catonce[] }; $@ # ~> catonce not use ref path!
```

## wildcard (;$wildcard)

Переводит файловую маску в регулярное выражение. Без параметра использует `$_`.

* `**` - `[^/]*`
* `*` - `.*`
* `?` - `.`
* `??` - `[^/]`
* `{` - `(`
* `}` - `)`
* `,` - `|`
* Остальные символы экранируются с помощью `quotemeta`.

```perl
wildcard "*.{pm,pl}"  # \> (?^usn:^.*?\.(pm|pl)$)
wildcard "?_??_**"  # \> (?^usn:^._[^/]_[^/]*?$)
```

Используется в фильтрах функции `find`.

**See also:**

* <File::Wildcard>.
* <String::Wildcard::Bash>.
* <Text::Glob> — `glob_to_regex("*.{pm,pl}")`.

## goto_editor ($path, $line)

Открывает файл в редакторе из .config на указанной строке. По умолчанию использует `vscodium %p:%l`.

Файл .config.pm:
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

## from_pkg (;$pkg)

Переводит пакет в путь ФС. Без параметра использует `$_`.

```perl
from_pkg "Aion::Fs"  # => Aion/Fs.pm
[map from_pkg, "Aion::Fs", "A::B::C"]  # --> ["Aion/Fs.pm", "A/B/C.pm"]
```

## to_pkg (;$path)

Переводит путь из ФС в пакет. Без параметра использует `$_`.

```perl
to_pkg "Aion/Fs.pm"  # => Aion::Fs
[map to_pkg, "Aion/Fs.md", "A/B/C.md"]  # --> ["Aion::Fs", "A::B::C"]
```

# AUTHOR

Yaroslav O. Kosmina <dart@cpan.org>

# LICENSE

⚖ **GPLv3**

# COPYRIGHT

The Aion::Fs is copyright © 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.
