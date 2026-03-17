package Dpkg::Copyright::Grant::ByDir;

use 5.20.0;
use warnings;
use utf8;
use Carp;

use Mouse;

use Software::Copyright;
use Dpkg::Copyright::Grant::ByFile;

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

has current_dir => (
    is => 'ro',
    required => 1,
    isa => 'Path::Tiny',
);

has grants => (
    is => 'ro',
    isa => 'Dpkg::Copyright::Grant::ByFile',
    default => sub ($self) {
        return Dpkg::Copyright::Grant::ByFile->new(current_dir => $self->current_dir );
    },
    handles => [qw/delete_grant/],
);

has main_grant => (
    is => 'bare',
    isa => 'Maybe[Dpkg::Copyright::Grant::Plain]',
    writer => 'set_main_grant',
    reader => 'get_main_grant',
);

has main_grant_weight => (
    is => 'ro',
    isa => 'Int',
    writer => '_set_main_grant_weight',
    default => 0,
);

has main_grant_is_type_file => (
    is => 'ro',
    isa => 'Maybe[Bool]',
    writer => '_set_main_grant_type_file',
);

has dirs => (
    is => 'ro',
    isa => 'HashRef[Dpkg::Copyright::Grant::ByDir]',
    traits => ['Hash'],
    default => sub { {} },
    handles => {
        get_dir_names => 'keys',
    },
);

sub get_dir ($self, $path) {
    $path =~ s!/?\*?$!!;
    return $self unless $path;
    my ($subdir, $subpath) = split m!/!, $path, 2;
    my $target = $self->dirs->{$subdir}
        //= Dpkg::Copyright::Grant::ByDir->new(
            current_dir => $self->current_dir->child($subdir)
        );
    return $subpath ? $target->get_dir($subpath) : $target;
}

sub get_grant ($self, $path) {
    my ($main, $subpath) = split m!/!, $path, 2;
    return $subpath ? $self->get_dir($main)->get_grant($subpath) : $self->grants->get_grant($main);
}

sub has_dir ($self,$dir) {
    $dir =~ s!/?\*?$!!;
    if ($dir eq '.') {
        return 1;
    }
    if ($dir =~ s!^([^/]+)/!!) {
        return $self->get_dir($1)->has_dir($dir);
    }
    if (exists $self->dirs->{$dir}) {
        return 1;
    }
    return 0;
}

sub add_all_grants ($self, $grants) {
    my $count = 0;
    foreach my $path ($grants->files) {
        if (++$count % 1000 == 0  and not defined $Test::More::VERSION) {
            print STDERR "added $count grants\r";
        }

        $self->add_grant($path,$grants->get_grant($path));
    }

    if ($count > 1000 and not defined $Test::More::VERSION) {
        print STDERR "\n";
    }

    return $self;
}

sub add_grant ($self, $path, $plain_grant) {
    $path =~ s!^\./!!;
    if ($path =~ s!^([^/]+)/!!) {
        my $sub_dir = $self->get_dir($1);
        $sub_dir->add_grant($path, $plain_grant);
    }
    else {
        $self->grants->add_grant($path, $plain_grant)
    }
    return;
}

sub add_grant_info ($self, %changes) {
    my $file = delete $changes{file} || croak "missing file parameter";
    $file =~ s!^./!!;
    if ($file =~ s!^([^/]+)/!!) {
        my $sub_dir = $self->get_dir($1);
        $sub_dir->add_grant_info(file => $sub_dir, %changes);
    }
    else {
        $self->grants->add_grant_info( file => $file, %changes)
    }
    return;
}

has dir_name => (
    is => 'ro',
    isa => 'Str',
);

has dir_copyright => (
    is => 'rw',
    isa => 'Software::Copyright',
    handles => {
        map { $_ => $_ } qw/name email record identifier/
    }
);

# a short-name
has dir_license => (
    is => 'rw',
    isa => 'Str',
);

sub find_main_files ($self) {
    my %main_files;
    foreach my $name (sort $self->grants->files) {
        # that's ugly because of a moved global config variable
        if (Dpkg::Copyright::Grant::ByFile::is_overridden($name)) {
            my $hash = $self->get_grant($name)->hash;
            next unless $hash; # skip files without info
            #$self->delete_grant($name);
            $main_files{$name} = 1;
        };
    }

    foreach my $info_name (qw/README LICENSE LICENCE COPYING NOTICE COPYRIGHT/) {
        my $re = qr!(^|/)$info_name[.\w-]*$!i;
        foreach my $name (sort $self->grants->files) {
            if ($name =~ $re) {
                my $hash = $self->get_grant($name)->hash;
                #$self->delete_grant($name) if $info_name ne 'README';
                next unless $hash; # skip files without info
                $main_files{$name} = 1;
            };
        }
    }
    return keys %main_files;
}

