use 5.20.0;
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(utf8)';

use Test::More;
use Test::Differences;
use Test::Exception;
use Test::Synopsis::Expectation;
use Unicode::Normalize;
use Software::Copyright;
use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;


# synopsis_ok('lib/Dpkg/Copyright/FileGrant.pm');

require_ok('Dpkg::Copyright::Grant::Plain');

sub new_gp ($c,$l,$comment = '', $lt = '') {
    return Dpkg::Copyright::Grant::Plain->new(
        copyright => $c,
        license => $l,
        comment => $comment,
        license_text => $lt,
    );
}

subtest "cleanup copyright function" => sub {
    my $clean = sub {Dpkg::Copyright::Grant::Plain::_cleanup_copyright(@_)};
    my @tests = (
        ["unknown", ''],
        ["no-info-found", ''],
        ["2022 Joe"],
        # cleanup copyright word and (c) as well
        ['Copyright © (c) (C) 2012-2015, Jonathan Worthington','2012-2015, Jonathan Worthington'],
        ['Copyright Aubrey Jaffer and copyright Heng Yuan.', 'Aubrey Jaffer and Heng Yuan.'],
        # leave nonsense alone
        ['protection under copyright law or other applicable laws.'],
        ["2007, THE PACKAGE'S COPYRIGHT HOLDER"],
        # cleanup \n
        ["Copyright © 2012-2015, Jonathan Worthington\n",'2012-2015, Jonathan Worthington'],
        ["\n\nCopyright © 2012-2015, Jonathan Worthington\n",'2012-2015, Jonathan Worthington'],
    );

    foreach my $test (@tests) {
        is($clean->($test->[0]), $test->[1] // $test->[0], "clean up '$test->[0]'");
    }
};

subtest "cleanup license on creation" => sub {
    my @tests = (
        ['Copyright © 2012-2015, Jonathan Worthington','Artistic-2.0', "2012-2015, Jonathan Worthington"],
        ["\@copyright{} 2001--2023 Free Software Foundation, Inc.",'GFDL-1.3+', '2001-2023, Free Software Foundation, Inc.']
    );

    foreach my $test (@tests) {
        my $grant = new_gp($test->@[0,1]);
        is($grant->copyright().'', $test->[2], "check copyright cleanup on construction");
    }
};

subtest "cleanup license on creation or modification" => sub {
    # creation
    my $grant = new_gp('2014,2015-2022 Marcel <marcel@example.com>','MIT or notMIT');
    is($grant->license(), "Expat or notMIT", "check Expat license cleanup on construction");
    $grant->license("MIT or apache");

    # modification
    is($grant->license(), "Expat or apache", "check Expat license cleanup on set");
    is($grant.'', 'Expat or apache / 2014-2022, Marcel <marcel@example.com>', 'check stringify');
};

subtest "check has_info" => sub {
    my $good_c = '2014,2015-2022 Marcel <marcel@example.com>';
    my $good_l = 'MIT or notMIT';
    my $empty_c = 'no-info-found';
    my $empty_l = 'unknown';

    is ( new_gp($good_c,$good_l)->has_info,1,"check has_info 1");
    is ( new_gp($empty_c,$good_l)->has_info,1,"check has_info 2");
    is ( new_gp($good_c,$empty_l)->has_info,1,"check has_info 3");
    is ( new_gp($empty_c,$empty_l)->has_info,0,"check has_info 4");
};

subtest "many license cleanup" => sub {
    my @tests = (
        gpl_1                     => 'GPL-1',
        lgpl_1                    => 'LGPL-1',
        'GPL-1+ and/or GPL-1'     => 'GPL-1+',
        'GPL-2+ or GPL-2'         => 'GPL-2+',
        'GPL-2 or GPL-2+'         => 'GPL-2+',
        'LGPL-2.1-only'           => 'LGPL-2.1',
        'LGPL-2.1-or-later'       => 'LGPL-2.1+',
        'GPL-3.0'                 => 'GPL-3',
        'LGPL-3 or LGPL-3.0-only' => 'LGPL-3',
        'GPL-3.0-only or GPL-3'   => 'GPL-3',
        'GPL-3.0-only or LGPL-3'  => 'GPL-3 or LGPL-3',
        'Artistic or GPL-2-only'  => 'Artistic-1.0 or GPL-2',
        'Apache-2.0 and/or BSL-1.0' => 'Apache-2.0 or BSL-1.0',
        'Apache-2.0 and/or BSL-1.0 or Apache-2.0 or BSL-1.0' => 'Apache-2.0 or BSL-1.0',
        'UNKNOWN'                 => '',
        'Perl'                    => 'Artistic-1.0 or GPL-1+',
        'Perl5'                    => 'Artistic-1.0 or GPL-1+',
        'Perl.5'                    => 'Artistic-1.0 or GPL-1+',
        'Perl_5'                    => 'Artistic-1.0 or GPL-1+',
    );

    while (@tests) {
        my ($in,$expect) = splice @tests, 0, 2;
        my $grant = new_gp('2014,2015-2022 Marcel <marcel@example.com>', $in);
        eq_or_diff($grant->license,$expect,"cleanup license '$in'");
    }

};

subtest "check utf8 hash" => sub{
    my $lic = "GPL-1";
    my @tests = (
        [ 'Marcel' => 'bd75e28dcb7726bf4725290b5483951bac97e072' ],
        [ 'Mélodie' => 'd8009bc6506d6bb6028a806e2dc76ce1e5e9a38f' ],
        [ 'Marcel' => comment => '505d572f974f2e26d7422cd42bcc9f0b9aad3bd5' ],
        [ 'Marcel' => comment => lic_text => 'e7a2857212c03bd601b73bbb103d67472bae7dce' ],
    );

    foreach my $test (@tests) {
        my $expect = pop $test->@*;
        my $in = shift $test->@*;
        my $grant = new_gp("2014,2015-2022 $in", $lic, $test->@* );
        my $str = "check hash license '$in'";
        $str .= "with ".join(' ',$test->@*) if $test->@*;
        eq_or_diff($grant->hash,$expect,$str) ;
    }
};

subtest "overload %{}" => sub {
    my ($c, $l) = ('Marcel', 'GPL-2');
    my $grant = new_gp($c,$l);
    my $struct = {
        Copyright => $c,
        License => { short_name => $l},
    };

    is_deeply({ $grant->%* } , $struct, "check structure");
    ok($grant eq $struct, "check equal");
    ok($struct eq $grant, "check reverse equal");
};

subtest "overload %{} with comment and license_text" => sub {
    my ($c, $l) = ('Marcel', 'GPL-2');
    my $grant = new_gp($c,$l);
    $grant->comment("blah");
    $grant->license_text("blah license");
    my $struct = {
        Copyright => $c,
        License => { short_name => $l, license_text => "blah license"},
        comment => "blah",
    };

    is_deeply({ $grant->%* } , $struct, "check structure");
    ok($grant eq $struct, "check equal");
    ok($struct eq $grant, "check reverse equal");
};

subtest "merge plain grants" => sub {
    my $grant = new_gp('2015, Marcel', 'GPL-2');

    $grant->merge($grant);
    is($grant->copyright.'', '2015, Marcel', "check self merge Copyright");
    is($grant->license.'', 'GPL-2', "check self merge License");

    $grant->merge(new_gp('2016, Yves', "UNKNOWN"));
    is($grant->copyright.'', "2016, Yves\n2015, Marcel", "check merge Copyright with unknown license");
    is($grant->license.'', 'GPL-2', "check merge unknown License");

    $grant->merge(new_gp('2017, Yves', "Artistic"));
    is($grant->copyright.'', "2016, 2017, Yves\n2015, Marcel", "check merge Copyright");
    is($grant->license.'', 'Artistic-1.0 or GPL-2', "check merge License");

    $grant->merge(new_gp('2017, Alex', "Artistic-2.0"));
    is($grant->copyright.'', "2017, Alex\n2016, 2017, Yves\n2015, Marcel", "check merge again Copyright");
    is($grant->license.'', 'Artistic-1.0 or Artistic-2.0 or GPL-2', "check merge again License");

    $grant->merge(new_gp('2017, Alex', "Artistic-2.0",'some comment'));
    is($grant->copyright.'', "2017, Alex\n2016, 2017, Yves\n2015, Marcel", "check merge again Copyright and comment");
    is($grant->comment.'', "some comment", "check merge comment");
    is($grant->license.'', 'Artistic-1.0 or Artistic-2.0 or GPL-2', "check merge again License and comment");

    throws_ok {
        $grant->merge(new_gp('2017, Alex', "Artistic-2.0",'another comment'));
    } qr/cannot clobber comment/;
};

subtest "merge plain grants with and/or statement" => sub {
    my $grant = new_gp('2015, Marcel', 'BSD-3-clause and/or Expat');

    $grant->merge($grant);
    is($grant->copyright.'', '2015, Marcel', "check self merge Copyright");
    is($grant->license.'', 'BSD-3-clause or Expat', "check self merge License");
};

subtest "cloned grant" => sub {
    my $grant = new_gp('2015, Marcel', 'GPL-2');
    my $clone = $grant->clone;

    is($clone->copyright.'', '2015, Marcel', "check self merge Copyright");
    is($clone->license.'', 'GPL-2', "check self merge License");

    $grant->merge(new_gp('2016, Yves', "Artistic"));

    # check that cloned object is not modified by the merge above
    is($clone->copyright.'', '2015, Marcel', "check self merge Copyright");
    is($clone->license.'', 'GPL-2', "check self merge License");
};

subtest "clone grant with additional info" => sub {
    my $grant = new_gp('2015, Marcel', 'GPL-2', 'blah','lic blah');
    my $clone = $grant->clone;

    is($clone->copyright.'', '2015, Marcel', "check self merge Copyright");
    is($clone->license.'', 'GPL-2', "check self merge License");
    is($clone->license_text, 'lic blah', "check self merge License text");
    is($clone->comment.'', 'blah', "check self merge comment");
};

subtest "grant contains another" => sub {
    my $grant = new_gp('2015-2020, Marcel', 'GPL-2');

    my @tests = (
        ['2014, Marcel', 'GPL-2', 0 ,0 ],
        ['2015, Marcel', 'GPL-2', 1 ,0 ],
        ['2015, Marcel', '', 1, 0 ],
        ['2015, Marcel', 'GPL-2', 'comment', 0 , 0],
        ['2015, Marcel', 'GPL-2', '', 1 , 0],
        ['2015, Marcel', 'GPL-2', '', 'lic_text', 0, 0 ],
        ['2015-2019, Marcel', 'GPL-2', 1, 0 ],
        ['2015-2019, Marcel', 'GPL-3', 0, 0 ],
        ['2015-2019, Yves', 'GPL-2', 0, 0 ],
        ['','',1,0]
    );

    foreach my $t (@tests) {
        my $swapped_expect = pop $t->@*;
        my $expect = pop $t->@*;
        is($grant->contains(new_gp($t->@*)), $expect, "check @$t");
        is(new_gp($t->@*)->contains($grant), $swapped_expect, "check swapped @$t");
    }
};

subtest "Debian info" => sub {
    my $grant = new_gp('2015-2020, Marcel', 'GPL-2');
    is($grant->comment, '', "test that no comment is fine");
    my $hash = $grant->hash;

    $grant->comment('blah');
    is($grant->comment, 'blah', "test comment");
    my $hash2 = $grant->hash;
    isnt($hash2, $hash,"check hash update after comment");

    $grant->license_text('blah-blah');
    is($grant->license_text, 'blah-blah', "test license text");
    isnt($grant->hash, $hash2,"check hash update after license_text");
};

subtest "merge_old_grant: check comment and license" => sub {
    my $old_grant = new_gp('2015-2020, Marcel', 'GPL-2');
    my $new_grant = $old_grant->clone;
    $old_grant->comment('blah');
    $old_grant->license_text('blah-blah');

    $new_grant->merge_old_grant($old_grant);

    is($new_grant->comment, 'blah', "test comment merge_old_grant");
    is($new_grant->license_text, 'blah-blah', "test license text merge_old_grant");

    $old_grant->comment('blah blah');
    is($new_grant->comment, 'blah', "test comment merge_old_grant does not clobber");
};

subtest "merge_old_grant with missing info" => sub {
    my $old_grant = new_gp('', '');

    $old_grant->merge_old_grant(new_gp('2015-2020, Marcel', ''));

    is($old_grant.'', '2015-2020, Marcel', "test copyright merge_old_grant");

    $old_grant->merge_old_grant(new_gp('2015-2020, Marcel', 'GPL-2'));

    is($old_grant.'', 'GPL-2 / 2015-2020, Marcel', "test license merge_old_grant");
};

done_testing;
