requires 'perl', '5.008001';

on 'develop' => sub {
    requires 'Minilla', 'v3.1.19';
    requires 'Data::Printer', '1.000004';
};

on 'test' => sub {
	requires 'Test::More', '0.98';
};

requires 'common::sense', '0';
