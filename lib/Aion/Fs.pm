package Aion::Fs;
use 5.22.0;
no strict; no warnings; no diagnostics;
use common::sense;

our $VERSION = "0.0.0-prealpha";

use Exporter qw/import/;
use List::Util qw/any all/;

our @EXPORT = our @EXPORT_OK = grep {
	ref \$Aion::Fs::{$_} eq "GLOB" && *{$Aion::Fs::{$_}}{CODE} && !/^(_|(NaN|import)\z)/n
} keys %Aion::Fs::;

# Подключает модуль, если он ещё не подключён, и возвращает его
sub include(;$) {
	my ($pkg) = @_;
	$pkg = $_ if @_ == 0;
	return $pkg if $pkg->can("new");
	my $path = ($pkg =~ s!::!/!gr) . ".pm";
	return $pkg if exists $INC{$path};
	require $path;
	$pkg
}

# Текущий путь в exec и replace
our $PATH;
sub PATH() {$PATH}

# как mkdir -p
use constant FILE_EXISTS => 17;
use constant DIR_DEFAULT_PERMISSION => 0755;
sub mkpath (;$) {
	my ($path) = @_;
	$path = $PATH if @_ == 0;
	my $permission = DIR_DEFAULT_PERMISSION;
	($path, $permission) = @$path if ref $path;
	mkdir $`, $permission or ($! != FILE_EXISTS? die "mkpath $`: $!": ()) while $path =~ m!/!g;
	undef $!;
	$path
}

# Считывает файл
# Для считываения :raw:
#  {use open IN => ':raw'; cat }
sub cat(;$) {
    my ($file) = @_;
	$file = $PATH if @_ == 0;
	my $layer = ":utf8";
	($file, $layer) = @$file if ref $file;
	open my $f, "<$layer", $file or die "cat $file: $!";
	read $f, my $x, -s $f;
	close $f;
	$x
}

# записать файл
# Для записи :raw:
#  {use open OUT => ':raw'; lay $path }
sub lay (;$$) {
	my ($file, $s) = @_;
	$file = $PATH if @_ == 0;
	$s = $_ if @_ <= 1;
	my $layer = ":utf8";
	($file, $layer) = @$file if ref $file;
	open my $f, ">$layer", $file or die "lay $file: $!";
	print $f $s;
	close $f;
	$file
}

# считать файл, если он ещё не был считан
our %FILE_INC;
sub catonce (;$) {
	my ($file) = @_;
	$file = $PATH if @_ == 0;
	die "catonce not use ref path!" if ref $file;
	return undef if exists $FILE_INC{$file};
	$FILE_INC{$file} = 1;
	cat($file)
}

