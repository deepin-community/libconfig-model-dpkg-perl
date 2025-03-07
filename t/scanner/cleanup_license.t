# -*- cperl -*-
use strict;
use warnings;
use 5.020;

use Test::More;                 # see done_testing()
use Test::Differences;

require_ok( 'Dpkg::Copyright::Scanner' );

my @tests = (
    gpl_1                     => 'GPL-1',
    lgpl_1                    => 'LGPL-1',
    'GPL-1+ and/or GPL-1'     => 'GPL-1+',
    'LGPL-2.1-only'           => 'LGPL-2.1',
    'LGPL-2.1-or-later'       => 'LGPL-2.1+',
    'GPL-3.0'                 => 'GPL-3',
    'LGPL-3 or LGPL-3.0-only' => 'LGPL-3',
    'GPL-3.0-only or GPL-3'   => 'GPL-3',
    'GPL-3.0-only or LGPL-3'  => 'GPL-3 or LGPL-3',
    'Artistic or GPL-2-only'  => 'Artistic or GPL-2',
);

while (@tests) {
    my ($in,$expect) = splice @tests, 0, 2;
    my $res = Dpkg::Copyright::Scanner::__cleanup_license($in);
    eq_or_diff($res,$expect,"cleanup license '$in'");
}


done_testing();
