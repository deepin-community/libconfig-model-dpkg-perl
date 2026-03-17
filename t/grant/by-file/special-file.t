use 5.20.0;
use strict;
use warnings;
use utf8;
use open ':std', ':encoding(utf8)';

use Test::More;
use Test::Warn;
use Test::Differences;
use Test::Synopsis::Expectation;
use Dpkg::Copyright::Grant::ByFile;
use Path::Tiny;
use Log::Log4perl 1.11 qw(:easy :levels);

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

Log::Log4perl->easy_init( $ERROR );

sub get_grant (%args) {
    return Dpkg::Copyright::Grant::ByFile->new(
        current_dir => path('.'),
        %args
    );
}

subtest "main toml file" => sub {
    my $grants = get_grant();
    my $file = 't/grant/examples/rust/Cargo.toml';
    $grants->add ($file, '', '');
    is($grants->get_grant($file)->license,'LGPL-2.1+','license from Cargo.toml');
    is($grants->get_grant($file)->copyright."",
       "Many others\nFederico Mena Quintero <federico\@gnome.org>",
       'copyright from Cargo.toml');
};

subtest "secondary toml file" => sub {
    my $grants = get_grant();
    my $file = 't/grant/examples/rust/sub-pkg-1/Cargo.toml';
    $grants->add ($file, '', '');

    # license is empty because it refers to Rust workspace.
    is($grants->get_grant($file)->license,'','empty license from Cargo.toml');
    is($grants->get_grant($file)->copyright."",
       'Alberto Ruiz <aruiz@gnome.org>',
       'copyright from Cargo.toml');
};

subtest "broken toml file" => sub {
    my $grants = get_grant();
    my $file = 't/grant/examples/rust/invalid/Cargo.toml';

    warning_like {
        $grants->add ($file, '', '');
    } qr/Error while parsing/, "got parsing warning";

    is($grants->get_grant($file)->license,'','empty license from Cargo.toml');
    is($grants->get_grant($file)->copyright."",'',
       'copyright from Cargo.toml');
};

# test for Debian #1101989
subtest "json file with a BOM" => sub {
    my $grants = get_grant();
    my $file = 't/grant/examples/nodejs/with-bom/package.json';
    $grants->add ($file, '', '');
    is($grants->get_grant($file)->license,'Apache','license from package.json');
    is($grants->get_grant($file)->copyright."", "Joe", 'copyright from package.json');
};

# test for Debian #1101989
subtest "broken package.json" => sub {
    my $grants = get_grant();
    my $file = 't/grant/examples/nodejs/invalid/package.json';

    warning_like {
        $grants->add ($file, '', '');
    } qr/Error while parsing/, "got parsing warning";

    is($grants->get_grant($file)->license,'','license from package.json');
    is($grants->get_grant($file)->copyright."", "", 'copyright from package.json');
};

subtest "main dist.ini file" => sub {
    my $grants = get_grant();
    my $file = 't/grant/examples/dzil/dist.ini';
    $grants->add ($file, '', '');
    is($grants->get_grant($file)->license,'LGPL-2.1','license from dist.ini');
    is($grants->get_grant($file)->copyright."", "2008-2025, Dominique Dumont", 'copyright from dist.ini');
};

# test for Debian #1107170
subtest "empty dist.ini file" => sub {
    my $grants = get_grant();
    my $file = 't/grant/examples/empty-dzil/dist.ini';
    $grants->add ($file, '', '');
    is($grants->get_grant($file)->license,'','no license from empty dist.ini');
    is($grants->get_grant($file)->copyright."", "", 'no copyright from empty dist.ini');
};

done_testing;
