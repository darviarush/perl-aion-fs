requires 'perl', '5.22.0';

on 'develop' => sub {
    requires 'Minilla', 'v3.1.19';
    requires 'Data::Printer', '1.000004';
    requires 'Liveman', '1.0';
};

on 'test' => sub {
    requires 'Test::More', '0.98';

    requires 'Carp';
    requires 'common::sense';
    requires 'File::Basename';
    requires 'File::Path';
    requires 'File::Slurper';
    requires 'File::Spec';
    requires 'Scalar::Util';
};

requires 'common::sense', '0';
requires 'config', '1.3';
requires 'constant', '1.33';
requires 'diagnostics', '0';
requires 'feature', '0';
requires 'strict', '0';
requires 'warnings', '1.70';
requires 'Exporter', '5.78';
requires 'File::Glob', '0';
requires 'File::Spec', '0';
requires 'File::Spec::Unix', '3.91';
requires 'List::Util', '1.63';
requires 'Scalar::Util', '0';
requires 'Time::HiRes', '0';
