# -*- cperl -*-
use strict;
use warnings;
use 5.010;

use Test::More;   # see done_testing()
use Test::Differences;
use YAML::PP qw/LoadFile/;
use Dpkg::Copyright::Grant::ByFile;
use Path::Tiny;
use Log::Log4perl 1.11 qw(:easy :levels);

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

require_ok( 'Dpkg::Copyright::Scanner' );

Log::Log4perl->easy_init( $ERROR );

my $filter = shift @ARGV;

# __pack_copyright tests
my $tests = LoadFile("t/grant/squash_copyright_years.yml");

foreach my $t ($tests->@*) {

    next if $filter and $t->{name} !~ /$filter/;

    subtest $t->{name} => sub {
        my $grant  = Dpkg::Copyright::Grant::ByFile->new( current_dir => path('.'));

        my %expect ;
        my $file = 'dummy01';
        foreach my $t_data ($t->{test}->@*) {
            my ($in, $lic, $out) = $t_data->@*;
            $expect{$file} = [ $lic, $out // $in ];
            $grant->add($file++, $lic, $in);
        }

        $grant->squash_copyright_years;

        # check coaslesced entries
        foreach my $file (sort keys %expect) {
            my $g = $grant->get_grant($file);
            my ($lic, $str) = $expect{$file}->@*;
            is($g->license,$lic, "check $file license");
            is($g->copyright."", $str, "check $file copyright string");
        } ;
    };
}


done_testing();
