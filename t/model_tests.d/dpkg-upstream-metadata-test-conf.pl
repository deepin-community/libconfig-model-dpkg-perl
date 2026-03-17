use strict;
use warnings;

my $conf_file_name = "metadata";

my $conf_dir       = 'debian/upstream';
my $model_to_test  = "Dpkg::Upstream::Metadata";

my @tests = (
    {
        name => 'from-dep12-ex1',
        backend_arg => $conf_file_name,
        check => {
            Documentation => 'https://eradman.com/entrproject/entr.1.html'
        }
    },
    {
        name => 'from-dep12-ex2',
        backend_arg => $conf_file_name,
        check => {
            'Reference:0 Author' => qr/Bienayme/,
        }
    },
    {
        name => 'debian-1129472',
        backend_arg => $conf_file_name,
        check => {
            'Registry:0 Entry' => 'r-gsignal'
        }
    },
);

return {
    conf_file_name => $conf_file_name,
    conf_dir => $conf_dir,
    tests => \@tests,
};
