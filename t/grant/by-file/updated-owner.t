use 5.20.0;
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(utf8)';

use Test::More;
use Test::Differences;
use Test::Synopsis::Expectation;
use Software::Copyright::Statement;
use Path::Tiny;

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

require_ok('Dpkg::Copyright::Grant::ByFile::UpdatedOwner');

sub check ($owner, $str, $o_ref, $new_str, $record_year, $modified_ref = []) {
    my $st = new_st($str);
    my @modified = $owner->update_statement_if_more_recent($st);
    is_deeply(\@modified, $modified_ref,"check modified hashes after $str");
    for (my $i=0; $i < $owner->statement->@*; $i++) {
        is(
            $owner->statement->[$i].'',
            $o_ref->[$i],
            "check maybe updated owner statement ". $owner->statement->[$i]
        );
    }
    is($st.'', $new_str, "check maybe updated statement ". $str);
    is($owner->year, $record_year, "check record year $record_year");
}

sub new_st($str) {
    return Software::Copyright::Statement->new($str);
}

subtest "add email" => sub {
    my $owner = Dpkg::Copyright::Grant::ByFile::UpdatedOwner->new();

    $owner->add('hash1', new_st('2012 Marcel'));
    $owner->add('hash2', new_st('2013 Marcel'));

    #             new info
    #                   records
    # updated new info
    # record_year
    check(
        $owner,
        '2013 Marcel',                       # new_info
        ['2012, Marcel','2013, Marcel'],     # records
        '2013, Marcel',                      # updated new info
        # because no email
        0                                    # record year
    );
    check(
        $owner,
        'Marcel <bogus@m.e>',
        ['2012, Marcel <bogus@m.e>','2013, Marcel <bogus@m.e>'],
        'Marcel <bogus@m.e>',
        0,
        [qw/hash1 hash2/]  # modified hashes
    );
    check(
        $owner,
        '2014 Marcel <m@e.com>',
        ['2012, Marcel <m@e.com>', '2013, Marcel <m@e.com>'],
        '2014, Marcel <m@e.com>',
        2014,
        [qw/hash1 hash2/]  # modified hashes
    );
    check(
        $owner,
        '2012 Marcel <m-old@e.com>',
        ['2012, Marcel <m@e.com>', '2013, Marcel <m@e.com>'],
        '2012, Marcel <m@e.com>',
        2014
    );

    # this is the corner case that may cause trouble: same year, 2 email addresses
    # we arbitrarily don't update the record in this case and the original record should be left as is.
    check(
        $owner,
        '2014 Marcel <m2@e.com>',
        ['2012, Marcel <m@e.com>', '2013, Marcel <m@e.com>'],
        '2014, Marcel <m2@e.com>',
        2014
    );
};

done_testing;