# Вернуть время модификации файла
sub mtime(;$) {
	my ($file) = @_;
	$file = $PATH if @_ == 0;
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
		push @filters, (eval join "", "sub { ", (join " && ", map "-$_ \$PATH", split //, $1), " }" or die) when /^-([a-z]+)$/;
		default { my $re = wildcard(); push @filters, sub { $PATH =~ $re } }
	}

	my @ret;

    FILE: while(@$file) {
		local $PATH = shift @$file;

		push @ret, $PATH if all { $_->() } @filters;

		if(-d $PATH) {
			next FILE if any { $_->() } @noenter;

			opendir my $dir, $PATH or die "find $PATH: $!";
			my @file;
			while(readdir $dir) {
				push @file, "$PATH/$_" unless /^(\.{1,2})\z/n;
			}
			push @$file, sort @file;
			closedir $dir;
		}
	}

	@ret
}

# Не входить в подкаталоги
sub noenter(&@) {
	bless(shift, "Aion::Fs::noenter"), @_
}

# Производит замену во всех указанных файлах. Возвращает файлы в которых замен не было
sub replace(&@) {
    my $fn = shift;
	my @noreplace; local($_, $PATH);
    for $PATH (@_) {
        my $file = $_ = cat;
        $fn->();
		if($file ne $_) {lay} else {push @noreplace, $PATH}
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
	qr/^$wildcard$/s
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

__END__

=encoding utf-8

=head1 NAME

Aion::Fs - utilities for filesystem: read, write, find, replace files, etc

=head1 VERSION

0.0.0-prealpha

=head1 SYNOPSIS

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

=head1 DESCRIPTION

This module provide light entering to filesystem.

Modules File::Path, File::Slurper and
File::Find are quite weighted with various features that are rarely used, but take time to get acquainted and, thereby, increases the entry threshold.

In Aion::Fs used the programming principle KISS - Keep It Simple, Stupid.

=head1 SUBROUTINES/METHODS

=head2 PATH ()

The current path in C<replace> and C<noenter> blocks. It use if not specified in C<mkpath>, C<mtime>, C<cat>, C<lay>, etc.

It is modifiable:

	local $Aion::Fs::PATH = "path1";
	{
	    local $Aion::Fs::PATH = "path2";
	    PATH  # => path2
	}
	PATH  # => path1

=head2 cat ($file)

Read file. If file not specified, then use C<PATH>.

	cat "/etc/passwd"  # ~> root

C<cat> read with layer C<:utf8>. But you can set the level like this:

	lay "unicode.txt", "↯";
	length cat "unicode.txt"            # -> 1
	length cat["unicode.txt", ":raw"]   # -> 3

C<cat> raise exception by error on io operation:

	eval { cat "A" }; $@  # ~> cat A: No such file or directory

=head2 lay ($file, $content)

Write C<$content> in C<$file>.

=over

=item * If C<$file> not specified, then use C<PATH>.

=item * If C<$content> not specified, then use C<$_>.

=item * C<lay> using layer C<:utf8>. For set layer using:

=back

	lay "unicode.txt", "↯"  # => unicode.txt
	lay ["unicode.txt", ":raw"], "↯"  # => unicode.txt
	
	eval { lay "/", "↯" }; $@ # ~> lay /: Is a directory

=head2 find ($path, @filters)

Finded files and returns array paths from start path or paths if C<$path> is array ref.

Filters may be:

=over

=item * Subroutine - the each path fits to C<$_> and test with subroutine.

=item * Regexp - test the each path on the regexp.

=item * String as "-Xxx", where C<Xxx> - one or more symbols. Test on the perl file testers. Example "-fr" test the path on C<-f> and C<-r> file testers.

=item * Any string interpret function C<wildcard> to regexp and the each path test on it.

=back

The paths that have not passed testing by C<@filters> are not returned.

=head2 erase (@paths)

Remove files and empty catalogs. Returns the C<@paths>.

=head2 noenter (&sub)

No enter to catalogs. Using in C<find>.

=head2 mkpath ($path)

As B<mkdir -p>, but consider last path-part (after last slash) as filename, and not create this catalog.

=over

=item * If C<$path> not specified, then use C<PATH>.

=item * If C<$path> is array ref, then use path as first and permission as second element.

=item * Default permission is C<0755>.

=item * Returns C<$path>.

=back

	$Aion::Fs::PATH = ["A", 0755];
	mkpath   # => A
	
	eval { mkpath "/A/" }; $@   # ~> mkpath : No such file or directory

=head2 mtime ($file)

Time modification the C<$file> in unixtime.

Raise exeception if file not exists, or not permissions:

	local $Aion::Fs::PATH = "nofile";
	eval { mtime }; $@  # ~> mtime nofile: No such file or directory

=head2 replace (&sub, @files)

Replacing each the file if C<&sub> replace C<$_>. Returns files in which there were no replacements.

C<@files> can contain arrays of two elements. The first one is treated as a path, and the second one is treated as a layer. Default layer is C<:utf8>.

=head2 include ($pkg)

Require C<$pkg> and returns it.

File lib/A.pm:

	package A;
	sub new { bless {@_}, shift }
	1;

File lib/N.pm:

	package N;
	sub ex { 123 }
	1;



	use lib "lib";
	include("A")->new               # ~> A=HASH\(0x\w+\)
	[map include, qw/A N/]          # --> [qw/A N/]
	{ local $_="N"; include->ex }   # -> 123

=head2 catonce ($file)

Read the file in first call with this file. Any call with this file return C<undef>. Using for insert js and css modules in the resulting file.

	local $Aion::Fs::PATH = "catonce.txt";
	local $_ = "result";
	lay;
	catonce  # -> $_
	catonce  # -> undef
	
	eval { catonce[] }; $@ # ~> catonce not use ref path!

=head2 wildcard ($wildcard)

Translate the wildcard to regexp.

=over

=item * C<**> - C<[^/]*>

=item * C<*> - C<.*>

=item * C<?> - C<.>

=item * C<??> - C<[^/]>

=item * C<{> - C<(>

=item * C<}> - C<)>

=item * C<,> - C<|>

=item * Any symbols translate by C<quotemeta>.

=back

	wildcard "*.{pm,pl}"  # \> (?^us:^.*?\.(pm|pl)$)

Using in filters the function C<find>.

=head2 goto_editor ($path, $line)

Open the file in editor from config on the line.

File .config.pm:

	package config;
	
	config_module 'Aion::Fs' => {
	    EDITOR => 'echo %p:%l > ed.txt',
	};
	
	1;



	goto_editor "mypath", 10;
	cat "ed.txt"  # => mypath:10\n

Default the editor is C<vscodium>.

=head1 AUTHOR

Yaroslav O. Kosmina LL<mailto:dart@cpan.org>

=head1 LICENSE

⚖ B<GPLv3>

=head1 COPYRIGHT

The Aion::Fs is copyright © 2023 by Yaroslav O. Kosmina. Rusland. All rights reserved.