sub find_main_grant_from_main_files ($self) {
    my @main_info_keys = sort $self->find_main_files;

    if (@main_info_keys) {
        my $main_grant = $self->get_grant(shift @main_info_keys)->clone;

        foreach my $name (@main_info_keys) {
            $main_grant->merge($self->get_grant($name));
        }
        return $main_grant;
    }
    else {
        return Dpkg::Copyright::Grant::Plain->new();
    }

}

sub count_grant ($self) {
    my %count ;
    my %grant_by_hash;
    $self->count_file_grant(\%count, \%grant_by_hash);
    $self->count_dir_grant(\%count, \%grant_by_hash);
    return (\%count, \%grant_by_hash);
}

sub count_file_grant ($self, $count, $grant_by_hash) {
    # count grant of files in this directory
    foreach my $hash (sort $self->grants->hashes) {
        my $files = $self->grants->get_hash_files($hash);
        my $sample = $self->grants->get_grant($files->[0]);
        my $lo_hash = $sample->lic_comment_owner_hash;
        $count->{$lo_hash} //= 0;
        $count->{$lo_hash} += scalar $files->@*;
        $grant_by_hash->{$lo_hash} //= $sample->clone;
        $grant_by_hash->{$lo_hash}->merge($sample);
    }
    return;
}

sub count_dir_grant ($self, $count, $grant_by_hash) {
    # count the main grant of the sub directories
    foreach my $dir (sort $self->get_dir_names) {
        my $dir = $self->get_dir($dir);
        my $dir_grant = $dir->main_grant; # recursive call
        next unless defined $dir_grant;
        next unless $dir->main_grant_is_type_file;
        my $lo_hash = $dir_grant->lic_comment_owner_hash;
        $count->{$lo_hash} //= 0;
        $count->{$lo_hash} += $dir->main_grant_weight;
        $grant_by_hash->{$lo_hash} //= $dir_grant->clone;
        $grant_by_hash->{$lo_hash}->merge($dir_grant);
    }
    return;
}

sub find_main_grant_from_files ($self) {
    # find the most used grant in this directory

    return $self->find_main_grant_from_count($self->count_grant);
}

# this count takes into account the weight of the main grant of the
# sub directory, i.e how many files are represented by the main grant
# of the sub-directory
sub find_main_grant_from_count ($self, $count, $grant_by_hash) {
    my $max = 0;
    my $main_grant;
    my $total = 0;

    # sort is required to have consistent result when there's a tie
    # between counted hashes
    my $cur_dir = $self->current_dir;
    foreach my $hash (sort keys $count->%*) {
        if ($count->{$hash} > $max) {
            $main_grant = $grant_by_hash->{$hash};
            # In subdirectories, many grants without info supersedes
            # one grant with info. This prevents a single file to
            # propagate its grants to directories above. In the top
            # directory case, we want to favor any grant that was
            # found.
            $max = $count->{$hash} unless ($cur_dir eq '.' and not $hash);
        }
    }

    # main return empty grant if no grant with info was found
    return $main_grant;
}

