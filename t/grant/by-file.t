use 5.20.0;
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(utf8)';

use Test::More;
use Test::Differences;
use Test::Synopsis::Expectation;
use Software::Copyright;
use Path::Tiny;
use Log::Log4perl 1.11 qw(:easy :levels);
use List::MoreUtils qw/bsearch/;

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

require_ok('Dpkg::Copyright::Grant::ByFile');

Log::Log4perl->easy_init( $ERROR );

sub check_hash_consistency($grants, $label = '') {
    my $str = $label? "$label: " : '';
    foreach my $file (sort $grants->files) {
        my $hash = $grants->get_grant($file)->hash;
        my $ref = $grants->get_hash_files($hash);
        ok($ref, $str."file $file hash is found");
        my $found = bsearch { $_ cmp $file} $ref->@*;
        ok($found, $str."file $file and hash $hash match") if $ref;
    }

    foreach my $hash ($grants->hashes) {
        my @files = $grants->get_hash_files($hash)->@*;
        ok(scalar @files, $str."hash $hash has data");
        foreach my $file (@files) {
            my $grant = $grants->get_grant($file);
            if ($grant) {
                is($grant->hash, $hash, $str."$file hashes match");
            }
            else {
                fail($str."$file grant should not exist, hash data was not cleaned up");
            }
        }
    }
}

sub get_grant (%args) {
    return Dpkg::Copyright::Grant::ByFile->new(
        current_dir => path('.'),
        %args
    );
}

subtest "email propagation" => sub {
    my $grants = get_grant();

    $grants->add ('marcel.txt', 'GPL-2', '2012, Marcel');
    my $old_hash = $grants->get_grant('marcel.txt')->hash;

    # check that this grant is recorded in _owner_with_no_email attribute
    is($grants->get_owner("Marcel")->hash->[0], $old_hash , "check updated owner hash 1");

    $grants->add ('marcel2.txt', 'GPL-2', '2015, Marcel <marcel@example.com>');
    my $new_hash = $grants->get_grant('marcel.txt')->hash;
    is($grants->get_owner("Marcel")->hash->[0], $new_hash , "check updated owner hash 2");
    isnt($new_hash, $old_hash, "check that marcel.txt hash was changed");

    # check that marcel2.txt has email info
    is($grants->get_grant('marcel2.txt')->copyright->statement('Marcel')->email,'marcel@example.com',"check marcel2 grant");

    # check that marcel2.txt email has propagated to marcel.txt even
    # though the latter was created befire marcel2
    is($grants->get_grant('marcel.txt')->copyright->statement('Marcel')->email,'marcel@example.com',"check marcel2 grant");

    check_hash_consistency($grants);
};

subtest "email propagation - hash updates" => sub {
    my $grants = get_grant();
    $grants->add ('marcel.txt', 'GPL-2', '2015, Marcel <marcel2015@example.com>');
    $grants->add ('marcel2.txt', 'GPL-2', '2015, Marcel <marcel2015@example.com>');
    $grants->add ('marcel3.txt', 'GPL-2', '2016, Marcel <marcel2016@example.com>');

    # check that older email is updated
    is($grants->get_grant('marcel.txt')->copyright->statement('Marcel')->email,'marcel2016@example.com',"check marcel email");
    is($grants->get_grant('marcel2.txt')->copyright->statement('Marcel')->email,'marcel2016@example.com',"check marcel2 email");
    check_hash_consistency($grants);
};

