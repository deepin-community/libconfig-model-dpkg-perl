use 5.020;

use Test::More;                 # see done_testing()
use Test::Differences;

require_ok( 'Dpkg::Copyright::Scanner' );

my $copyrights_by_id = [
    undef,
    {
        Copyright => 'Perl 6 community
2017, Ronald Schmidt.
2015, Raku Community Authors',
        License => {
            short_name => 'Artistic-2.0'
        },
    },
    {
        Copyright => 'Perl 6 community',
        License => {
            short_name => 'Artistic-2.0'
        },
    },
    {
        Copyright => '2017, Ronald Schmidt.
2015, Raku Community Authors',
        License => {
            short_name => 'Artistic-2.0'
        },
    },
];

my $main_info = {
    2 => 1,
    3 => 1
};

is(Dpkg::Copyright::Scanner::__find_main_license_id($copyrights_by_id, $main_info), 1 , "redundant owner detected");

done_testing();
