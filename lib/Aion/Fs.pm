package Aion::Fs;
use 5.22.0;
no strict; no warnings; no diagnostics;
use common::sense;

our $VERSION = "0.0.0-prealpha";

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

# как mkdir -p
sub mkpath ($;$) {
	my ($path, $mode) = @_;
	$mode //= 0755;
	mkdir $`, $mode while $path =~ m!/!g;
	$path
}

# считать файл, если он ещё не был считан
our %FILE_INC;
sub require_file ($) {
	my ($file) = @_;
	return undef if exists $FILE_INC{$file};
	my $x = read_file($file);
	$FILE_INC{$file} = 1;
	$x
}

BEGIN {

# Считывает файл в указанной кодировке
sub read(@) {
    my ($file, $layer) = @_;
	$layer //= ":utf8";
	open my $f, "<$layer", $file or die "read $file: $!";
	read $f, my $x, -s $f;
	close $f;
	$x
}

# записать файл
sub write (@) {
	my ($file, $s, $layer) = @_;
	$layer //= ":utf8";
	open my $f, ">$layer", $file or die "> $file: $!";
	print $f $s;
	close $f;
	wantarray? ($file, $s, $layer): $file
}

}

# Вернуть время модификации файла
sub mtime($) {
	(stat shift())[9]
}

# Вернуть время модификации файла
sub find($;@) {
	my ($file, @filters) = @_;
    my @S = ref $file? @$file: $file;
    
}

# 
sub noenter(&@) {

}

# 
sub exec(&@) {

}

# Производит замену во всех файлах
sub replace(&@) {
    my $fn = shift;
    local $_;
    for my $path (@_) {
        my $file = $_ = read $path;
        $fn->($path);
        write $path, $_ if $file ne $_;
    }
}

# Открывает файл на указанной строке в редакторе
sub goto_editor($$) {
	my ($path, $line) = @_;
	my $p = $main_config::editor;
	$p =~ s!%p!$path!;
	$p =~ s!%l!$line!;
	my $status = system $p;
	die "$path:$line\n\n$status) $?" if $status;
	return;
}

1;