subtest "merge after email propagation" => sub {
    my $grants = get_grant();

    $grants->add ('marcel.txt', 'GPL-2', '2015, Marcel');
    my $old_marcel_hash = $grants->get_grant('marcel.txt')->hash;

    $grants->add ('marcel2.txt', 'GPL-2', '2015, Marcel <marcel@example.com>');

    my $marcel_hash = $grants->get_grant('marcel.txt')->hash;
    my $marcel2_hash = $grants->get_grant('marcel2.txt')->hash;

    isnt($old_marcel_hash, $marcel_hash,"Since marcel grant was updated by merging an email, its new hash is different");

    is($marcel_hash, $marcel2_hash, "both grants have the same hash after merging email");

    # check that hash to file attribute point to both files
    is_deeply($grants->get_hash_files($marcel_hash),[qw/marcel.txt marcel2.txt/],"hash list was updated");
    isnt(defined $grants->get_hash_files($old_marcel_hash),"hash list was cleaned up");

    check_hash_consistency($grants);
};

subtest "merge after email propagation" => sub {
    my $grants = get_grant();

    $grants->add('merged.txt', 'GPL-2', "2012, Marcel\n2014 Marcel <marcel\@example.com>");
    is($grants->get_grant('merged.txt')->copyright->statement('Marcel').'','2012, 2014, Marcel <marcel@example.com>',"check grant");

    check_hash_consistency($grants);
};

subtest "merge after email propagation (reverse order)" => sub {
    my $grants = get_grant();

    $grants->add('merged.txt', 'GPL-2', "2014 Marcel <marcel\@example.com>\n2012, Marcel");
    is($grants->get_grant('merged.txt')->copyright->statement('Marcel').'','2012, 2014, Marcel <marcel@example.com>',"check marcel2 grant");

    check_hash_consistency($grants);
};

subtest "merge accross grants with different emails. different years" => sub {
    my $grants = get_grant();

    $grants->add('merged0.txt', 'GPL-2', "2010, Marcel");

    note("merging merged1.txt" );
    $grants->add('merged1.txt', 'GPL-2', "2014 Marcel <marcel1\@example.com>");
    is($grants->get_grant('merged0.txt')->copyright->statement('Marcel').'','2010, Marcel <marcel1@example.com>',"check merged0 email grant");

    note("merging merged2.txt" );
    $grants->add('merged2.txt', 'GPL-2', "2015, Marcel <marcel2\@example.com>");

    note("merging merged3.txt" );
    $grants->add('merged3.txt', 'GPL-2', "2012, Marcel");

    is($grants->get_grant('merged0.txt')->copyright->statement('Marcel').'','2010, Marcel <marcel2@example.com>',"check merged0 email grant (more recent email)");
    is($grants->get_grant('merged2.txt')->copyright->statement('Marcel').'','2015, Marcel <marcel2@example.com>',"check merged2 email grant");

    note("merging merged4.txt" );
    $grants->add('merged4.txt', 'GPL-2', "2011, Marcel <marcel-older\@example.com>");
    note("merging merged5.txt" );
    $grants->add('merged5.txt', 'GPL-2', "2012, Marcel");

    is($grants->get_grant('merged0.txt')->copyright->statement('Marcel').'','2010, Marcel <marcel2@example.com>',"check merged0 email grant (more recent email not clobbered)");
    is($grants->get_grant('merged5.txt')->copyright->statement('Marcel').'','2012, Marcel <marcel2@example.com>',"check merged5 email grant (updated with more recent email, year wise)");

    check_hash_consistency($grants);
};

subtest "all records have email" => sub {
    my $grants = get_grant();
    $grants->add('dummy01.txt', 'ISC', '2007-2015, Daniel Adler <dadler@uni-goettingen.de>');
    # call updated owner when there's no owner without email
    $grants->add('dummy02.txt', 'ISC', '2013, Daniel Adler <dadler@uni-goettingen.de>');
    ok(1, "correctly processed");
};

subtest "raku style merge" => sub {
    my $grants = get_grant();
    $grants->add('LICENSE', 'Artistic-2.0', '2015, Jonathan Stowe');
    $grants->add('README.md', 'UNKNOWN', '2015-2021, Jonathan Stowe');
    $grants->add('META6.json', 'Artistic-2.0', 'Jonathan Stowe <jns+git@gellyfish.co.uk>');

    check_hash_consistency($grants, "first");
    $grants->_copy_license_in_readme_info();
    check_hash_consistency($grants, "after copy license");
    is_deeply([sort $grants->files_without_info], [], "check files without info");
};

