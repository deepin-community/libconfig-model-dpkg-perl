package Dpkg::Copyright::Grant::ByFile::UpdatedOwner;

use 5.20.0;
use warnings;
use utf8;
use Carp;

use Mouse;

use Software::Copyright;
use Dpkg::Copyright::Grant::Plain;

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

has hash => (
    is => 'rw',
    traits => ['Array'],
    isa => 'ArrayRef[Str]',
    default => sub { [] },
);

has statement => (
    is => 'ro',
    traits => ['Array'],
    isa => 'ArrayRef[Software::Copyright::Statement]',
    default => sub { [] },
    handles => {
        all_statements => 'elements',
    }
);

has year => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

sub update_statements ($self, $email) {
    foreach my $st ($self->all_statements) {
        $st->email($email);
    }
    return;
}

sub update_statement_if_more_recent ($self, $new_st) {
    my ($year) = ($new_st->range =~ /(\d+)$/);
    $year //= 0;

    if ($new_st->email and (not $self->year or $year > $self->year)) {
        my @modified = $self->hash->@*;
        $self->update_statements($new_st->email);
        $self->year($year);
        return @modified;
    }
    elsif ($self->all_statements and $self->statement->[0]->email and $year < $self->year) {
        $new_st->email($self->statement->[0]->email);
        return ();
    }
    return ();
}

sub add ($self, $hash, $st) {
    push $self->hash->@*, $hash;
    push $self->statement->@*, $st;
    return $self;
}

1;

