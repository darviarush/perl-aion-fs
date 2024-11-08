package Aion::Fs;
use 5.22.0;
no strict; no warnings; no diagnostics;
use common::sense;

our $VERSION = "0.0.8";

use Exporter qw/import/;
use File::Spec     qw//;
use Scalar::Util   qw//;
use List::Util     qw//;
use Time::HiRes    qw//;

our @EXPORT = our @EXPORT_OK = grep {
	ref \$Aion::Fs::{$_} eq "GLOB" && *{$Aion::Fs::{$_}}{CODE} && !/^(?:_|(NaN|import)\z)/
} keys %Aion::Fs::;


# Список ОС с различающимся синтаксисом файловых путей (должен быть в нижнем регистре)
use constant {
	UNIX    => 'unix',
	AMIGAOS => 'amigaos',
	CYGWIN  => 'cygwin',
	MSYS    => 'msys',
	MSYS2   => 'msys2',
	MSWIN32 => 'mswin32',
	DOS     => 'dos',
	OS2     => 'os2',
	SYMBIAN => 'symbian',
	VMS     => 'vms',
	VOS     => 'vos',
	RISCOS  => 'riscos',
	MACOS   => 'macos',
	VMESA   => 'vmesa',
};

sub _fs();
sub _match($$) {
	my ($match, $fs) = @_;
	my @res; my @remove;
	my $trans = $fs->{before_split} // sub {$_[0]};
	for my $key (@$match) {
		next unless exists $_->{$key};
		
		push @remove, $key unless defined $_->{$key};
		
		my $regexp = ($key eq "path"? $fs->{regexp}: $fs->{group}{$key});
		my $val = $trans->($_->{$key});
		push @res, $val =~ $regexp
			? %+
			: die "`$key` is in the wrong format `$val`. Has been used regexp: $regexp";
	}

	my %res = @res;
	delete @res{keys %{$fs->{remove}->{$_}}} for @remove;
	
	return %res, %$_;
}

sub _join(@) {
	my ($match, @format) = @_;
	my $fs = _fs;
	my $trans = $fs->{before_split} // sub {$_[0]};
	my %f = _match $match, $fs;
	join "", List::Util::pairmap {
		my @keys = ref $a? @$a: $a;
		my $is = List::Util::first {defined $f{$_}} @keys;
		defined $is? do {
			my ($if, $format) = ref $b? @$b: (undef, $b);
			
			my @val = map $trans->($f{$_}), @keys;
			defined $if && $val[0] eq $if? $if:
				$format !~ /%s/? $format:
					sprintf($format, @val)
		}: () 
	} @format
}