subtest "no info handling" => sub {
    my $grants = get_grant();
    $grants->add('LICENSE', 'Artistic-2.0', '2015, Jonathan Stowe');
    $grants->add('README.md', 'UNKNOWN', 'no-info-found');
    $grants->add('WRITEME.md', 'UNKNOWN', 'no-info-found');

    is_deeply([sort $grants->files], [qw/LICENSE README.md WRITEME.md/], "check files");
    is_deeply([sort $grants->files_without_info], [qw/README.md WRITEME.md/], "check files without info");
};

subtest "invalid copyright handling" => sub {
    my $grants = get_grant();
    $grants->add('LICENSE', 'Artistic-2.0', '2015');
    $grants->add('README.md', 'Artistic-2.0', '2020, Jonathan Stowe');
    $grants->add('WRITEME.md', 'Artistic-2.0', '2020');
    # guess what was before **b
    $grants->add('bn_mp_n_root.c', 'UNKNOWN', '**b <= a and (c+1)**b > a');

    is_deeply([sort $grants->files], [qw/LICENSE README.md WRITEME.md bn_mp_n_root.c/], "check files");

    is($grants->get_grant('LICENSE').'','Artistic-2.0',"copyright year of Artistic license was removed");
    is($grants->get_grant('WRITEME.md').'','Artistic-2.0 / 2020',"copyright year of file was kept even if unvalid");
};

subtest "fill blank data" => sub {
    my $grants = get_grant(
        fill_blank_data => {
            'foo.c' => {
                copyright => "2015 Marcel Mézigue"
            },
            'bar.c' => {
                'override-copyright' => "2015 Marcel Mézigue"
            },
            'foo.l' => {
                license => "Apache-2.0"
            },
            'bar.l' => {
                'override-license' => "Apache-2.0"
            },
        }
    );

    $grants->add('foo.c', 'Artistic-2.0', '');
    is($grants->get_grant('foo.c').'','Artistic-2.0 / 2015, Marcel Mézigue',"apply copyright");

    # Since the copyright entry is overridden above, we should not get a warning there
    $grants->add('bar.c', 'Artistic-2.0', '2014-2013, wrong guy, invalid range');
    is($grants->get_grant('bar.c').'','Artistic-2.0 / 2015, Marcel Mézigue',"override copyright");

    $grants->add('foo.l', '', '2015 Marcel Mézigue');
    is($grants->get_grant('foo.l').'','Apache-2.0 / 2015, Marcel Mézigue',"apply copyright");

    $grants->add('bar.l', 'WRONG_LICENSE', '2015 Marcel Mézigue');
    is($grants->get_grant('bar.l').'','Apache-2.0 / 2015, Marcel Mézigue',"ovveride copyright");
};

subtest "copy license info in readme file" => sub {
    my $grants = get_grant();
    $grants->add('LICENSE', 'Artistic-2.0', '2015, Jonathan Stowe');
    $grants->add('README.md', 'UNKNOWN', '2016 Joe Writer');

    $grants->_copy_license_in_readme_info;

    is($grants->get_grant('README.md').'','Artistic-2.0 / 2016, Joe Writer',"updated license in readme");

    my $hash = $grants->get_grant('README.md')->hash;
    my $found = grep { $_ eq 'README.md'} $grants->get_hash_files($hash)->@*;
    ok($found, "hash data was updated");
};

