# -*- cperl -*-
use strict;
use warnings;
use 5.020;

use Test::More;   # see done_testing()
use Path::Tiny;
use Test::File::Contents;
use Config::Model::Tester::Setup qw/init_test setup_test_dir/;
use Getopt::Long;

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

use Dpkg::Copyright::Scanner qw/generate_copyright/;

sub check_output ($in, $out_file, $test_name, $fix, $long = 0) {
    my %from = $in->is_dir ? ( from_dir => $in ) : ( in => $in );
    my $out_text = generate_copyright( %from , quiet => 1, long => $long);

    my $success = file_contents_eq_or_diff($out_file, $out_text, { encoding => 'UTF-8' }, "check $test_name copyright");

    if ($fix and not $success) {
        print "Fix $test_name output ? (yes/no/quit) ";
        my $answer = <STDIN>;
        if ($answer =~ /^q/i) {
            exit 0;
        }
        if ($answer =~ /^y/i) {
            $out_file->spew_utf8($out_text);
        }
    }
}

my ($model, $trace, $options) = init_test("fix");

# global tests
my $dir = path('t/scanner/examples/') ;
my $suffix_re = qr/\.(in|d)$/;

foreach my $in (sort $dir->children($suffix_re)) {
    my $test_name = $in->basename($suffix_re);
    next if @ARGV and not grep { $test_name =~ /$_/; } @ARGV;
    note("scanning $test_name");

    my $out_file_name =  $test_name. '.out';
    my $out_file = $dir->child($out_file_name);
    if (not $out_file->exists) {
        # avoids breaking the test when creating a new test case
        $out_file->spew('');
    }

    check_output($in, $out_file, "$in short", $options->{fix}) ;

    my $long_out_file = $dir->child($test_name. '-long.out');
    if ($long_out_file->exists) {
        check_output($in, $long_out_file, "$in long", $options->{fix}, 1) ;
    }
}


done_testing();
