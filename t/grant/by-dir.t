use 5.20.0;
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(utf8)';

use Test::More;
use Test::Differences;
use Test::Synopsis::Expectation;
use Dpkg::Copyright::Grant::ByFile;
use Dpkg::Copyright::Grant::Plain;
use Path::Tiny;
use Log::Log4perl 1.11 qw(:easy :levels);
use YAML::PP;

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

require_ok('Dpkg::Copyright::Grant::ByDir');

Log::Log4perl->easy_init( $ERROR );

sub get_grant (%args) {
    return Dpkg::Copyright::Grant::ByFile->new(current_dir => path('.'), %args);
}

sub get_dir_grant (%args) {
    return Dpkg::Copyright::Grant::ByDir->new(current_dir => path('.'), %args);
}

subtest "add files" => sub {
    my $grants = get_grant();

    $grants->add ('marcel.txt', 'GPL-2', '2012, Marcel');
    $grants->add ('marcel2.txt', 'GPL-2', '2015, Marcel <marcel@example.com>');
    $grants->add ('foo/marcel.txt', 'GPL-2', '2015, Marcel Foo <marcel.foo@example.com>');
    $grants->add ('foo/bar/marcel.txt', 'GPL-2', '2015, Marcel FooBar <marcel.foobar@example.com>');
    $grants->add ('t/test1.t', 'GPL-2', '2015, Marcel FooBar <marcel.foobar@example.com>');
    $grants->add ('./t/test2.t', 'GPL-2', '2015, Marcel FooBar <marcel.foobar@example.com>');

    my $dir = get_dir_grant();

    $dir->add_all_grants($grants);

    # check that marcel2.txt has email info
    is($dir->grants->get_grant('marcel2.txt')->copyright->statement('Marcel')->email,'marcel@example.com',"check marcel2 grant");

    is($dir->grants->get_grant('marcel.txt')->copyright->statement('Marcel')->email,'marcel@example.com',"check marcel grant");

    # check that the same dir object can be accessed with Debian paths
    for my $subdir (qw!foo foo/ foo/*!) {
        is(
            $dir->get_dir($subdir)->grants->get_grant('marcel.txt')->copyright->statement('Marcel Foo')->email,
            'marcel.foo@example.com',
            "check marcel foo grant via $subdir"
        );
    }

    is(
        $dir->get_dir('foo')->get_dir('bar')->get_grant('marcel.txt').'',
        'GPL-2 / 2015, Marcel FooBar <marcel.foobar@example.com>',
        "check get_dir(foo) and git_dir(bar) grant"
    );
    is(
        $dir->get_dir('foo/bar')->get_grant('marcel.txt').'',
        'GPL-2 / 2015, Marcel FooBar <marcel.foobar@example.com>',
        "check getdir(foo/bar) grant"
    );

    foreach my $t_file (qw/test1.t test2.t/) {
        is(
            $dir->get_grant("t/$t_file").'',
            'GPL-2 / 2015, Marcel FooBar <marcel.foobar@example.com>',
            "check get_grant of t/$t_file"
        );
    }

    is ($dir->get_dir('foo')->current_dir, 'foo', "check sub dir");

    is ($dir->get_dir('*')->current_dir, '.', "check get_dir(*)");

    is(
        $dir->get_dir('foo')->get_dir('bar')->grants->get_grant('marcel.txt')->copyright->statement('Marcel FooBar')->email,
        'marcel.foobar@example.com',
        "check marcel foobar grant"
    );

    ok($dir->has_dir('.'),"check has_dir .");
    ok($dir->has_dir('foo'),"check has_dir foo");
    ok($dir->has_dir('foo/bar'),"check has_dir foo/bar");
    ok(!$dir->has_dir('baz'),"check has_dir baz (not)");
    ok(!$dir->has_dir('foo/baz'),"check has_dir foo/baz (not)");
};

sub init_main_files () {
    my $grants = get_grant();
    $grants->add('LICENSE', 'Artistic-2.0', '2015, Jonathan Stowe');
    $grants->add('README.md', 'UNKNOWN', '2015-2021, Jonathan Stowe');
    $grants->add('META6.json', 'Artistic-2.0', 'Jonathan Stowe <jns+git@gellyfish.co.uk>');
    $grants->add('foo.pl', 'Artistic-2.0', 'Jonathan Stowe <jns+git@gellyfish.co.uk>');

    return get_dir_grant()->add_all_grants($grants);
}

subtest "find main files" => sub {
    my $dir = init_main_files();
    eq_or_diff([sort $dir->find_main_files], [qw/LICENSE META6.json README.md/], "main main files")
};

subtest "find main license" => sub {
    my $dir = init_main_files();
    my $main_grant = $dir->find_main_grant_from_main_files();
    is($main_grant->copyright.'', '2015-2021, Jonathan Stowe <jns+git@gellyfish.co.uk>', "main copyright");
    is($main_grant->license,"Artistic-2.0","main license");
};

subtest "find main license from files - one directory" => sub{
    my $grants = get_grant();
    $grants->add('foo1.c', 'Artistic-2.0', '2014, Jonathan Stowe');
    $grants->add('foo2.c', 'Artistic-2.0', '2015, Jonathan Stowe');
    $grants->add('bar.c', 'GPL-2', '2016, Marcel');

    my $dir = get_dir_grant()->add_all_grants($grants);

    # main grant coaslesces the copyright years of the main file
    is($dir->main_grant.'', 'Artistic-2.0 / 2014, 2015, Jonathan Stowe', "find main grant");

    is($dir->main_grant_weight, 2, "check main grant weight");

    # check that file grant is left intact
    is($dir->get_grant('foo1.c').'', 'Artistic-2.0 / 2014, Jonathan Stowe', "check file grant is not modified")
};

sub grant_with_foo_bar() {
    my $grants = get_grant();
    $grants->add('foo/foo1.c', 'Artistic-2.0', '2014, Jonathan Stowe');
    $grants->add('foo/foo2.c', 'Artistic-2.0', '2015, Jonathan Stowe');
    $grants->add('bar/bar1.c', 'GPL-2', '2016, Marcel');
    $grants->add('bar/bar2.c', 'GPL-2', '2017, Marcel');
    $grants->add('baz/baz1.c', 'GPL-2', '2018, Marcel');
    $grants->add('baz/baz2.c', 'GPL-2', '2017, Marcel');
    return $grants;
}

subtest "find main license from files - several directories" => sub{
    my $grants = grant_with_foo_bar();
    $grants->add('baz/baz3.c', 'GPL-2', '2017, Marcel');
    for my $i (1..4) {
        $grants->add("nada/nada$i.c", '', '');
    }

    my $main_dir = get_dir_grant()->add_all_grants($grants);
    # actually, there's a tie between foo and bar directory. The
    # actual main grant is not predicatable because of this tie, but
    # is stays the same.
    is($main_dir->main_grant.'', 'GPL-2 / 2016-2018, Marcel', "find main grant");

    is($main_dir->get_dir('foo')->main_grant.'',  'Artistic-2.0 / 2014, 2015, Jonathan Stowe', "find foo main grant");
    is($main_dir->get_dir('bar')->main_grant.'',  'GPL-2 / 2016, 2017, Marcel', "find bar main grant");
    is($main_dir->get_dir('baz')->main_grant.'',  'GPL-2 / 2017, 2018, Marcel', "find baz main grant");
    is($main_dir->get_dir('nada')->main_grant.'',  '', "find nada main grant");

    is($main_dir->get_dir('foo')->main_grant_weight, 2, "check foo main grant weight");
    is($main_dir->get_dir('bar')->main_grant_weight, 2, "check bar main grant weight");
    is($main_dir->get_dir('baz')->main_grant_weight, 3, "check baz main grant weight");
    is($main_dir->get_dir('nada')->main_grant_weight, 4, "check nada main grant weight");

    is($main_dir->main_grant_weight, 5, "check main grant weight");
};

subtest "find main license from files - several directories and a file" => sub{
    my $grants = grant_with_foo_bar();
    $grants->add ('marcel2.txt', 'GPL-2', '2015, Marcel');

    my $main_dir = get_dir_grant()->add_all_grants($grants);

    # actually, there's a tie between foo and bar directory. The
    # actual main grant is not predictable because of this tie, but
    # is stays the same.
    is($main_dir->main_grant.'', 'GPL-2 / 2015-2018, Marcel', "find main grant");

    is($main_dir->get_dir('foo')->main_grant.'',  'Artistic-2.0 / 2014, 2015, Jonathan Stowe', "find foo main grant");
    is($main_dir->get_dir('bar')->main_grant.'',  'GPL-2 / 2016, 2017, Marcel', "find bar main grant");

    is($main_dir->get_dir('foo')->main_grant_weight, 2, "check foo main grant weight");
    is($main_dir->get_dir('bar')->main_grant_weight, 2, "check bar main grant weight");
    is($main_dir->get_dir('baz')->main_grant_weight, 2, "check baz main grant weight");
    is($main_dir->main_grant_weight, 5, "check main grant weight");
};

subtest "find main license from files - several directories and main file" => sub{
    my $grants = grant_with_foo_bar();
    $grants->add('LICENSE', 'Artistic-2.0', '2014, Jonathan Stowe');
    $grants->add('README.md', 'UNKNOWN', '2015-2017, Jonathan Stowe');
    $grants->add('foo/foo3.c', 'Artistic-2.0', '2018, Jonathan Stowe');
    $grants->add('baz1.c', 'GPL-2', '2018, Marcel');
    $grants->add('baz2.c', 'GPL-2', '2018, Marcel');

    my $main_dir = get_dir_grant()->add_all_grants($grants);

    # Marcel has more files than Jonathan
    is($main_dir->find_main_grant_from_files.'', 'GPL-2 / 2016-2018, Marcel', "find main grant from files");

    # Jonathan and some files and README
    is($main_dir->find_main_grant_from_main_files.'', 'Artistic-2.0 / 2014-2017, Jonathan Stowe', "find main grant from main files");

    # But Jonathan has README and LICENSE which supersedes Marcel
    # main grant combines the years of all Jonathan files
    is($main_dir->main_grant.'', 'Artistic-2.0 / 2014-2018, Jonathan Stowe', "find main grant");

    is($main_dir->get_dir('foo')->main_grant.'',  'Artistic-2.0 / 2014, 2015, 2018, Jonathan Stowe', "find foo main grant");
    is($main_dir->get_dir('bar')->main_grant.'',  'GPL-2 / 2016, 2017, Marcel', "find bar main grant");

    is($main_dir->get_dir('foo')->main_grant_weight, 3, "check foo main grant weight");
    is($main_dir->get_dir('bar')->main_grant_weight, 2, "check bar main grant weight");
    is($main_dir->get_dir('baz')->main_grant_weight, 2, "check baz main grant weight");
    is($main_dir->main_grant_weight, 4, "check main grant weight");
};

subtest "dir with many files trumps some files at top" => sub {
    my $grants = grant_with_foo_bar();
    foreach my $i (3..6) {
        $grants->add("bar/bar$i.c", 'GPL-2', '2017, Marcel');
    }
    $grants->add('foo/foo3.c', 'Artistic-2.0', '2015, Jonathan Stowe');

    my $main_dir = get_dir_grant()->add_all_grants($grants);

    is($main_dir->main_grant.'', 'GPL-2 / 2016-2018, Marcel', "find main grant");

    is($main_dir->get_dir('foo')->main_grant_weight, 3, "check foo main grant weight");
    is($main_dir->get_dir('bar')->main_grant_weight, 6, "check bar main grant weight");
    is($main_dir->get_dir('baz')->main_grant_weight, 2, "check baz main grant weight");
    is($main_dir->main_grant_weight, 8, "check main grant weight");
};

subtest "dir with main files in sub-directories" => sub {
    my $grants = get_grant();
    my $str = <<'EOL';
Artistic2.txt	Artistic-2.0	2000-2006 The Perl Foundation.
LICENSE	UNKNOWN	2012-2015 Jonathan Worthington and others.
tools/update-submodules.pl	UNKNOWN	2009-2019 The Perl Foundation
3rdparty/cmp/LICENSE	Expat	2014 Charles Gunyon
3rdparty/cmp/cmp.c	Expat	2017 Charles Gunyon
3rdparty/cmp/cmp.h	Expat	2017 Charles Gunyon
3rdparty/dynasm/COPYRIGHT	Expat	2005-2014 Mike Pall.
3rdparty/dynasm/dasm_arm.h	Expat	2005-2015 Mike Pall.
3rdparty/dynasm/dasm_ppc.h	Expat	2005-2015 Mike Pall.
3rdparty/dynasm/dasm_x64.lua	Expat	2005-2015 Mike Pall.
3rdparty/dynasm/minilua.c	Expat	1994-2012 Lua.org, PUC-Rio.
EOL
    add_all($grants, $str);

    my $dir = get_dir_grant()->add_all_grants($grants);

    my @tests = (
        # dir is empty and dirs belows have main file -> no main grant
        [ "" => '2012-2015, Jonathan Worthington and others.', 1, 0 ],
        [ "3rdparty" => '', 0, undef ],
        [ "3rdparty/cmp" => 'Expat / 2014, 2017, Charles Gunyon', 3,0 ],
        [ "3rdparty/dynasm" => 'Expat / 2005-2015, Mike Pall.', 4,0 ],
        [ "tools" => '2009-2019, The Perl Foundation',1,1],
    );

    foreach my $t (@tests) {
        my ($comp, $grant, $weight, $file_type) = $t->@*;
        my $item =  $dir->get_dir($comp);
        is($item->main_grant.'' ,$grant,"check $comp main grant");
        is($item->main_grant_weight,$weight,"check $comp main grant weight");
        is($item->main_grant_is_type_file,$file_type,"check $comp main grant type");
    }
};

subtest "debian_full_data - normal output" => sub {
    my $grants = grant_with_foo_bar();
    my $dir = get_dir_grant()->add_all_grants($grants);

    my $expect = [
        {
            Copyright => '2016-2018, Marcel',
            Files => '*',
            License => {
                short_name => 'GPL-2'
            }
        },
        {
            Copyright => '2014, 2015, Jonathan Stowe',
            Files => 'foo/*',
            License => {
                short_name => 'Artistic-2.0'
            }
        }
    ] ;
    my @got = $dir->debian_full_data();
    eq_or_diff(\@got, $expect, "data output");
};

subtest "debian_full_data - long output" => sub {
    my $grants = get_grant();
    $grants->add('foo/foo1.c', 'Artistic-2.0', '2014, Jonathan Stowe');
    $grants->add('foo/foo2.c', 'Artistic-2.0', '2014, Jonathan Stowe');
    $grants->add('bar/bar1.c', 'GPL-2', '2016, Marcel');
    $grants->add('bar/bar2.c', 'GPL-2', '2016, Marcel');
    $grants->add('baz/baz1.c', 'GPL-2', '2017, Marcel');
    $grants->add('baz/baz2.c', 'GPL-2', '2017, Marcel');

    my $dir = get_dir_grant()->add_all_grants($grants);

    my $expect = [
        {
            Copyright => '2016, Marcel',
            Files => "bar/bar1.c\nbar/bar2.c",
            License => {
                short_name => 'GPL-2'
            }
        },
        {
            Copyright => '2017, Marcel',
            Files => "baz/baz1.c\nbaz/baz2.c",
            License => {
                short_name => 'GPL-2'
            }
        },
        {
            Copyright => '2014, Jonathan Stowe',
            Files => "foo/foo1.c\nfoo/foo2.c",
            License => {
                short_name => 'Artistic-2.0'
            }
        }
    ] ;

    my @got = $dir->debian_full_data(long => 1);
    eq_or_diff(\@got, $expect, "data output");
};

subtest "debian_record" => sub {
    my $grants = get_grant();

    $grants->add ('marcel2.txt', 'GPL-2', '2015, Marcel <marcel@example.com>');
    my $dir = get_dir_grant()->add_all_grants($grants);

    is($dir->main_grant.'',  'GPL-2 / 2015, Marcel <marcel@example.com>', "find main grant");
    my $expect_str = <<"EOR";
Files: marcel2.txt
Copyright: 2015, Marcel <marcel\@example.com>
License: GPL-2
EOR
    eq_or_diff($dir->debian_record($grants->get_grant('marcel2.txt')->hash), $expect_str, "check file");

    my $expect_str_dir = <<"EOR";
Files: *
Copyright: 2015, Marcel <marcel\@example.com>
License: GPL-2
EOR
    eq_or_diff($dir->debian_record(), $expect_str_dir, "check dir");

    $dir->add_grant_info(file => 'marcel2.txt', license_text => "lic text");
    $dir->add_grant_info(file => 'marcel2.txt', comment => "some comment");

    my $expect_data = {
        Comment => 'some comment',
        Copyright => '2015, Marcel <marcel@example.com>',
        Files => 'marcel2.txt',
        License => {
            full_license => 'lic text',
            short_name => 'GPL-2'
        }
    };
    eq_or_diff($dir->debian_data(hash => $dir->get_grant('marcel2.txt')->hash), $expect_data, "data output");
    $expect_str .= " lic text\nComment: some comment\n";
    eq_or_diff($dir->debian_record($dir->get_grant('marcel2.txt')->hash), $expect_str, "check file with comment");
};

subtest "debian_record - files in sub dir" => sub {
    my $grants = grant_with_foo_bar();

    $grants->add ('marcel2.txt', 'GPL-2', '2019, Marcel');
    $grants->add ('marcel3.txt', 'GPL-2', '');
    $grants->add('bar/bar3.c', 'GPL-2', '2015, Yves');
    my $dir = get_dir_grant()->add_all_grants($grants);

    my $expect = <<"EOR";
Files: marcel2.txt
Copyright: 2019, Marcel
License: GPL-2
EOR
    eq_or_diff(
        $dir->debian_record($grants->get_grant('marcel2.txt')->hash),
        $expect, "check file marcel2.txt"
    );

    $expect = <<"EOR";
Files: marcel3.txt
Copyright: no-info-found
License: GPL-2
EOR
    eq_or_diff(
        $dir->debian_record($grants->get_grant('marcel3.txt')->hash),
        $expect, "check file marcel3.txt"
    );

    $expect = <<"EOR";
Files: *
Copyright: 2016-2019, Marcel
License: GPL-2
EOR
    eq_or_diff($dir->debian_record(), $expect, "check root dir");

    $expect = <<"EOR";
Files: bar/*
Copyright: 2016, 2017, Marcel
License: GPL-2
EOR
    eq_or_diff($dir->get_dir('bar')->debian_record(), $expect, "check dir 'bar'");

    $expect = <<"EOR";
Files: baz/*
Copyright: 2017, 2018, Marcel
License: GPL-2
EOR
    eq_or_diff($dir->get_dir('baz')->debian_record(), $expect, "check dir 'baz'");

    $expect = <<"EOR";
Files: bar/bar3.c
Copyright: 2015, Yves
License: GPL-2
EOR
    my $hash = $dir->get_dir('bar')->get_grant('bar3.c')->hash;
    my $rec = $dir->get_dir('bar')->debian_record($hash);
    eq_or_diff($rec, $expect, "check file 'bar/bar3.c'");

};

subtest "debian_struct - several levels" => sub {
    my $grants = grant_with_foo_bar();
    $grants->add('bar/bar3.c', 'GPL-2', '2016, Marcel');
    $grants->add('bar/bar4.c', 'GPL-2', '2014, Marcel');
    $grants->add('bar/bar5.c', 'GPL-2', '2015, Yves');
    $grants->add('bar/bar6.c', 'GPL-2', '2015, Yves');

    $grants->add ('marcel2.txt', 'GPL-2', '2015, Marcel <marcel@example.com>');
    $grants->add('README.md', 'GPL-2', '2015, Marcel <marcel@example.com>');

    my $dir = get_dir_grant()->add_all_grants($grants);

    my $expect = <<"EOR";
Files: *
Copyright: 2014-2018, Marcel <marcel\@example.com>
License: GPL-2

Files: bar/bar5.c
 bar/bar6.c
Copyright: 2015, Yves
License: GPL-2

Files: foo/*
Copyright: 2014, 2015, Jonathan Stowe
License: Artistic-2.0
EOR

    eq_or_diff($dir->debian_full_record(), $expect, "check dir debian record");
};

subtest "debian_struct - dir and file without info" => sub {
    my $grants = get_grant();
    $grants->add('bar/bar3.c', '', '');
    $grants->add('bar/bar4.c', '', '');
    $grants->add('foo/foo-yes.c', 'MIT', '2012, Yves <yves@e.com>');
    $grants->add('foo/foo-no.c', '', '');

    $grants->add ('marcel2.txt', 'GPL-2', '2015, Marcel <marcel@example.com>');
    $grants->add('README.md', 'GPL-2', '2015, Marcel <marcel@example.com>');

    my $dir = get_dir_grant()->add_all_grants($grants);

    my $expect = <<"EOR";
Files: *
Copyright: 2015, Marcel <marcel\@example.com>
License: GPL-2

Files: foo/foo-yes.c
Copyright: 2012, Yves <yves\@e.com>
License: Expat
EOR
    my $record = $dir->debian_full_record();
    eq_or_diff($record, $expect, "check dir debian record");
};

sub add_all ($grants, $str) {
    foreach my $line (split /\n/, $str) {
        $grants->add(split /\t/, $line, 3);
    }
}

subtest "debian_full_data - main file and one file" => sub {
    my $grants = get_grant();
    my $str = <<'EOL';
./LICENSE.txt	BSD-3-clause	2011, 2013 Mutsuo Saito, Makoto Matsumoto,
./README.txt	UNKNOWN	*No copyright*
./tinymt64.c	UNKNOWN	2011 Mutsuo Saito, Makoto Matsumoto,
./tinymt64.h	UNKNOWN	*No copyright*
EOL
    add_all($grants, $str);

    my $dir = get_dir_grant()->add_all_grants($grants);

    my $expect = [
        {
            Copyright => '2011, 2013, Mutsuo Saito, Makoto Matsumoto',
            Files => '*',
            License => {
                short_name => 'BSD-3-clause'
            }
        },
    ];
    eq_or_diff([ $dir->debian_full_data() ], $expect, "full data output");
};

subtest "debian_full_data - dir and file with info" => sub {
    my $grants = get_grant();
    my $str = <<'EOL';
./configure	FSFUL	1992-1996, 1998-2012 Free Software Foundation, Inc.
./foo.c	FSFUL	1992-1996, 1998-2012 Free Software Foundation, Inc.
./configure.in	Artistic	 *No copyright*
./configure.dummy	UNKNOWN	*No copyright*
./acinclude/ax_check_compiler_flags.m4	GPL-3+	2009 Steven G. Johnson <stevenj@alum.mit.edu> / 2009 Matteo Frigo
./acinclude/ax_gcc_archflag.m4	GPL-3+	2008 Steven G. Johnson <stevenj@alum.mit.edu> / 2008 Matteo Frigo
./acinclude/ax_gcc_x86_cpuid.m4.htm	GPL-3+	2008 Steven G. Johnson <stevenj@alum.mit.edu> / 2008 Matteo Frigo
./acinclude/ltsugar.m4	UNKNOWN	2004-2005, 2007-2008 Free Software Foundation, Inc.
./acinclude/ltsugar2.m4	UNKNOWN	2004-2005, 2007-2008 Free Software Foundation, Inc.
EOL
    add_all($grants, $str);

    my $dir = get_dir_grant()->add_all_grants($grants);

    my $expect = [
        {
            Copyright => '2008, 2009, Steven G. Johnson <stevenj@alum.mit.edu>
2008, 2009, Matteo Frigo',
            Files => '*',
            License => {
                short_name => 'GPL-3+'
            }
        },
        {
            Copyright => '2004, 2005, 2007, 2008, Free Software Foundation, Inc.',
            Files => 'acinclude/ltsugar.m4
acinclude/ltsugar2.m4',
            License => {
                full_license => 'Please fill license text from header of files',
                short_name => 'UNKNOWN'
            }
        },
        {
            Copyright => 'no-info-found',
            Files => 'configure.in',
            License => {
                short_name => 'Artistic-1.0'
            }
        },
                {
            Copyright => '1992-1996, 1998-2012, Free Software Foundation, Inc.',
            Files => "configure
foo.c",
            License => {
                short_name => 'FSFUL'
            }
        },
    ];
    eq_or_diff([ $dir->debian_full_data() ], $expect, "full data output");
};

sub get_debian_struct_grants {
    my $grants = get_grant();
    my $str = <<'EOL';
./configure	FSFUL	1992-1996, 1998-2012 Free Software Foundation, Inc.
./bar.c	FSFUL	1992-1996, 1998-2012 Free Software Foundation, Inc.
./foo.c	FSFUL	1992-1996, 1998-2012 Free Software Foundation, Inc.
./configure.in	Artistic	*No copyright*
./configure.dummy	UNKNOWN	*No copyright*
./acinclude/ax_check_compiler_flags.m4	GPL-3+	2009 Steven G. Johnson <stevenj@alum.mit.edu> / 2009 Matteo Frigo
./acinclude/ax_gcc_archflag.m4	GPL-3+	2008 Steven G. Johnson <stevenj@alum.mit.edu> / 2008 Matteo Frigo
./acinclude/ax_gcc_x86_cpuid.m4.htm	GPL-3+	2008 Steven G. Johnson <stevenj@alum.mit.edu> / 2008 Matteo Frigo
./acinclude/libtool.m4	GPL-2+	1996-2001, 2003-2011 Free Software
./acinclude/libtool2.m4	GPL-2+	1996-2001, 2003-2011 Free Software
./acinclude/ltoptions.m4	UNKNOWN	2004-2005, 2007-2009 Free Software Foundation,
./acinclude/ltsugar.m4	UNKNOWN	2004-2005, 2007-2008 Free Software Foundation, Inc.
./acinclude/ltsugar2.m4	UNKNOWN	2004-2005, 2007-2008 Free Software Foundation, Inc.
./acinclude/ltversion.m4	UNKNOWN	2004 Free Software Foundation, Inc.
./acinclude/lt~obsolete.m4	UNKNOWN	2004-2005, 2007, 2009 Free Software Foundation, Inc.
EOL
    add_all($grants, $str);

    return get_dir_grant()->add_all_grants($grants);

}

subtest "debian_data - dir and file with info and comments" => sub {
    my $dir = get_debian_struct_grants;

    $dir->add_grant_info(
        file => 'configure.in',
        license_text => "lic text line 1\nlic text line 2"
    );
    $dir->add_grant_info(
        file => 'foo.c',
        comment => "some comment"
    );

    is(
        $dir->get_dir('acinclude')->find_main_grant_from_files.'',
        '2004, 2005, 2007-2009, Free Software Foundation, Inc.',
        "acinclude main grant from files"
    );
    is(
        $dir->get_dir('acinclude')->main_grant.'',
        '2004, 2005, 2007-2009, Free Software Foundation, Inc.',
        "acinclude main grant"
    );

    is($dir->get_dir('acinclude')->main_grant_weight, 4,"acinclude main grant weight");

    is(
        $dir->find_main_grant_from_files.'',
        '2004, 2005, 2007-2009, Free Software Foundation, Inc.',
        "top main grant from files"
    );
    is(
        $dir->main_grant.'',
        '2004, 2005, 2007-2009, Free Software Foundation, Inc.',
        "top main grant"
    );

    my $expect = {
            Copyright => '2004, 2005, 2007-2009, Free Software Foundation, Inc.',
            Files => '*',
            License => {
                full_license => 'Please fill license text from header of files',
                short_name => 'UNKNOWN'
            }
        };
    my @deb_data = $dir->debian_full_data();
    eq_or_diff( $deb_data[0], $expect, "file comment should not propagate to main data");

    my $expect_foo = {
            Copyright => '1992-1996, 1998-2012, Free Software Foundation, Inc.',
            Files => 'foo.c',
            License => {
                short_name => 'FSFUL'
            },
            Comment => 'some comment',
        };
    my ($got) = grep { $_->{Files} eq 'foo.c'} @deb_data;
    eq_or_diff( $got, $expect_foo, "foo.c should have its own section with comment");
};

subtest "debian_record - dir and file with info and license text" => sub {
    my $dir = get_debian_struct_grants;

    $dir->add_grant_info(
        file => 'configure.in',
        license_text => "lic text line 1\nlic text line 2"
    );

    # comments are not injected in debian text, because licensecheck
    # does not provides comments.
    my $expect = <<'EOR';
Files: *
Copyright: 2004, 2005, 2007-2009, Free Software Foundation, Inc.
License: UNKNOWN
 Please fill license text from header of files

Files: acinclude/ax_check_compiler_flags.m4
Copyright: 2009, Steven G. Johnson <stevenj@alum.mit.edu>
 2009, Matteo Frigo
License: GPL-3+

Files: acinclude/ax_gcc_archflag.m4
 acinclude/ax_gcc_x86_cpuid.m4.htm
Copyright: 2008, Steven G. Johnson <stevenj@alum.mit.edu>
 2008, Matteo Frigo
License: GPL-3+

Files: acinclude/libtool.m4
 acinclude/libtool2.m4
Copyright: 1996-2001, 2003-2011, Free Software
License: GPL-2+

Files: acinclude/ltoptions.m4
Copyright: 2004, 2005, 2007-2009, Free Software Foundation
License: UNKNOWN
 Please fill license text from header of files

Files: bar.c
 configure
 foo.c
Copyright: 1992-1996, 1998-2012, Free Software Foundation, Inc.
License: FSFUL

Files: configure.in
Copyright: no-info-found
License: Artistic-1.0
 lic text line 1
 lic text line 2
EOR
   my $record = $dir->debian_full_record();
   eq_or_diff($record, $expect, "check dir debian record");
};

subtest "debian struct = 2 main files" => sub {
    my $grants = get_grant();
    # extracted from node-gulp example
    my $str = <<'EOL';
./LICENSE	Expat	2014-2018 Jon Schlinkert.
./README.md	UNKNOWN	2012-2013 moutjs team
./index.js	Expat	2014-2018 Jon Schlinkert.
./package.json	UNKNOWN	*No copyright*
EOL
    add_all($grants, $str);

    my $dir = get_dir_grant()->add_all_grants($grants);

    is(
        $dir->find_main_grant_from_files.'',
        'Expat / 2014-2018, Jon Schlinkert.',
        "main grant from files"
    );
    is(
        $dir->find_main_grant_from_main_files.'',
        "Expat / 2014-2018, Jon Schlinkert.\n2012, 2013, moutjs team",
        "main grant from main files"
    );
    is(
        $dir->main_grant.'',
        "Expat / 2014-2018, Jon Schlinkert.\n2012, 2013, moutjs team",
        "main grant"
    );

};

subtest "merge dir" => sub {
    # emulate data retrieved from debian/copyright
    my $old_grants = get_grant();

    $old_grants->add ('marcel.txt', 'GPL-2', '2012, Marcel');
    $old_grants->add ('marcel2.txt', 'GPL-2', '2015, Marcel <marcel@example.com>');
    $old_grants->add ('foo/marcel.txt', 'GPL-2', '2015, Marcel Foo <marcel.foo@example.com>');
    $old_grants->add ('foo/bar/marcel.txt', 'GPL-2', '2015, Marcel FooBar <marcel.foobar@example.com>');
    $old_grants->add ('bar/marcel.txt', 'GPL-2', '2015, Marcel Foo <marcel.foo@example.com>');
    $old_grants->get_grant('marcel.txt')->comment('marcel comment');
    $old_grants->get_grant('marcel.txt')->license_text('marcel license');

    my $old_dir = get_dir_grant();

    $old_dir->add_all_grants($old_grants);

    # emulate override done by Debian developer
    my $override = Dpkg::Copyright::Grant::Plain->new(
        copyright => '2015, Marcel Bar <marcel.Bar@example.com>',
        license => 'GPL-2+',
    );
    $old_dir->get_dir('foo')->set_main_grant($override);

    # emulate comment added on a directory like File: bar/*
    $old_dir->get_dir('bar')->main_grant->comment('bar comment');

    ok(1,"setup debian/copyright data emulation");

    # emulate new data retrieved from new software version
    my $new_grants = get_grant();

    # no change
    $new_grants->add ('marcel.txt', 'GPL-2', '2012, Marcel');
    # year update
    $new_grants->add ('marcel2.txt', 'GPL-2', '2015-2016, Marcel <marcel@example.com>');
    # no change
    $new_grants->add ('foo/marcel.txt', 'GPL-2', '2015, Marcel Foo <marcel.foo@example.com>');
    $new_grants->add ('bar/marcel.txt', 'GPL-2', '2015, Marcel Foo <marcel.foo@example.com>');
    # file is moved    $new_grants->add ('foo/marcel.txbt', 'GPL-2', '2015, M Foo Baracel <marcel.fbaroo@example.com>');
    # file is moved
    $new_grants->add ('foo/bar2/marcel.txt', 'GPL-2', '2015, Marcel FooBar <marcel.foobar@example.com>');

    my $new_dir = get_dir_grant();
    $new_dir->add_all_grants($new_grants);

    # setup an old directory
    my $nada_grant = Dpkg::Copyright::Grant::Plain->new(
            copyright => "2012, Nada Inc.",
            license => "GPL-2",
        );
    # weird path to trigger a bug
    $new_dir->get_dir('nada/zilch')->set_main_grant($nada_grant);

    ok(1,"setup software update data emulation");

    $new_dir->merge_old_dir($old_dir);

    is($new_dir->get_grant('marcel.txt')->comment(), 'marcel comment', 'check comment override');
    is($new_dir->get_grant('marcel.txt')->license_text(), 'marcel license', 'check license override');

    ok(!$new_dir->has_dir('foo/bar'), 'check obsolete dir');
    ok($new_dir->has_dir('foo/bar2'), 'check new dir');
    is($new_dir->get_grant('foo/bar2/marcel.txt').'',
       'GPL-2 / 2015, Marcel FooBar <marcel.foobar@example.com>', "check new file");
    is($new_dir->get_grant('marcel2.txt').'',
       'GPL-2 / 2015, 2016, Marcel <marcel@example.com>',"check updated copyright");
    my $expect = "GPL-2 / 2015, Marcel Foo <marcel.foo\@example.com>";
    is($new_dir->get_dir('foo')->main_grant.'', $expect , 'check overridden dir');

    is($new_dir->get_dir('bar')->main_grant->comment, 'bar comment' , 'check propagated comment dir');
};
subtest "test merge dir with main grant" => sub {
    my $old_grants = get_grant();

    $old_grants->add ('marcel.txt', 'GPL-2', '2012, Marcel');
    $old_grants->add ('marcel2.txt', 'GPL-2', '2015, Marcel <marcel@example.com>');
    $old_grants->add ('foo/no_cop1.txt', '', '');
    $old_grants->add ('foo/no_cop2.txt', '', '');

    my $old_dir = get_dir_grant();
    $old_dir->add_all_grants($old_grants);
    my $foo_dir = $old_dir->get_dir('foo');
    is($foo_dir->main_grant.'','','check empty main grant');

    # set manually main grant
    my $old_main_grant = Dpkg::Copyright::Grant::Plain->new(license => "Artistic", copyright => '2016, Dod');
    $foo_dir->set_main_grant($old_main_grant);
    is($foo_dir->main_grant.'','Artistic-1.0 / 2016, Dod','check foo main grant setup manually');

    # new release has new file without grant -> main grant is propagated
    my $new_grants_1 = get_grant();
    $new_grants_1->add ('foo/no_cop3.txt', '', '');
    my $new_dir_1 = get_dir_grant();
    $new_dir_1->add_all_grants($new_grants_1);

    $new_dir_1->merge_old_dir($old_dir);
    is($new_dir_1->get_dir('foo')->main_grant.'','Artistic-1.0 / 2016, Dod','check propagated empty foo main grant');

    # new release has new file with correct grant
    my $new_grants_2 = get_grant();
    $new_grants_2->add ('foo/with_cop1.txt', 'Artistic', '2016, Dominique Dumont');
    my $new_dir_2 = get_dir_grant();
    $new_dir_2->add_all_grants($new_grants_2);

    ok(1,"setup software update emulation done");

    # main grant from new files overrides 
    $new_dir_2->merge_old_dir($new_dir_1);
    is($new_dir_2->get_dir('foo')->main_grant.'','Artistic-1.0 / 2016, Dominique Dumont','check updated empty foo main grant');
};

subtest "block propagation from subdir" => sub {
    my $ypp = YAML::PP->new;

    my $yaml = <<'EOM';
LICENSE:
  override-copyright: 2015-2023, libuv project contributors.
  override-license: Expat
  skip: false
debian:
  override-copyright: |
    2018-2023, Dominique Dumont <dod@debian.org>
    2013, Luca Bruno <lucab@debian.org>
  license: Expat
EOM
    my $grants = get_grant(fill_blank_data => $ypp->load_string($yaml));

    # from libuv1 files
    add_all($grants, << "EOF");
LICENSE	Expat	2015
docs/src/guide/introduction.rst	UNKNOWN	*No copyright*
docs/src/guide/networking.rst	UNKNOWN	*No copyright*
docs/src/sphinx-plugins/manpage.py	Apache-2.0	2013 Dariusz Dwornikowski.
EOF

    my $dir = get_dir_grant();

    $dir->add_all_grants($grants);

    my $expect = << 'EOF';
Files: *
Copyright: 2015-2023, libuv project contributors.
License: Expat

Files: docs/src/sphinx-plugins/*
Copyright: 2013, Dariusz Dwornikowski.
License: Apache-2.0
EOF
    my $record = $dir->debian_full_record();
    eq_or_diff($record, $expect, "check dir debian record");
};

subtest "debian_full_record - main file and one file" => sub {
    my $grants = get_grant();
    my $str = <<'EOL';
./LICENSE.txt	BSD-3-clause	2011, 2013 Mutsuo Saito, Makoto Matsumoto,
./README.txt	UNKNOWN	*No copyright*
./tinymt64.c	UNKNOWN	2011 Mutsuo Saito, Makoto Matsumoto,
./tinymt64.h	UNKNOWN	*No copyright*
EOL
    add_all($grants, $str);

    my $dir = get_dir_grant()->add_all_grants($grants);

    my $expect = << "EOF";
Files: *
Copyright: 2011, 2013, Mutsuo Saito, Makoto Matsumoto
License: BSD-3-clause
EOF
    eq_or_diff([ $dir->debian_full_record() ], [$expect], "full data output");
};

subtest "debian_full_record - several subdirs" => sub {
    my $grants = get_grant();
    my $str = <<'EOL';
./LICENSE	LGPL-2.1	2018 Dominique Dumont.
./t/model_tests.d/backend-yaml-data-test-conf.pl	LGPL-2.1	2018 Dominique Dumont.
./t/model_tests.d/backend-yaml-test-conf.pl	LGPL-2.1	2018 Dominique Dumont.
./t/model_tests.d/backend-yaml-data-examples/basic	UNKNOWN	*No copyright*
./t/model_tests.d/backend-yaml-examples/basic	UNKNOWN	*No copyright*
EOL
    add_all($grants, $str);

    my $dir = get_dir_grant()->add_all_grants($grants);

    my $expect = << "EOF";
Files: *
Copyright: 2018, Dominique Dumont.
License: LGPL-2.1
EOF
    eq_or_diff([ $dir->debian_full_record() ], [$expect], "full data output");
};

subtest "debian_full_record - only one subdir has data" => sub {
    my $grants = get_grant();
    my $str = <<'EOL';
./README	UNKNOWN	*No copyright*
./lib/Tk/FontDialog.pm	Artistic or GPL-1+	1998-1999, 2003-2005, 2010-2011, 2013, 2017 Slaven Rezic.
EOL
    add_all($grants, $str);

    my $dir = get_dir_grant()->add_all_grants($grants);

    my $expect = << "EOF";
Files: *
Copyright: 1998, 1999, 2003-2005, 2010, 2011, 2013, 2017, Slaven Rezic.
License: Artistic-1.0 or GPL-1+
EOF
    eq_or_diff([ $dir->debian_full_record() ], [$expect], "full data output");
};

subtest "debian_full_record - only one subdir has a main file" => sub {
    my $grants = get_grant();
    my $str = <<'EOL';
./LICENSE	Expat	2013-2018 Blaine Bublitz <blaine.bublitz@gmail.com>
./matchdep/.jshintrc	UNKNOWN	*No copyright*
./matchdep/.npmignore	UNKNOWN	*No copyright*
./matchdep/.travis.yml	UNKNOWN	*No copyright*
./matchdep/LICENSE-MIT	Expat	2013 Tyler Kellen
./matchdep/README.md	UNKNOWN	*No copyright*
./matchdep/package.json	UNKNOWN	*No copyright*
./matchdep/lib/matchdep.js	Expat	2012 Tyler Kellen
EOL
    add_all($grants, $str);

    my $dir = get_dir_grant()->add_all_grants($grants);

    my $expected_grant = "Expat / 2012, 2013, Tyler Kellen";
    is($dir->get_dir('matchdep')->main_grant.'', $expected_grant , 'check main grant of subdir with main file');


    my $expect = << 'EOF';
Files: *
Copyright: 2013-2018, Blaine Bublitz <blaine.bublitz@gmail.com>
License: Expat

Files: matchdep/*
Copyright: 2012, 2013, Tyler Kellen
License: Expat
EOF
    eq_or_diff([ $dir->debian_full_record() ], [$expect], "full data output");
};

subtest "debian_full_record - main file and several files without info" => sub {
    my $grants = get_grant();
    my $author = 'Felix Geisendörfer (felix@debuggable.com)';
    my $str = <<"EOL";
./stack-trace/.npmignore	UNKNOWN	*No copyright*
./stack-trace/License	Expat	2011 $author
./stack-trace/Makefile	UNKNOWN	*No copyright*
./stack-trace/Readme.md	UNKNOWN	*No copyright*
./stack-trace/package.json	UNKNOWN	*No copyright*
./stack-trace/lib/stack-trace.js	UNKNOWN	*No copyright*
EOL
    add_all($grants, $str);
    my $dir = get_dir_grant()->add_all_grants($grants);

    my $res = $dir->get_dir('stack-trace')->find_main_grant_from_main_files.'';

    my $expected_grant = "Expat / 2011, $author";
    is($res, $expected_grant, 'check main grant of subdir with main file');

    is($dir->get_dir('stack-trace')->main_grant.'', $expected_grant , 'check main grant of subdir with main file');


    my $expect = << "EOF";
Files: stack-trace/*
Copyright: 2011, $author
License: Expat
EOF
    eq_or_diff([ $dir->debian_full_record() ], [$expect], "full data output");
};

done_testing;