subtest "delete grants" => sub {
    my $grants = get_grant();
    my $goner = 'foo.txt';

    $grants->add ('marcel.txt', 'GPL-2', '2012, Marcel <marcel@example.com>');
    $grants->add ('marcel2.txt', 'GPL-2', '2015, Marcel <marcel@example.com>');
    $grants->add ($goner, 'GPL-2', '2015, Foo <foo@example.com>');

    $grants->delete_grant($goner);
    is($grants->get_grant($goner), undef, "$goner was deleted");

    check_hash_consistency($grants);
};

subtest "stop comment and license propagation" => sub {
    my $grants = get_grant();

    $grants->add ('marcel.txt', 'GPL-2', '2012, Marcel <marcel@example.com>');
    $grants->add ('marcel2.txt', 'GPL-2', '2012, Marcel <marcel@example.com>');
    my $hash = $grants->get_grant('marcel2.txt')->hash;

    is( $grants->get_grant('marcel.txt')->hash, $hash, "same hash");

    $grants->add_grant_info(file => 'marcel.txt', comment => "blah");
    is($grants->get_grant('marcel.txt')->comment(), 'blah', 'check comment');
    isnt( $grants->get_grant('marcel.txt')->hash, $hash, "different hash");
    is($grants->get_grant('marcel2.txt')->comment, '', "comment is not shared");

    $grants->add_grant_info(file => 'marcel.txt', license_text => "license blah blah");
    is($grants->get_grant('marcel.txt')->license_text, 'license blah blah', 'check license text');

    $grants->add_grant_info(
        file => 'marcel2.txt',
        comment => "blah",
        license_text => "license blah blah"
    );

    is( $grants->get_grant('marcel.txt')->hash,
        $grants->get_grant('marcel2.txt')->hash , "back to same hash");
};

subtest "merge_old_grants" => sub {
    # emulate data retrieved from debian/copyright
    my $old_grants = get_grant();

    $old_grants->add ('marcel.txt', 'GPL-2', '2012, Marcel');
    $old_grants->add ('marcel2.txt', 'GPL-2', '2012, Marcel');
    $old_grants->add ('marcel3.txt', 'GPL-2', '2015, Marcel <marcel@example.com>');
    $old_grants->add ('foo/marcel.txt', 'GPL-2', '2015, Marcel Foo <marcel.foo@example.com>');

    $old_grants->add_grant_info(file => 'marcel.txt', comment => 'marcel comment');
    $old_grants->add_grant_info(file => 'marcel.txt', license_text => 'marcel license');

    ok(1,"setup debian/copyright data emulation");

    # emulate new data retrieved from new software version
    my $new_grants = get_grant();

    # no change
    $new_grants->add ('marcel.txt', 'GPL-2', '2012, Marcel');
    $new_grants->add ('marcel2.txt', 'GPL-2', '2012, Marcel');
    # year update
    $new_grants->add ('marcel3.txt', 'GPL-2', '2015-2016, Marcel <marcel@example.com>');
    # file is moved
    $new_grants->add ('bar/marcel.txt', 'GPL-2', '2015, Marcel Foo <marcel.foo@example.com>');

    $new_grants->merge_old_grants($old_grants);

    is($new_grants->get_grant('marcel.txt')->comment(), 'marcel comment', 'check comment override');
    is($new_grants->get_grant('marcel.txt')->license_text(), 'marcel license', 'check license override');
    is($new_grants->get_grant('marcel.txt').'', 'GPL-2 / 2012, Marcel <marcel@example.com>', 'check unchanged file grant');

    is($new_grants->get_grant('marcel2.txt')->comment(), '', 'check no comment leak');

    is($new_grants->get_grant('foo/marcel.txt'), undef, 'check obsolete file');
    is($new_grants->get_grant('bar/marcel.txt').'', 'GPL-2 / 2015, Marcel Foo <marcel.foo@example.com>', "check new file");

    is($new_grants->get_grant('marcel3.txt').'', 'GPL-2 / 2015, 2016, Marcel <marcel@example.com>',"check updated copyright");
};

# TODO: test other method wichc tweaked no-info-found

done_testing;
