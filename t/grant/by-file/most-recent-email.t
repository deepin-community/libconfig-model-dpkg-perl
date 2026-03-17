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

require_ok('Dpkg::Copyright::Grant::ByFile::MostRecentEmail');

sub check ($inv, $input, $year = 0, $email = '') {
    $inv->update_email_if_more_recent(new_st($input));
    is($inv->email, $email, "check email $email");
    is($inv->year, $year, "check year $year");
}

sub new_st($str) {
    return Software::Copyright::Statement->new($str);
}

subtest "add email" => sub {
    my $inv = Dpkg::Copyright::Grant::ByFile::MostRecentEmail->new();

    check($inv, '2013 Marcel');
    check($inv, 'Marcel <bogus@e.com>', 0 => 'bogus@e.com');
    check($inv, '2013 Marcel <marcel@example.com>', 2013 => 'marcel@example.com'  );
    check($inv, '2012 Marcel <oldmarcel@example.com>', 2013 => 'marcel@example.com'  );
    check($inv, '2010-2014 Marcel <newmarcel@example.com>', 2014 => 'newmarcel@example.com'  );

    # this is the corner case that may cause trouble: same year, 2 email addreses
    # we arbitrarily don't update in this case.
    check($inv, '2014 Marcel <new2marcel@example.com>', 2014 => 'newmarcel@example.com'  );
};

done_testing;