sub main_grant ($self) {
    # say "find_main_grant called for path ", $self->current_dir;

    if (not defined $self->{main_grant}) {
        my $main_grant = $self->find_main_grant_from_main_files ;
        my ($count, $grant_by_hash) = $self->count_grant;

        if (not $main_grant->hash) {
            # no info in main grant, grant from files wins
            my $new_grant = $self->find_main_grant_from_count($count, $grant_by_hash);
            if (defined $new_grant) {
                $main_grant = $new_grant;
                $self->_set_main_grant_weight($count->{$main_grant->lic_comment_owner_hash} // 0);
                $self->_set_main_grant_type_file(1);
            }
        }
        elsif ($grant_by_hash->{$main_grant->lic_comment_owner_hash}) {
            # use grant found in main files (README, etc...) and merge
            # in information from files of the same owner (with same
            # comment and license)
            $main_grant = $main_grant->clone->merge($grant_by_hash->{$main_grant->lic_comment_owner_hash});
            $self->_set_main_grant_weight($count->{$main_grant->lic_comment_owner_hash} // 0);
            $self->_set_main_grant_type_file(0);
        }
        else {
            $self->_set_main_grant_weight(scalar $self->grants->num_files);
            $self->_set_main_grant_type_file(0);
        }
        # else use only grant from main files
        $self->set_main_grant($main_grant);
    }
    return $self->get_main_grant();
}

# this method can be used in scanner context (to generate
# debian/copyright) file and used to fill config-model
sub debian_data ($self, %args) {
    my $hash = $args{hash} // '';

    my $grant;
    my $path;
    my $cdir = $self->current_dir;

    #say "debian_data called in $cdir for hash $hash";
    if (length($hash)) {
        # show record for a set of files pointed by hash
        return unless $hash; # null hash has no info to display
        $path = $self->grants->get_hash_files($hash)
            // croak "Unknown grant hash $hash in ",$self->current_dir," dir";
        $grant = $self->get_grant($path->[0]);
    }
    else {
        # show record for self
        # say "debian_record called for dir '$cdir'";
        $grant = $self->main_grant;
        # this makes scanner test with raku log fails
        return unless ($grant and $grant->hash); # null hash has no info to display
        $path = ['*'];
    }

    my $prefix = $cdir eq '.' ? '' : $cdir.'/';
    my $data = {
        Files => $prefix.join("\n$prefix", $path->@* ),
        Copyright => $grant->copyright->stringify || 'no-info-found',
        License => {
            short_name => $grant->license || 'UNKNOWN',
        },
    };

    if ($grant->license_text) {
        $data->{License}{full_license} = $grant->license_text;
    }
    elsif (not $grant->license) {
        $data->{License}{full_license} = "Please fill license text from header of files";
    }

    # include comments as they are provided by
    # Config::Model::Dpkg::Copyright during update operation
    $data->{Comment} = $grant->comment if $grant->comment;
    # say "debian_data called in $cdir for hash $hash exits";
    return $data;
}

sub debian_record ($self, $hash = '') {
    my $data = $self->debian_data(hash => $hash);
    return '' unless $data;
    return $self->data_to_record($data);
}

sub data_to_record ($self, $data) {
    my $str = "Files: %s\nCopyright: %s\nLicense: %s\n";

    my $copyright = $data->{Copyright};
    $copyright =~ s/\n/\n /g;

    my $files = $data->{Files};
    $files =~ s/\n/\n /g;
    my $cop_str = sprintf(
        $str,
        $files,
        $copyright,
        $data->{License}{short_name}
    );

    my $full_lic = $data->{License}{full_license};
    if ($full_lic) {
        $full_lic =~ s/\n\n/\n.\n/g;
        $full_lic =~ s/\n/\n /g;
        $cop_str .= " ". $full_lic ."\n" ;
    }

    if (my $comment = $data->{Comment}) {
        $cop_str .= "Comment: $comment\n";
    }

    return $cop_str;
}

sub debian_full_data ($self, %args) {
    my $upper_grant = $args{upper_grant} // '';
    my @records;
    my $main_grant = $self->main_grant;

    my $propagate_grant;
    if ($upper_grant and $upper_grant->contains($main_grant)) {
        # don't print directory info covered by same info in directory above
        $propagate_grant = $upper_grant;
    }
    else {
        $propagate_grant = $main_grant;
        push @records , $self->debian_data() unless $args{long};
    }

    # get records of subdirectories
    foreach my $dir (sort $self->get_dir_names) {
        push @records, $self->get_dir($dir)->debian_full_data(%args, upper_grant => $propagate_grant);
    }

    # get records of files
    foreach my $hash (sort $self->grants->hashes) {
        if ($hash) {
            my $ref = $self->grants->get_hash_files($hash)
                // croak "Unknown grant hash $hash in ",$self->current_dir," dir";
            my $grant = $self->get_grant($ref->[0]);

            next if ($propagate_grant->contains($grant) and not $args{long});
            push @records, $self->debian_data(long => $args{long}, hash => $hash);
        }
    }

    return @records;
}

sub debian_full_record ($self, %args) {
    my @records = map {$self->data_to_record($_)} $self->debian_full_data(%args);
    # need to filter empty records (when hash is 0)
    return join("\n", sort grep {$_} @records);
}

sub merge_old_dir ($self, $old_dir) {
    # files: merge only comment or license_text. data extracted from
    # file supersedes old data
    $self->grants->merge_old_grants($old_dir->grants);
    # merge sub directories
    foreach my $dir_name (sort $self->get_dir_names) {
        if ($old_dir->has_dir($dir_name)) {
            $self->get_dir($dir_name)->merge_old_dir($old_dir->get_dir($dir_name));
        }
    }

    # and merge main grant
    if ($old_dir->main_grant and not $self->main_grant) {
        $self->set_main_grant($old_dir->main_grant);
    }
    elsif ($old_dir->main_grant) {
        my $merged_grant = $self->main_grant->clone;
        $merged_grant->merge_old_grant($old_dir->main_grant);
        $self->set_main_grant($merged_grant);
    }
    return;
}
1;