# Синтаксисы файловых путей в разных ОС
my %FS;
my @FS = (
	{
		name   => UNIX,
		symdir => '/',
		symext => '.',
		regexp => qr!^
			(
				(?<dir> / ) | (?<dir> .* ) /
			)?
			(?<file>
				(?<name> \.? [^/.]* )
				( \. (?<ext> [^/]* ) )?
			)
		\z!xsn,
		join => sub {
			_join [qw/path file/],
				dir    => ["/", "%s/"],
				name   => "%s",
				ext    => ".%s",
		},
	},
	{
		name   => AMIGAOS,
		symdir => '/',
		symext => '.',
		regexp => qr!^
			(?<dir>
				( (?<volume> [^/:]+) : )?
				(?<folder> .* ) /
			)?
			(?<file>
				(?<name> \.? [^/.]* )
				( \. (?<ext> [^/]* ) )?
			)
		\z!xsn,
		join => sub {
			_join [qw/path dir file/],
				volume => "%s:",
				folder => "%s/",
				name   => "%s",
				ext    => ".%s",
		},
	},
	{
		name   => CYGWIN,
		symdir => '/',
		symext => '.',
		regexp => qr!^
			(?<dir>
				( /cygdrive/ (?<volume> [^/]+ ) /? )?
				( (?<folder> .* ) / )?
			)
			(?<file>
				(?<name> \.? [^/.]* )
				( \. (?<ext> [^/]* ) )?
			)
		\z!xsn,
		join => sub {
			_join [qw/path dir file/],
				volume => "/cygdrive/%s/",
				folder => "%s/",
				name   => "%s",
				ext    => ".%s",
		},
	},
	{
		name   => [MSYS, MSYS2],
		symdir => '/',
		symext => '.',
		regexp => qr!^
			(?<dir>
				( / (?<volume> [^/]+ )? /? )
				( (?<folder> .* ) / )?
			)?
			(?<file>
				(?<name> \.? [^/.]* )
				( \. (?<ext> [^/]* ) )?
			)
		\z!xsn,
		join => sub {
			_join [qw/path dir file/],
				volume => "/%s/",
				folder => "%s/",
				name   => "%s",
				ext    => ".%s",
		},
	},
	{
		name   => [DOS, OS2, MSWIN32, SYMBIAN],
		symdir => '\\',
		symext => '.',
		before_split => sub { $_[0] =~ s!/!\\!gr },
		regexp => qr!^
			(?<dir>
				( (?<volume> [^\\:]+) : | \\\\ (?<server> [^\\]+ )? )?
				( (?<folder> \\ ) | (?<folder> .* ) \\ )?
			)
			(?<file>
				(?<name> \.? [^\\.]* )
				( \. (?<ext> [^\\]* ) )?
			)
		\z!xsn,
		join => sub {
			_join [qw/path dir file/],
				volume => "%s:",
				server => "\\\\%s",
				folder => ["\\", "%s\\"],
				name   => "%s",
				ext    => ".%s",
		},
	},
	{
		name   => VMS,
		symdir => '.',
		symext => '.',
		regexp => qr!^
			(?<dir>
				( 
					(?<node> [^:\[\]]* )
					( \[" (?<accountname> [^\s:\[\]]+ ) \s+ (?<password> [^\s:\[\]]+ ) "\] )?
				:: )?
				(?<volume>
						(?<disk> [^\$:\[\]]* )
						( \$ (?<user> [^\$:\[\]]* ) )?
					: )?
				( \[ (?<folder> [^\[\]]* ) \] )?
			)
			(?<card>
			    (?<file>
					(?<name> \.? [^.;\[\]]*? )
					( \. (?<ext> [^;\[\]]* ) )?
				)
				( ; (?<version> [^;\[\]]* ) )?
			)
		\z!xsn,
		join => sub {
			_join [qw/path dir volume file/],
				node            => "%s",
				[qw/accountname password/] => '["%s %s"]',
				[qw/node accountname password/] => "::",
				disk            => "%s",
				user            => "\$%s",
				[qw/disk user/] => ':',
				folder          => "[%s]",
				name            => "%s",
				ext             => ".%s",
				version         => ";%s",
		},
	},
	{
		name   => VOS,
		symdir => '>',
		symext => '.',
		regexp => qr!^
			(?<dir>
				(?<volume>
					% (?<sysname> [^>\#]* ) \# (?<module> [^>\#]* ) >
				)?
				( (?<folder> .* ) > )?
			)
			(?<file>
				(?<name> \.? [^.]*? )
				( \. (?<ext> .* ) )?
			)
		\z!xsn,
		join => sub {
			_join [qw/path dir volume file/],
				[qw/sysname module/] => "%%%s#%s>",
				folder => "%s>",
				name   => "%s",
				ext    => ".%s",
		},
	},
	{
		name   => RISCOS,
		symdir => '.',
		symext => '/',
		regexp => qr!^
			(?<dir>
				(?<volume>
					(
						(?<fstype> [^\$\#:.]* )
						( \# (?<option> [^\$\#:.]* ) )?
					: )?
					( : (?<disk> [^\$\#:.]* ) \. )?
				)
				( (?<folder> .* ) \. )?
			)
			(?<file>
				(?<name> [^./]*? )
				( / (?<ext> [^.]* ) )?
			)
		\z!xsn,
		join => sub {
			_join [qw/path dir volume file/],
				fstype => "%s",
				option => "#%s",
				[qw/fstype option/] => ":",
				disk   => ":%s.",
				folder => "%s.",
				name   => "%s",
				ext    => "/%s",
		},
	},
	{
		name   => MACOS,
		symdir => ':',
		symext => '.',
		regexp => qr!^
			(?<dir>
				( (?<volume> [^:]* ) : )?
				( (?<folder>    .* ) : )?
			)
			(?<file>
				(?<name> [^.:]*? )
				( \. (?<ext> [^:]* ) )?
			)
		\z!xsn,
		join => sub {
			_join [qw/path dir file/],
				volume => "%s:",
				folder => "%s:",
				name   => "%s",
				ext    => ".%s",
		},
	},
	{
		name   => VMESA,
		symdir => '/',
		symext => '.',
		regexp => qr!^
			\s* (?<userid> \S+ )
			\s+ (?<file>
				    (?<name> \S+ )
				\s+ (?<ext>  \S+ )
			)
			\s+ (?<volume> \S+ )
			\s*
		\z!xsn,
		join => sub {
			_join [qw/path/],
				[qw/userid file ext volume/] => "%s %s %s %s",
		},
	},
	
);

# Инициализация по имени
%FS = map {
	$_->{symdirquote} = quotemeta $_->{symdir};
	$_->{symextquote} = quotemeta $_->{symext};
	
	my @S;
	while($_->{regexp} =~ m{
		\\ .
		| (?<open> \( ( \?<(?<group> \w+ )> )? )
		| (?<close> \) )
	}gx) {
		if($+{open}) {
			my $group = $+{group};

			if ($group && @S) {
				my $curgroup;
				for(my $i = $#S; $i>=0; --$i) { $curgroup = $S[$i][1], last if defined $S[$i][1] }
				
				$_->{remove}{$curgroup}{$group}++ if defined $curgroup;
			}
		
			push @S, [length($`) + length $&, $group];
		}
		elsif($+{close}) {
			my ($pos, $group, $g2) = @{pop @S};
			
			$S[$#S][2] //= $group if $_->{group}{$group} && @S;
			
			$group //= $g2;
			$_->{group}{$group} = do {
				my $x = substr $_->{regexp}, $pos, length($`) - $pos;
				qr/()^$x\z/xsn
			} if defined $group;
		}
	}
	
	my $x = $_;
	ref $_->{name}? (map { ($_ => $x) } @{$_->{name}}): ($_->{name} => $_)
} @FS;

sub _fs() { $FS{lc $^O} // $FS{unix} }

# Мы находимся в ОС семейства UNIX
sub isUNIX() { _fs->{name} eq "unix" }

# Разбивает директорию на составляющие
sub splitdir(;$) {
	my ($dir) = @_ == 0? $_: @_;
	($dir) = @$dir if ref $dir;
	my $fs = _fs;
	$dir = $fs->{before_split}->($dir) if exists $fs->{before_split};
	split $fs->{symdirquote}, $dir, -1
}

# Объединяет директорию из составляющих
sub joindir(@) {
	join _fs->{symdir}, @_
}

# Разбивает расширение (тип файла) на составляющие
sub splitext(;$) {
	my ($ext) = @_ == 0? $_: @_;
	($ext) = @$ext if ref $ext;
	split _fs->{symextquote}, $ext, -1
}

# Объединяет расширение (тип файла) из составляющих
sub joinext(@) {
	join _fs->{symext}, @_
}


# Выделяет в пути составляющие, а если получает хеш, то объединяет его в путь
sub path(;$) {
	my ($path) = @_ == 0? $_: @_;
	
	my $fs = _fs;
	
	if(ref $path eq "HASH") {
		local $_ = $path;
		return $fs->{join}->();
	}
	
	($path) = @$path if ref $path;
	
	$path = $fs->{before_split}->($path) if exists $fs->{before_split};
	
	+{
		$path =~ $fs->{regexp}? (map { $_ ne "ext" && $+{$_} eq ""? (): ($_ => $+{$_}) } keys %+): (error => 1),
		path => $path,
	}
}

# Переводит путь из формата одной ОС в другую
sub transpath ($$;$) {
	my ($path, $from, $to) = @_ == 2? ($_, @_): @_;
	my (@dir, @folder, @ext);
	{ local $^O = $from;
		$path = path $path;

		@dir = splitdir $path->{dir} if exists $path->{dir} && !exists $path->{folder};
		@folder = splitdir $path->{folder} if exists $path->{folder};
		@ext = splitext $path->{ext} if exists $path->{ext};
	}

	delete $path->{path};
	delete $path->{dir} if exists $path->{folder};
	delete $path->{file};
	
	{ local $^O = $to;
		@dir = @folder, @folder = () if !_fs->{group}{folder};
		
		$path->{dir} = joindir @dir if scalar @dir;
		$path->{folder} = joindir @folder if scalar @folder;
		$path->{ext}    = joinext @ext if scalar @ext;
		path $path;
	}
}

# как mkdir -p
use constant FILE_EXISTS => 17;
use config   DIR_DEFAULT_PERMISSION => 0755;
sub mkpath (;$) {
	my ($path) = @_ == 0? $_: @_;
	
	my $permission;
	($path, $permission) = @$path if ref $path;
	$permission = DIR_DEFAULT_PERMISSION unless Scalar::Util::looks_like_number $permission;
	
	local $!;
	
	if(isUNIX) {
		while($path =~ m!/!g) {
			mkdir $`, $permission
				or ($! != FILE_EXISTS? die "mkpath $`: $!": ())
					if $` ne '';
		}
	}
	else {
		my $part = path $path;
		
		return $path unless exists $part->{folder};
		
		my @dirs = splitdir $part->{folder};
		
		# Если волюм или первый dirs пуст - значит путь относительный
		my $cat = $part->{volume};
		for(my $i=0; $i<@dirs; $i++) {
			
			next if $dirs[$i] eq "";
			
			my $cat = path +{
				$part->{volume}? (volume => $part->{volume}): (),
				folder => joindir(@dirs[0..$i]),
			};
			
			mkdir $cat, $permission or ($! != FILE_EXISTS? die "mkpath $cat: $!": ());
		}
	}
	
	$path
}

# Считывает файл
sub cat(;$) {
    my ($file) = @_ == 0? $_: @_;
	my $layer = ":utf8";
	($file, $layer) = @$file if ref $file;
	open my $f, "<$layer", $file or die "cat $file: $!";
	read $f, my $x, -s $f;
	close $f;
	$x
}

# записать файл
sub lay ($;$) {
	my ($file, $s) = @_ == 1? ($_, @_): @_;
	my $layer = ":utf8";
	($file, $layer) = @$file if ref $file;
	open my $f, ">$layer", $file or die "lay $file: $!";
	local $\;
	print $f $s;
	close $f;
	$file
}

# считать файл, если он ещё не был считан
our %FILE_INC;
sub catonce (;$) {
	my ($file) = @_ == 0? $_: @_;
	die "catonce not use ref path!" if ref $file;
	return undef if exists $FILE_INC{$file};
	$FILE_INC{$file} = 1;
	cat $file
}

use constant {
	DEV_NO		=> 0,	# Номер устройства
	INO_NO		=> 1,	# Номер inode
	MODE_NO		=> 2,	# Режим файла (права доступа)
	NLINK_NO	=> 3,	# Количество жестких ссылок
	UID_NO		=> 4,	# Идентификатор пользователя-владельца
	GID_NO		=> 5,	# Идентификатор группы-владельца
	RDEV_NO		=> 6,	# Номер устройства (если это специальный файл)
	SIZE_NO		=> 7,	# Размер файла в байтах
	ATIME_NO	=> 8,	# Время последнего доступа
	MTIME_NO	=> 9,	# Время последнего изменения
	CTIME_NO	=> 10,	# Время последнего изменения inode
	BLKSIZE_NO	=> 11,	# Размер блока ввода-вывода
	BLOCKS_NO	=> 12,	# Количество выделенных блоков
};

# Вернуть время модификации файла
sub mtime(;$) {
	my ($file) = @_ == 0? $_: @_;
	($file) = @$file if ref $file;
	(Time::HiRes::stat $file)[MTIME_NO] // die "mtime $file: $!"
}

# Информация о файле в виде хеша
sub sta(;$) {
	my ($path) = @_ == 0? $_: @_;
	($path) = @$path if ref $path;
	
	my %sta = (path => $path);
	@sta{qw/dev ino mode nlink uid gid rdev size atime mtime ctime blksize blocks/} = Time::HiRes::stat $path or die "sta $path: $!";
# 	@sta{qw/
# 		 user_can_exec user_can_read   user_can_write
# 		group_can_exec group_can_read group_can_write
# 		other_can_exec other_can_read other_can_write
# 	/} = (
# 		
# 	);
	\%sta
}

# Файловые фильтры
sub _filters(@) {
	map {
		if(ref $_ eq "CODE") {$_}
		elsif(ref $_ eq "Regexp") { my $re = $_; sub { $_ =~ $re } }
		elsif(/^-([a-z]+)$/) {
			eval join "", "sub { ", (join " && ", map "-$_()", split //, $1), " }"
		}
		else { my $re = wildcard(); sub { $_ =~ $re } }
	} @_
}

# Найти файлы
sub find(;@) {
	my $file = @_? shift: $_;
    $file = [$file] unless ref $file;

	my @noenters; my $errorenter = sub {};
	my $ex = @_ && ref($_[$#_]) =~ /^Aion::Fs::(noenter|errorenter)\z/ ? pop: undef;

	if($ex) {
		if($1 eq "errorenter") {
			$errorenter = $ex;
		} else {
			$errorenter = pop @$ex if ref $ex->[$#$ex] eq "Aion::Fs::errorenter";
			push @noenters, _filters @$ex;
		}
	}
	
	my @filters = _filters @_;
	my $wantarray = wantarray;

	my @ret; my $count;

	eval {
		local $_;
		
	    FILE: while(@$file) {
			my $path = shift @$file;

			for my $filter (@filters) {
				local $_ = $path;
				goto DIR unless $filter->();
			}

			# Не держим память, если это не нужно
			if($wantarray) { push @ret, $path } else { $count++ }

			DIR: if(-d $path) {
				for my $noenter (@noenters) {
					local $_ = $path;
					next FILE if $noenter->();
				}

				opendir my $dir, $path or do { local $_ = $path; $errorenter->(); next FILE };
				my @file;
				while(my $f = readdir $dir) {
					push @file, File::Spec->join($path, $f) if $f !~ /^\.{1,2}\z/;
				}
				push @$file, sort @file;
				closedir $dir;
			}
		}
		
	};
	
	if($@) {
		die if ref $@ ne "Aion::Fs::stop";
	}

	wantarray? @ret: $count
}

# Не входить в подкаталоги
sub noenter(@) {
	bless [@_], "Aion::Fs::noenter"
}

# Вызывается для всех ошибок ввода-вывода
sub errorenter(&) {
	bless shift, "Aion::Fs::errorenter"
}

# Останавливает find будучи вызван с одного из его фильтров, errorenter или noenter
sub find_stop() {
	die bless {}, "Aion::Fs::stop"
}

# Производит замену во всех указанных файлах. Возвращает файлы в которых замен не было
sub replace(&@) {
    my $fn = shift;
	my @noreplace; local $_; my $pkg = caller;
	my $aref = "${pkg}::a";	my $bref = "${pkg}::b";
    for $$aref (@_) {
		if(ref $$aref) { ($$aref, $$bref) = @$$aref } else { $$bref = ":utf8" }
        my $file = $_ = cat [$$aref, $$bref];
        $fn->();
		if($file ne $_) { lay [$$aref, $$bref], $_ } else { push @noreplace, $$aref if defined wantarray }
    }
	@noreplace
}

# Стирает все указанные файлы. Возвращает переданные файлы
sub erase(@) {
    -d? rmdir: unlink or die "erase ${\(-d? 'dir': 'file')} $_: $!" for @_;
	@_
}

# Переводит вилдкард в регулярку
sub wildcard(;$) {
	my ($wildcard) = @_;
	$wildcard = $_ if @_ == 0;
	$wildcard =~ s{
		(?<file> \*\*)
		| (?<path> \*)
		| (?<anyn> \?\? )
		| (?<any> \? )
		| (?<w1> \{ )
		| (?<w2> \} )
		| (?<comma> , )
		| .
	}{
		exists $+{file}? "[^/]*?":
		exists $+{path}? ".*?":
		exists $+{anyn}? "[^/]":
		exists $+{any}? ".":
		exists $+{w1}? "(":
		exists $+{w2}? ")":
		exists $+{comma}? "|":
		quotemeta $&
	}gxe;
	qr/^$wildcard$/ns
}

# Открывает файл на указанной строке в редакторе
use config EDITOR => "vscodium %p:%l";
sub goto_editor($$) {
	my ($path, $line) = @_;
	my $p = EDITOR;
	$p =~ s!%p!$path!;
	$p =~ s!%l!$line!;
	my $status = system $p;
	die "$path:$line --> $status" if $status;
	return;
}

# Из пакета в файловый путь
sub from_pkg(;$) {
	my ($pkg) = @_ == 0? $_: @_;
	$pkg =~ s!::!/!g;
	"$pkg.pm"
}

# Из файлового пути в пакет
sub to_pkg(;$) {
	my ($path) = @_ == 0? $_: @_;
	$path =~ s!\.\w+$!!;
	$path =~ s!/!::!g;
	$path
}

# Подключает модуль, если он ещё не подключён, и возвращает его
sub include(;$) {
	my ($pkg) = @_ == 0? $_: @_;
	return $pkg if $pkg->can("new") || $pkg->can("has");
	my $path = from_pkg $pkg;
	return $pkg if exists $INC{$path};
	require $path;
	$pkg
}

1;

__END__

=encoding utf-8

=head1 NAME

Aion::Fs - utilities for the file system: reading, writing, searching, replacing files, etc.

=head1 VERSION

0.0.8

=head1 SYNOPSIS

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

=head1 DESCRIPTION

This module makes it easier to use the file system.

Modules C<File::Path>, C<File::Slurper> and
C<File::Find> is burdened with various features that are rarely used, but require time to become familiar with and thereby increase the barrier to entry.

C<Aion::Fs> uses the KISS programming principle - the simpler the better!

The C<IO::All> supermodule is not a competitor to C<Aion::Fs>, because uses an OOP approach, and C<Aion::Fs> is FP.

=over

=item * OOP - object-oriented programming.

=item * FP - functional programming.

=back

=head1 SUBROUTINES/METHODS

=head2 cat ($file)

Reads the file. If no parameter is specified, use C<$_>.

	cat "/etc/passwd"  # ~> root

C<cat> reads with layer C<:utf8>. But you can specify another layer like this:

	lay "unicode.txt", "↯";
	length cat "unicode.txt"            # -> 1
	length cat["unicode.txt", ":raw"]   # -> 3

C<cat> throws an exception if the I/O operation fails:

	eval { cat "A" }; $@  # ~> cat A: No such file or directory

--timeout
13

--timeout
13

=head2 lay ($file?, $content)

Writes C<$content> to C<$file>.

=over

=item * If one parameter is specified, use C<$_> instead of C<$file>.

=item * C<lay>, uses the C<:utf8> layer. To specify a different layer, use an array of two elements in the C<$file> parameter:

=back

	lay "unicode.txt", "↯"  # => unicode.txt
	lay ["unicode.txt", ":raw"], "↯"  # => unicode.txt
	
	eval { lay "/", "↯" }; $@ # ~> lay /: Is a directory

--timeout
13

--timeout
13

=head2 find (;$path, @filters)

Recursively traverses and returns paths from the specified path or paths if C<$path> is an array reference. Without parameters, uses C<$_> as C<$path>.

Filters can be:

=over

=item * By subroutine - the path to the current file is passed to C<$_>, and the subroutine must return true or false, as understood by Perl.

=item * Regexp - tests each path with a regular expression.

=item * String in the form "-Xxx", where C<Xxx> is one or more characters. Similar to Perl operators for testing files. Example: C<-fr> checks the path with file testers LLL<https://perldoc.perl.org/functions/-X>.

=item * The remaining lines are turned by the C<wildcard> function (see below) into a regular expression to test each path.

=back

Paths that fail the C<@filters> check are not returned.

If the -X filter is not a perl file function, an exception is thrown:

	eval { find "example", "-h" }; $@   # ~> Undefined subroutine &Aion::Fs::h called

In this example, C<find> cannot enter the subdirectory and passes an error to the C<errorenter> function (see below) with the C<$_> and C<$!> variables set (to the directory path and the OS error message).

B<Attention!> If C<errorenter> is not specified, then all errors are B<ignored>!

	mkpath ["example/", 0];
	
	[find "example"]                  # --> ["example"]
	[find "example", noenter "-d"]    # --> ["example"]
	
	eval { find "example", errorenter { die "find $_: $!" } }; $@   # ~> find example: Permission denied
	
	mkpath for qw!ex/1/11 ex/1/12 ex/2/21 ex/2/22!;
	
	my $count = 0;
	find "ex", sub { find_stop if ++$count == 3; 1}  # -> 2

--timeout
13

--timeout
13

=head2 noenter (@filters)

Tells C<find> not to enter directories matching the filters behind it.

=head2 errorenter (&block)

Calls C<&block> for every error that occurs when a directory cannot be entered.

=head2 find_stop ()

Stops C<find> being called in one of its filters, C<errorenter> or C<noenter>.

	my $count = 0;
	find "ex", sub { find_stop if ++$count == 3; 1}  # -> 2

=head2 erase (@paths)

Removes files and empty directories. Returns C<@paths>. If there is an I/O error, it throws an exception.

	eval { erase "/" }; $@  # ~> erase dir /: Device or resource busy
	eval { erase "/dev/null" }; $@  # ~> erase file /dev/null: Permission denied

--timeout
13

--timeout
13

=head2 replace (&sub, @files)

Replaces each file with C<$_> if it is modified by C<&sub>. Returns files that have no replacements.

C<@files> can contain arrays of two elements. The first is treated as a path and the second as a layer. The default layer is C<:utf8>.

C<&sub> is called for each file in C<@files>. It transmits:

=over

=item * C<$_> - file contents.

=item * C<$a> — path to the file.

=item * C<$b> — the layer by which the file was read and by which it will be written.

=back

In the example below, the file "replace.ex" is read by the C<:utf8> layer and written by the C<:raw> layer in the C<replace> function:

	local $_ = "replace.ex";
	lay "abc";
	replace { $b = ":utf8"; y/a/¡/ } [$_, ":raw"];
	cat  # => ¡bc

--timeout
13

--timeout
13

=head2 mkpath (;$path)

Like B<mkdir -p>, but considers the last part of the path (after the last slash) to be a filename and does not create it as a directory. Without a parameter, uses C<$_>.

=over

=item * If C<$path> is not specified, use C<$_>.

=item * If C<$path> is an array reference, then the path is used as the first element and rights as the second element.

=item * The default permission is C<0755>.

=item * Returns C<$path>.

=back

	local $_ = ["A", 0755];
	mkpath   # => A
	
	eval { mkpath "/A/" }; $@   # ~> mkpath /A: Permission denied
	
	mkpath "A///./file";
	-d "A"  # -> 1

--timeout
13

=over

=item * <File::Path> - C<mkpath("dir1/dir2")>.

=item * <File::Path::Tiny> - C<File::Path::Tiny::mk($path)>. Does not throw exceptions.

=back

=head2 mtime (;$path)

Modification time of C<$path> in unixtime with fractional part (from C<Time::HiRes::stat>). Without a parameter, uses C<$_>.

Throws an exception if the file does not exist or does not have permission:

	local $_ = "nofile";
	eval { mtime }; $@  # ~> mtime nofile: No such file or directory
	
	mtime ["/"]   # ~> ^\d+(\.\d+)?$

--timeout
13

--timeout
13

=head2 sta (;$path)

Returns statistics about the file. Without a parameter, uses C<$_>.

To be used with other file functions, it can receive a reference to an array from which it takes the first element as the file path.

Throws an exception if the file does not exist or does not have permission:

	local $_ = "nofile";
	eval { sta }; $@  # ~> sta nofile: No such file or directory
	
	sta(["/"])->{ino} # ~> ^\d+$
	sta(".")->{atime} # ~> ^\d+(\.\d+)?$

--timeout
13

=over

=item * <Fcntl> – contains constants for mode recognition.

=item * <BSD::stat> - optionally returns atime, ctime and mtime in nanoseconds, user flags and file generation number. Has an OOP interface.

=item * <File::chmod> – C<chmod("o=,g-w","file1","file2")>, C<@newmodes = getchmod("+x","file1","file2")>.

=item * <File::stat> – provides an OOP interface to stat.

=item * <File::Stat::Bits> – similar to <Fcntl>.

=item * <File::stat::Extra> – extends <File::stat> with methods to obtain information about the mode, and also reloads B<-X>, B<< <=> >>, B<cmp> and B<~~> operators and stringified.

=item * <File::Stat::Ls> – returns the mode in the format of the ls utility.

=item * <File::Stat::Moose> – OOP interface for Moose.

=item * <File::Stat::OO> – provides an OOP interface to stat. Can return atime, ctime and mtime at once in C<DateTime>.

=item * <File::Stat::Trigger> – monitors changes in file attributes.

=item * <Linux::stat> – parses /proc/stat and returns additional information. However, it does not work on other OSes.

=item * <Stat::lsMode> – returns the mode in the format of the ls utility.

=item * <VMS::Stat> – returns VMS ACLs.

=back

=head2 path (;$path)

Splits a file path into its components or assembles it from its components.

--timeout
13

	{
	    local $^O = "freebsd";
	
	    path "."        # --> {path => ".", file => ".", name => "."}
	    path ".bashrc"  # --> {path => ".bashrc", file => ".bashrc", name => ".bashrc"}
	    path ".bash.rc"  # --> {path => ".bash.rc", file => ".bash.rc", name => ".bash", ext => "rc"}
	    path ["/"]      # --> {path => "/", dir => "/"}
	    local $_ = "";
	    path            # --> {path => ""}
	    path "a/b/c.ext.ly"   # --> {path => "a/b/c.ext.ly", dir => "a/b", file => "c.ext.ly", name => "c", ext => "ext.ly"}
	
	    path +{dir  => "/", ext => "ext.ly"}    # => /.ext.ly
	    path +{file => "b.c", ext => "ly"}      # => b.ly
	    path +{path => "a/b/f.c", dir => "m"}   # => m/f.c
	
	    local $_ = +{path => "a/b/f.c", dir => undef, ext => undef};
	    path # => f
	    path +{path => "a/b/f.c", volume => "/x", dir => "m/y/", file => "f.y", name => "j", ext => "ext"} # => m/y//j.ext
	    path +{path => "a/b/f.c", volume => "/x", dir => "/y", file => "f.y", name => "j", ext => "ext"} # => /y/j.ext
	}
	
	{
	    local $^O = "MSWin32"; # also os2, symbian and dos
	
	    path "."        # --> {path => ".", file => ".", name => "."}
	    path ".bashrc"  # --> {path => ".bashrc", file => ".bashrc", name => ".bashrc"}
	    path "/"        # --> {path => "\\", dir => "\\", folder => "\\"}
	    path "\\"       # --> {path => "\\", dir => "\\", folder => "\\"}
	    path ""         # --> {path => ""}
	    path "a\\b\\c.ext.ly"   # --> {path => "a\\b\\c.ext.ly", dir => "a\\b\\", folder => "a\\b", file => "c.ext.ly", name => "c", ext => "ext.ly"}
	
	    path +{dir  => "/", ext => "ext.ly"}    # => \\.ext.ly
	    path +{dir  => "\\", ext => "ext.ly"}   # => \\.ext.ly
	    path +{file => "b.c", ext => "ly"}      # => b.ly
	    path +{path => "a/b/f.c", dir => "m/r/"}   # => m\\r\\f.c
	
	    path +{path => "a/b/f.c", dir => undef, ext => undef} # => f
	    path +{path => "a/b/f.c", volume => "x", dir => "m/y/", file => "f.y", name => "j", ext => "ext"} # \> x:m\y\j.ext
	    path +{path => "x:/a/b/f.c", volume => undef, dir =>  "/y/", file => "f.y", name => "j", ext => "ext"} # \> \y\j.ext
	}
	
	{
	    local $^O = "amigaos";
	
	    my $path = {
	        path   => "Work1:Documents/Letters/Letter1.txt",
	        dir    => "Work1:Documents/Letters/",
	        volume => "Work1",
	        folder => "Documents/Letters",
	        file   => "Letter1.txt",
	        name   => "Letter1",
	        ext    => "txt",
	    };
	
	    path "Work1:Documents/Letters/Letter1.txt" # --> $path
	
	    path {volume => "Work", file => "Letter1.pm", ext => "txt"} # => Work:Letter1.txt
	}
	
	{
	    local $^O = "cygwin";
	
	    my $path = {
	        path   => "/cygdrive/c/Documents/Letters/Letter1.txt",
	        dir    => "/cygdrive/c/Documents/Letters/",
	        volume => "c",
	        folder => "Documents/Letters",
	        file   => "Letter1.txt",
	        name   => "Letter1",
	        ext    => "txt",
	    };
	
	    path "/cygdrive/c/Documents/Letters/Letter1.txt" # --> $path
	
	    path {volume => "c", file => "Letter1.pm", ext => "txt"} # => /cygdrive/c/Letter1.txt
	}
	
	{
	    local $^O = "dos";
	
	    my $path = {
	        path   => 'c:\Documents\Letters\Letter1.txt',
	        dir    => 'c:\Documents\Letters\\',
	        volume => 'c',
	        folder => '\Documents\Letters',
	        file   => 'Letter1.txt',
	        name   => 'Letter1',
	        ext    => 'txt',
	    };
	
	    path 'c:\Documents\Letters\Letter1.txt' # --> $path
	
	    path {volume => "c", file => "Letter1.pm", ext => "txt"} # \> c:Letter1.txt
	    path {dir => 'r\t\\',  file => "Letter1",    ext => "txt"} # \> r\t\Letter1.txt
	}
	
	{
	    local $^O = "VMS";
	
	    my $path = {
	        path   => "DISK:[DIRECTORY.SUBDIRECTORY]FILENAME.EXTENSION",
	        dir    => "DISK:[DIRECTORY.SUBDIRECTORY]",
	        volume => "DISK:",
	        disk   => "DISK",
	        folder => "DIRECTORY.SUBDIRECTORY",
	        card   => "FILENAME.EXTENSION",
	        file   => "FILENAME.EXTENSION",
	        name   => "FILENAME",
	        ext    => "EXTENSION",
	    };
	
	    path "DISK:[DIRECTORY.SUBDIRECTORY]FILENAME.EXTENSION" # --> $path
	
	    $path = {
	        path        => 'NODE["account password"]::DISK$USER:[DIRECTORY.SUBDIRECTORY]FILENAME.EXTENSION;7',
	        dir         => 'NODE["account password"]::DISK$USER:[DIRECTORY.SUBDIRECTORY]',
	        node        => "NODE",
	        accountname => "account",
	        password    => "password",
	        volume      => 'DISK$USER:',
	        disk        => 'DISK',
	        user        => 'USER',
	        folder      => "DIRECTORY.SUBDIRECTORY",
	        card        => "FILENAME.EXTENSION;7",
	        file        => "FILENAME.EXTENSION",
	        name        => "FILENAME",
	        ext         => "EXTENSION",
	        version     => 7,
	    };
	
	    path 'NODE["account password"]::DISK$USER:[DIRECTORY.SUBDIRECTORY]FILENAME.EXTENSION;7' # --> $path
	
	    path {volume => "DISK:", file => "FILENAME.pm", ext => "EXTENSION"} # => DISK:FILENAME.EXTENSION
	    path {user => "USER", folder => "DIRECTORY.SUBDIRECTORY", file => "FILENAME.pm", ext => "EXTENSION"} # \> $USER:[DIRECTORY.SUBDIRECTORY]FILENAME.EXTENSION
	}
	
	{
	    local $^O = "VOS";
	
	    my $path = {
	        path    => "%sysname#module1>SubDir>File.txt",
	        dir     => "%sysname#module1>SubDir>",
	        volume  => "%sysname#module1>",
	        sysname => "sysname",
	        module  => "module1",
	        folder  => "SubDir",
	        file    => "File.txt",
	        name    => "File",
	        ext     => "txt",
	    };
	
	    path $path->{path} # --> $path
	
	    path {volume => "%sysname#module1>", file => "File.pm", ext => "txt"} # => %sysname#module1>File.txt
	    path {module => "module1", file => "File.pm"} # => %#module1>File.pm
	    path {sysname => "sysname", file => "File.pm"} # => %sysname#>File.pm
	    path {dir => "dir>subdir>", file => "File.pm", ext => "txt"} # => dir>subdir>File.txt
	}
	
	{
	    local $^O = "riscos";
	
	    my $path = {
	        path   => 'Filesystem#Special_Field::DiskName.$.Directory.Directory.File/Ext/Ext',
	        dir    => 'Filesystem#Special_Field::DiskName.$.Directory.Directory.',
	        volume => 'Filesystem#Special_Field::DiskName.',
	        fstype => "Filesystem",
	        option => "Special_Field",
	        disk   => "DiskName",
	        folder => '$.Directory.Directory',
	        file   => "File/Ext/Ext",
	        name   => "File",
	        ext    => "Ext/Ext",
	    };
	
	    path $path->{path} # --> $path
	
	    $path = {
	        path => '.$.Directory.Directory.',
	        dir => '.$.Directory.Directory.',
	        folder => '.$.Directory.Directory',
	    };
	
	    path '.$.Directory.Directory.' # --> $path
	
	    path {volume => "ADFS::HardDisk.", file => "File"} # => ADFS::HardDisk.$.File
	    path {folder => "x"}  # => x.
	    path {dir    => "x."} # => x.
	}
	
	{
	    local $^O = "MacOS";
	
	    my $path = {
	        path   => '::::mix:report.doc',
	        dir    => "::::mix:",
	        folder => ":::mix",
	        file   => "report.doc",
	        name   => "report",
	        ext    => "doc",
	    };
	
	    path $path->{path} # --> $path
	    path $path         # => $path->{path}
	
	    path 'report' # --> {path => 'report', file => 'report', name => 'report'}
	
	    path {volume => "x", file => "f"} # => x:f
	    path {folder => "x"} # => x:
	}
	
	{
	    local $^O = "vmesa";
	
	    my $path = {
	        path   => ' USERID   FILE EXT   VOLUME ',
	        userid => "USERID",
	        file   => "FILE EXT",
	        name   => "FILE",
	        ext    => "EXT",
	        volume => "VOLUME",
	    };
	
	    path $path->{path} # --> $path
	
	    path {volume => "x", file => "f"} # -> ' f  x'
	}
	

--timeout
13

--timeout
13

--timeout
13

--timeout
13

--timeout
13

--timeout
13

=head2 transpath ($path?, $from, $to)

--timeout
13

--timeout
13

--timeout
13

--timeout
13

	local $_ = ">x>y>z.doc.zip";
	transpath "vos", "unix"       # \> /x/y/z.doc.zip
	transpath "vos", "VMS"        # \> [.x.y]z.doc.zip
	transpath $_, "vos", "RiscOS" # \> .x.y.z/doc/zip

=head2 splitdir (;$dir)

--timeout
13

	local $^O = "unix";
	[ splitdir "/x/" ]    # --> ["", "x", ""]

--timeout
13

--timeout
13

	local $^O = "unix";
	joindir qw/x y z/    # => x/y/z
	
	path +{ dir => joindir qw/x y z/ } # => x/y/z/

--timeout
13

--timeout
13

	local $^O = "unix";
	[ splitext ".x." ]    # --> ["", "x", ""]

--timeout
13

--timeout
13

	local $^O = "unix";
	joinext qw/x y z/    # => x.y.z
	
	path +{ ext => joinext qw/x y z/ } # => .x.y.z

--timeout
13

Connects C<$pkg> (if it has not already been connected via C<use> or C<require>) and returns it. Without a parameter, uses C<$_>.

lib/A.pm file:

	package A;
	sub new { bless {@_}, shift }
	1;

lib/N.pm file:

	package N;
	sub ex { 123 }
	1;



	use lib "lib";
	include("A")->new               # ~> A=HASH\(0x\w+\)
	[map include, qw/A N/]          # --> [qw/A N/]
	{ local $_="N"; include->ex }   # -> 123

=head2 catonce (;$file)

Reads the file for the first time. Any subsequent attempt to read this file returns C<undef>. Used to insert js and css modules into the resulting file. Without a parameter, uses C<$_>.

=over

=item * C<$file> can contain arrays of two elements. The first is treated as a path and the second as a layer. The default layer is C<:utf8>.

=item * If C<$file> is not specified, use C<$_>.

=back

	local $_ = "catonce.txt";
	lay "result";
	catonce  # -> "result"
	catonce  # -> undef
	
	eval { catonce[] }; $@ # ~> catonce not use ref path!

=head2 wildcard (;$wildcard)

Converts a file mask to a regular expression. Without a parameter, uses C<$_>.

=over

=item * C<**> - C<[^/]*>

=item * C<*> - C<.*>

=item * C<?> - C<.>

=item * C<??> - C<[^/]>

=item * C<{> - C<(>

=item * C<}> - C<)>

=item * C<,> - C<|>

=item * Other characters are escaped using C<quotemeta>.

=back

	wildcard "*.{pm,pl}"  # \> (?^usn:^.*?\.(pm|pl)$)
	wildcard "?_??_**"  # \> (?^usn:^._[^/]_[^/]*?$)

Used in filters of the C<find> function.

=head3 See also

=over

=item * <File::Wildcard>.

=item * <String::Wildcard::Bash>.

=item * <Text::Glob> - C<glob_to_regex("*.{pm,pl}")>.

=back

=head2 goto_editor ($path, $line)

Opens the file in the editor from .config at the specified line. Defaults to C<vscodium %p:%l>.

.config.pm file:

	package config;
	
	config_module 'Aion::Fs' => {
	    EDITOR => 'echo %p:%l > ed.txt',
	};
	
	1;



	goto_editor "mypath", 10;
	cat "ed.txt"  # => mypath:10\n
	
	eval { goto_editor "`", 1 }; $@  # ~> `:1 --> 512

=head2 from_pkg (;$pkg)

Transfers the packet to the FS path. Without a parameter, uses C<$_>.

	from_pkg "Aion::Fs"  # => Aion/Fs.pm
	[map from_pkg, "Aion::Fs", "A::B::C"]  # --> ["Aion/Fs.pm", "A/B/C.pm"]

=head2 to_pkg (;$path)

Translates the path from the FS to the package. Without a parameter, uses C<$_>.

	to_pkg "Aion/Fs.pm"  # => Aion::Fs
	[map to_pkg, "Aion/Fs.md", "A/B/C.md"]  # --> ["Aion::Fs", "A::B::C"]

=head1 AUTHOR

Yaroslav O. Kosmina L<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

The Aion::Fs is copyright © 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.
