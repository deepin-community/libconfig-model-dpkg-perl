use 5.20.0;

use ExtUtils::testlib;
use Test::More ;
use Test::Exception ;
use Test::Memory::Cycle;
use Config::Model ;
use Config::Model::Tester::Setup qw/init_test setup_test_dir/;
use Test::Log::Log4perl;

use warnings;
use strict;

Test::Log::Log4perl->ignore_priority("info");

my ($model, $trace) = init_test();

# pseudo root where config files are written by config-model
my $wr_root = setup_test_dir();

# cleanup before tests

my $control = $model->instance(
    root_class_name => 'Dpkg::Control',
    root_dir        => $wr_root,
);

my $root = $control->config_root ;
$control->initial_load_stop;

subtest "PWD cannot be used for Source package name" => sub {
    my $bad_dir = $wr_root->child('1');
    $bad_dir->mkpath;
    chdir $bad_dir;
    my $i = $model->instance(
        root_class_name => 'Dpkg::Control',
        root_dir        => $wr_root,
        name            => 'bad_test',
    );
    # setting Standards-Version to avoid an undef warning
    # Source is a mandatory value and must be set before calling apply_fixes
    $i->load('source Standards-Version=3.6.0 Source=foo-pkg');
    $i->apply_fixes;
    ok(1,"apply_fixes is done");
    is($i->grab_value('source Source'),'foo-pkg',"check that Source is not modified");
    chdir $wr_root;
};

# Test Build-Profiles which has a complex match regexp
subtest "Build-Profiles" => sub {
    my $bp = $root->grab("binary:test-bp Build-Profiles");

    my @bad = ('plop', '<check> plop', 'plop <!nocheck>');
    foreach my $t (@bad) {
        throws_ok {
            $bp->store($t);
        } 'Config::Model::Exception::WrongValue', "set bad value $t";
    }

    my @test = ('<check>', '<!nocheck>','<pkg.foo-bar.baz-foo>');
    foreach my $t (@test) {
        $bp->store($t);
        ok(1,"set $t");
    }
};

memory_cycle_ok($model, "check memory cycles");

done_testing();
