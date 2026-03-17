package Dpkg::Copyright::Grant::ByFile::MostRecentEmail;

use 5.20.0;
use warnings;
use utf8;
use Carp;

use Mouse;

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

has email => (
    is => 'rw',
    isa => 'Str',
    default => '',
);

has year => (
    is => 'rw',
    isa => 'Int',
    default => 0
);

sub update_email_if_more_recent ($self, $st) {
    my ($year) = ($st->range =~ /(\d+)$/);

    return unless $st->email;
    return if $self->email and ($year // 0) <= ($self->year // 0);

    $self->email($st->email);
    return $self->year($year // 0) ;
}

1;

