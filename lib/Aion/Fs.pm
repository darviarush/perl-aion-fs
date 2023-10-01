package Aion::Fs;
use 5.22.0;
no strict; no warnings; no diagnostics;
use common::sense;

our $VERSION = "0.0.0-prealpha";

use List::Util qw/any all/;

require Exporter;
our @EXPORT = our @EXPORT_OK = grep {
	*{$Aion::Fs::{$_}}{CODE} && !/^(_|(NaN|import)\z)/n
} keys %Aion::Fs::;

# Подключает модуль, если он ещё не подключён, и возвращает его
sub include($) {
	my ($pkg) = @_;
	return $pkg if $pkg->can("new");
	my $path = ($pkg =~ s!::!/!gr) . ".pm";
	return $pkg if exists $INC{$path};
	require $path;
	$pkg
}

# считать файл, если он ещё не был считан
our %FILE_INC;
sub require_file ($) {
	my ($file) = @_;
	return undef if exists $FILE_INC{$file};
	my $x = cat($file);
	$FILE_INC{$file} = 1;
	$x
}

# Текущий путь в exec и replace
our $PATH;
sub PATH() {$PATH}

# как mkdir -p
sub mkpath (;$$) {
	my ($path, $mode) = @_;
	$path //= $PATH;
	$mode //= 0755;
	mkdir $`, $mode while $path =~ m!/!g;
	$path
}

# Считывает файл
# Для считываения :raw:
#  {use open IN => ':raw'; cat }
sub cat(;$) {
    my ($file) = @_;
	$file //= $PATH;
	open my $f, "<", $file or die "cat $file: $!";
	read $f, my $x, -s $f;
	close $f;
	$x
}

# записать файл
# Для записи :raw:
#  {use open OUT => ':raw'; lay $path }
sub lay (;$$) {
	my ($file, $s) = @_;
	$file //= $PATH;
	$s //= $_;
	open my $f, ">", $file or die "lay $file: $!";
	print $f $s;
	close $f;
	$file
}

# Вернуть время модификации файла
sub mtime(;$) {
	my $file = shift // $PATH;
	(stat $file)[9] // die "mtime $file: $!"
}

# Найти файлы
sub find($;@) {
	my $file = shift;
    $file = [$file] unless ref $file;

	my @noenter;
	my @filters;
	for(@_) {
		push @noenter, $_ when ref $_ eq "Aion::Fs::noenter";
		push @filters, $_ when ref $_ eq "CODE";
		push @filters, do { my $re = $_; sub { $PATH =~ $re } } when ref $_ eq "Regexp";
		push @filters, eval(join "", "sub { ", (join " && ", map "-$_", split //, $1), " }") || die when /^-([a-z]+)$/;
		default { push @filters, wildcard($_) }
	}

	my @ret;

    FILE: while(@$file) {
		local $PATH = shift @$file;

		push @ret, $PATH if all { $_->() } @filters;

		if(-d $PATH) {
			next FILE if any { $_->() } @noenter;

			opendir my $dir, $PATH or die "find $PATH: $!";
			while(readdir $dir) {
				push @$file, "$PATH/$_";
			}
			closedir $dir;
		}
	}

	@ret
}

# Не входить в подкаталоги
sub noenter(&@) {
	bless(shift, "Aion::Fs::noenter"), @_
}

# # 
# sub offset($@) {
# 	bless(shift, "Aion::Fs::offset"), @_
# }

# # 
# sub limit($@) {
# 	bless(shift, "Aion::Fs::limit"), @_
# }

# Производит замену во всех указанных файлах. Возвращает количество файлов в которых были замены
sub replace(&@) {
    my $fn = shift;
	my $count = 0; local($_, $PATH);
    for my $path (@_) {
		$PATH = $path;
        my $file = $_ = cat;
        $fn->();
        $count++, lay if $file ne $_;
    }
	$count
}

# Стирает все указанные файлы. Возвращает переданные файлы
sub erase(@) {
    -d? rmdir: unlink or die "erase ${\(-d? 'dir': 'file')} $_: $!" for @_;
	@_
}

# Переводит вилдкард в регулярку
sub wildcard(;$) {
	my ($wildcard) = @_;
	$wildcard = $_;
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
	qr/$wildcard/s
}

# Открывает файл на указанной строке в редакторе
use config EDITOR => "vscodium";
sub goto_editor($$) {
	my ($path, $line) = @_;
	my $p = EDITOR;
	$p =~ s!%p!$path!;
	$p =~ s!%l!$line!;
	my $status = system $p;
	die "$path:$line\n\n$status) $?" if $status;
	return;
}

1;
