package Dpkg::Copyright::Grant::ByFile;

use 5.20.0;
use warnings;
use utf8;
use Carp;

use Mouse;

use JSON;
use TOML::Tiny qw/from_toml/;
use YAML::PP qw/LoadFile/;
use Path::Tiny;
use List::MoreUtils qw/binsert bremove bsearch/;
use Log::Log4perl qw(get_logger :levels);
use Config::IniFiles;

use Software::Copyright;
use Dpkg::Copyright::Grant::Plain;
use Dpkg::Copyright::Grant::ByFile::MostRecentEmail;
use Dpkg::Copyright::Grant::ByFile::UpdatedOwner;

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

my $logger = get_logger(__PACKAGE__);

has file_to_grant => (
    is => 'ro',
    traits => ['Hash'],
    isa => 'HashRef[Dpkg::Copyright::Grant::Plain]',
    default => sub { { } },
    handles   => {
        get_grant  => 'get',
        has_grant  => 'exists',
        files      => 'keys',
        all_grants => 'values',
        num_files => 'count',
    },
);

sub delete_grant ($self, $file) {
    my $hash = $self->get_grant($file)->hash;
    my $grant = delete $self->file_to_grant->{$file};
    $self->cleanup_hash($hash, $file);
    return $grant;
}

sub cleanup_hash ($self, $hash, $file) {
    my $list_ref = $self->get_hash_files($hash);
    bremove { $_ cmp $file } $list_ref->@*;
    $self->delete_hash($hash) unless $list_ref->@*;
    return;
}

has _email_inventory => (
    is => 'ro',
    traits => ['Hash'],
    default => sub { {} },
);

sub update_email_if_more_recent ($self, $st) {
    my $inv = $self->_email_inventory->{$st->name} //=
        Dpkg::Copyright::Grant::ByFile::MostRecentEmail->new();
    return $inv->update_email_if_more_recent($st);
}

sub most_recent_email ($self, $name) {
    my $inv = $self->_email_inventory->{$name} //=
        Dpkg::Copyright::Grant::ByFile::MostRecentEmail->new();
    return $inv->email;
}

has _owner_with_no_email => (
    is => 'ro',
    traits => ['Hash'],
    default => sub { {} },
);

# was no_info_list
sub files_without_info ($self) {
    my $ref = $self->get_hash_files(0) // [];
    return $ref->@*;
}

# provides the inverse data of file_to_grant
has hash_to_files => (
    is => 'ro',
    traits => ['Hash'],
    isa => 'HashRef[ArrayRef]',
    # hash 0 is reserved for empty grant, is it still needed ??
    default => sub { { } },
    handles => {
        get_hash_files => 'get',
        set_hash_files => 'set',
        hashes         => 'keys',
        delete_hash    => 'delete',
    },
);

sub push_file_hash ($self, $hash, @files) {
    my $list_ref = $self->get_hash_files($hash);
    if (not $list_ref) {
        # bypass Mouse setter to gain perf
        $self->{hash_to_files}{$hash} = \@files;
    }
    else {
        foreach my $file (@files) {
            binsert { $_ cmp $file } $file, $list_ref->@*;
        }
    }
    return;
}

sub move_file_grant ($self, $from_hash, $to_hash, $to_grant) {
    my $file_list_ref = $self->get_hash_files($from_hash) // [];

    $logger->trace("move_file_grant from $from_hash to $to_hash");
    my @file_list = $file_list_ref->@*;
    # since the loops modifies the file list with bremove, we must use
    # a copy of this list
    foreach my $file (@file_list) {
        $logger->trace("Moving file $file from $from_hash to $to_hash...");
        $self->file_to_grant->{$file} = $to_grant;
        $self->push_file_hash($to_hash, $file);
        bremove { $_ cmp $file } $self->get_hash_files($from_hash)->@*;
    }
    return;
}

has fill_blank_data => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '_load_fill_blank_data',
);

has current_dir => (
    is => 'ro',
    required => 1,
    isa => 'Path::Tiny',
);

has quiet => (
    is => 'ro',
    isa => 'Bool',
);

sub _load_fill_blank_data ($self) {
    my %fill_blanks ;
    my $debian = $self->current_dir->child('debian'); # may be missing in test environment

    if ($debian->is_dir) {
        my @fills = $debian->children(qr/fill\.copyright\.blanks\.yml$/);

        $logger->info("Note: loading @fills fixes") if @fills;
        foreach my $file ( @fills) {
            my $data = LoadFile($file->stringify);
            foreach my $path (sort keys %$data) {
                if ($fill_blanks{$path}) {
                    $self->_warn("Warning: skipping duplicated fill blank path $path from file $file");
                }
                else {
                    $fill_blanks{$path} = $data->{$path};
                }

                foreach my $k (keys $fill_blanks{$path}->%*) {
                    die "Error in file $file: Unexpected key '$k' in path '$path'\n"
                        unless $k =~/^((forwarded-)?comment|skip|(override-)?(license|copyright))$/;
                }
            }
        }
    }

    return \%fill_blanks;
}


sub new_sc ($str) { return Software::Copyright->new($str); }

# update email in the *same* copyright grant. Email update does not
# apply accross grants
sub get_owner ($self, $name) {
    return $self->_owner_with_no_email->{$name} //=
        Dpkg::Copyright::Grant::ByFile::UpdatedOwner->new();
}

sub _update_email ($self, $file, $grant) {
    foreach my $owner (sort $grant->copyright->owners) {
        my $st = $grant->copyright->statement($owner);

        my $name = $st->name;

        next unless defined $name;
        my $updated_owner = $self->get_owner($name);

        if (defined $st->email) {
            # store email for this owner
            $self->update_email_if_more_recent($st);
            # change statement of owners without email or with an older email
            my @modified = $updated_owner->update_statement_if_more_recent($st);
            if (@modified) {
                # the line above has changed the grant hash, so update the hash info in grant
                my @new_hashes = $self->update_changed_grant(@modified);
                # and in the updated_owner object
                $updated_owner->hash(\@new_hashes);
            }
            else {
                # keep owner for further updates
                $self->get_owner($name)->add( $grant->hash, $st);
            }
        }
        elsif (my $recent_mail = $self->most_recent_email($name)) {
            # the statement has not email, add the one we've got (if any)
            $logger->trace( "$file: updating $st with $recent_mail");
            $st->email($recent_mail);
            # record the fact that the email of that owner was updated
            $updated_owner->add($grant->hash, $st);
        }
        else {
            $logger->trace( "$file: keeping $st around");
            # no email for that owner, record the owner
            $self->get_owner($name)->add( $grant->hash, $st);
        }
    }
    return;
}

sub update_changed_grant($self, @hashes) {
    my @new_hashes;
    foreach my $hash (@hashes) {
        my $file_ref = $self->delete_hash($hash);
        next unless $file_ref and $file_ref->@*;
        my $changed_grant = $self->get_grant($file_ref->[0]);
        push @new_hashes, $changed_grant->hash;
        $self->push_file_hash($changed_grant->hash, $file_ref->@*);
    }
    return @new_hashes;
}

sub add ($self, $file, $license, $copyright) {

    $self->__apply_fill_blank_overrides($file, \$license, \$copyright);

    my $grant = Dpkg::Copyright::Grant::Plain->new(
        license => $license,
        copyright => $copyright
    );

    return if $self->__skip_line ($file, $grant);

    $self->__refine_grant ($file, $grant);

    # we can't skip adding grant for files without data: this breaks
    # copyright update: when debian/copyright contains entries added
    # manually. These are dropped when the target file (or directory)
    # is removed. When skipping files without data, Config::Model
    # update can no longer distinguish between removed files and files
    # without data, so the entries added manually are lost.

    $self->_update_email($file, $grant);
    $self->add_grant($file, $grant);
    return;
}

sub add_grant ($self, $file, $grant) {
    my $hash = $grant->hash;

    if ($self->get_grant($file)) {
        croak "file $file is already registered in ".__PACKAGE__."\n";
    }
    elsif (my $other_file_array = $self->get_hash_files($hash)) {
        # grant is already known, no need to store the new object
        my $other_grant = $self->get_grant($file, $other_file_array->[0]) ;
        $self->file_to_grant->{$file} = $other_grant;
    }
    else {
        $self->file_to_grant->{$file} = $grant;
    }
    $self->push_file_hash($hash, $file);
    return;
}

# find grants that can be merged together. I.e. merge grants with same
# license and same set of owners. In this case the years are merged
# together.
sub squash_copyright_years ($self) {
    my %hash_year_by_same_owner_license;
    foreach my $grant (
        reverse sort {$a->copyright->stringify cmp $b->copyright->stringify}
        grep {$_->copyright}
        $self->all_grants
    ) {
        my $key = $grant->lic_comment_owner_hash;
        $hash_year_by_same_owner_license{$key} //= [];
        push $hash_year_by_same_owner_license{$key}->@*, $grant;
    }

    # now detect where %hash_year_by_same_owner_license references
    # more than one hash. This means that several entries can be
    # merged in a *new* grant (new grant to avoid cloberring data of
    # other directories)
    foreach my $lic_owner_hash (sort keys %hash_year_by_same_owner_license) {
        my $grant_list = $hash_year_by_same_owner_license{$lic_owner_hash};

        my @hash_list = map {$_->hash} $grant_list->@*;

        # grant_list contains grants for the same set of copyright owners
        # so we can get the owner list using any grant of the list
        my $master_grant;
        foreach my $grant ( $grant_list->@* ) {
            if (defined $master_grant) {
                my $from_hash = $grant->hash;
                # master hash is modifed by merge. so store before
                my $to_hash = $master_grant->hash;
                # no need to move and merge when 2 files point to the same grant
                if ($from_hash ne $to_hash) {
                    $master_grant->merge($grant);
                    $self->move_file_grant($from_hash, $to_hash, $master_grant);
                }
            }
            else {
                $master_grant = $grant;
            }
        }

        $self->update_changed_grant(@hash_list);
    }

    return;
}

sub _copy_license_in_readme_info ($self) {
    my $new_data = $self->get_grant('LICENSE') // $self->get_grant('LICENCE');

    if (defined $new_data and $new_data->copyright) {
        foreach my $f (sort $self->files) {
            my $c = $self->get_grant($f)->copyright;
            my $l = $self->get_grant($f)->license;
            # copy license data in README if there's copyright info and no license info
            if ($f =~ /^README/ and not $l and $c) {
                my $grant = $self->get_grant($f);
                # adding the license changes the grant content, hence
                # the grant hash is changed and the hash to file data
                # must be updated.
                # First delete the old hash to file
                $self->cleanup_hash($grant->hash, $f);
                # update the grant
                $grant->license($new_data->license);
                # update the hash to file data with the new grant
                $self->push_file_hash($grant->hash, $f);
            }
        }
    }
    return;
}

sub __skip_line ($self, $f, $grant) {
    # skip copyright because there's no need to have recursive copyrights
    # skip changelog because it often contains log entries beginning with copyright
    # and it's a collective work by nature.

    return 1 if $f =~  m!debian/(copyright|changelog)!;

    # skip copyright infos extracted from license files when they
    # come from the author of the license and not from the project
    # author
    if ($f =~  m/^COPYING|LICENSE$/) {
        my $c = $grant->copyright;
        if ($c =~ /Free Software Foundation/) {
            return 1;
        }
        if ($c =~ /Perl Foundation/) {
            return 1;
        }

        # skip license files without copyright information (usually plain license)
        return 1 if $c =~ /no-info-found/;
    }

    # this data overrides what's found in current files. This is done before
    # the code that merge and coalesce entries
    my $fill_blank = $self->__get_fill_blank($f);

    return 1 if $fill_blank->{skip};
    return 0;
}

sub __get_fill_blank ($self, $file) {
    my $fbd = $self->fill_blank_data;
    foreach my $path (reverse sort keys $fbd->%*) {
        if ($file =~ m(^$path)) {
            $fbd->{$path}{used} = 1;
            return $fbd->{$path};
        }
    }
    return {};
}

my $__extract_rakudoc_info = sub ($file, $grant, $current_dir) {
    my $rakudoc = $current_dir->child($file);

    if ($rakudoc->is_file) {
        foreach my $line ($rakudoc->lines_utf8) {
            if ($line =~ /^=AUTHOR\s+(.*)/) {
                my $author = $1;
                # do not override actual info coming from licensecheck
                $grant->copyright(new_sc($author)) unless $grant->copyright;
                last;
            }
        }
    }
    return;
};

my $__extract_dist_ini_info = sub ($file, $grant, $current_dir) {
    my $dist_ini = $current_dir->child($file);
    my $cfg;

    if ($dist_ini->is_file) {
        $cfg = Config::IniFiles->new(
            -file => $dist_ini->stringify,
            -fallback => 'top',
        );
    }

    if (defined $cfg) {
        $grant->license($cfg->val(qw/top license/)) if $cfg->exists(qw/top license/);

        if ($cfg->exists(qw/top copyright_holder/) or $cfg->exists(qw/top copyright_year/)) {
            $grant->copyright(new_sc(
                $cfg->val(top => copyright_year => '') . ', ' .
                $cfg->val(top => copyright_holder => '')
            ));
        }
    }
    return;
};

my $__extract_rust_info = sub ($file, $grant, $current_dir) {
    my $cargotoml = $current_dir->child($file);

    if ($cargotoml->is_file) {
        my $toml = $cargotoml->slurp_utf8;

        my $data_raw = eval {from_toml($toml);};
        if ($@) {
            warn "Error while parsing $cargotoml: $@";
            return;
        }

        # cope with https://doc.rust-lang.org/cargo/reference/workspaces.html
        my $data = $data_raw->{workspace} // $data_raw;
        my $license = $data->{'package'}{'license'};
        my $authors = $data->{'package'}{'authors'} // [];

        if (ref($authors) eq 'ARRAY' and @$authors) {
            $grant->copyright(new_sc(join("\n", @$authors)));
        }

        if (defined $license and ref($license) eq '') {
            # Cargo.toml spells AND and OR in capitals
            # and allows / as a synonym to OR
            $license =~ s! AND ! and !g;
            $license =~ s! OR ! or !g;
            $license =~ s!/! or !g;
            $grant->license($license);
        }
    }
    return;
};

my $__extract_nodejs_info = sub ($c_key, $l_key, $file, $grant, $current_dir) {
    my $json_file = $current_dir->child($file);

    if ($json_file->is_file) {
        my $json = $json_file->slurp_utf8;
        # remove crap like BOM
        $json =~ s/^[^{]+//;
        my $data = eval { from_json($json) };
        if ($@) {
            warn "Error while parsing $json_file: $@";
            return;
        }

        my @c_data;
        if  (ref $data->{$c_key}) {
            if (ref $data->{$c_key} eq 'HASH') {
                if (exists($data->{$c_key}->{name})) {
                    @c_data = ($data->{$c_key}->{name});
                }
            }
            else {
                @c_data = ($data->{$c_key}->@*);
            }
        } elsif (defined $data->{$c_key}) {
            @c_data = ($data->{$c_key});
        }

        if (@c_data) {
            $grant->copyright(new_sc(join("\n", @c_data)));
        }

        my @l_data;
        # see https://docs.npmjs.com/cli/v6/configuring-npm/package-json
        if (ref $data->{$l_key} eq 'ARRAY') {
            # deprecated in package.json
            if (ref $data->{$l_key}[0] eq 'HASH') {
                @l_data = map {$_->{type}} $data->{$l_key}->@*;
            } else {
                @l_data = $data->{$l_key}->@*;
            }
        } elsif (ref $data->{$l_key} eq 'HASH') {
            # deprecated in package.json
            @l_data = ($data->{$l_key}{type});
        } else {
            @l_data = ($data->{$l_key});
        }

        if (@l_data) {
            $grant->license(join(" or ",@l_data));
        }
    }
    return ;
};

my $__extract_json_info = sub ($c_key, $l_key, $file, $grant, $current_dir) {
    my $json_file = $current_dir->child($file);

    if ($json_file->is_file) {
        my $data = from_json($json_file->slurp_utf8);
        my @c_data = ref $data->{$c_key} ? $data->{$c_key}->@* : $data->{$c_key};
        if (@c_data) {
            $grant->copyright(new_sc(join("\n", @c_data)));
        }
        my @l_data = ref $data->{$l_key} ? $data->{$l_key}->@* : $data->{$l_key};
        if (@l_data) {
            $grant->license(join(" or ",@l_data));
        }
    }
    return;
};

my $_cleanup_license = sub ($file, $grant, $current_dir) {
    if ($grant->license =~ /^Artistic/) {
        my $copyright = $grant->copyright;

        if ($copyright =~ /Perl Foundation/ or $copyright =~ /^\d+$/) {
            # Artistic license contains the copyright of Artistic license,
            # and not the copyright of the software owner, so its
            # copyright information is trashed
            $grant->copyright(new_sc(''));
        }
    }
    return;
};

my %override = (
    'Cargo.toml' => $__extract_rust_info,
    'package.json' => sub {$__extract_nodejs_info->('author','license',@_)},
    'META.json' => sub {$__extract_json_info->('author','license',@_)},
    'META6.json' => sub {$__extract_json_info->('authors','license',@_)},
    'README.rakudoc' => $__extract_rakudoc_info,
    'dist.ini' => $__extract_dist_ini_info,
    'LICENSE' => $_cleanup_license,
    'LICENCE' => $_cleanup_license,
);

# keep this ugliness until Scanner refactor is complete
sub is_overridden ($f) {
    return defined $override{$f};
}

sub __refine_grant ($self, $file, $grant) {
    # override license information by scanning special file
    my @names = split m!/!,$file;
    if ($override{$names[-1]}) {
        $override{$names[-1]}->($file, $grant, $self->current_dir);
    }

    $self->__apply_fill_blank($file, $grant);
    return;
}

sub __apply_fill_blank_overrides ($self, $file, $l, $c) {
    my $fill_blank = $self->__get_fill_blank($file);

    if ($fill_blank->{'override-copyright'}) {
        $logger->info("Overriding path $file copyright info");
        $$c = $fill_blank->{'override-copyright'};
    }
    if ($fill_blank->{'override-license'}) {
        $logger->info("Overriding path $file license info");
        $$l = $fill_blank->{'override-license'};
    }
    return;
}

sub __apply_fill_blank ($self, $file, $grant) {
    my $fill_blank = $self->__get_fill_blank($file);

    my $c = $grant->copyright;
    if ( not $c and $fill_blank->{copyright} ) {
        $grant->copyright(new_sc($fill_blank->{copyright}));
    }

    my $l = $grant->license;
    if ( not $l and $fill_blank->{license} ) {
        $grant->license( $fill_blank->{license});
    }

    if ( not $grant->comment and $fill_blank->{'forwarded-comment'} ) {
        $grant->comment( $fill_blank->{'forwarded-comment'});
    }

    return ;
}

sub _warn ($self, $msg) {
    $logger->warn($msg) unless $self->quiet;
    return;
}

# TODO: check output
sub warn_user_about_problems ($self) {
    if ($self->files_without_info) {
        my $msg= "The following paths are missing information:\n";
        map {
            $msg .= "- $_\n";
        } $self->files_without_info;
        $msg .= "You may want to add a line in debian/fill.copyright.blanks.yml\n\n";
        $self->_warn($msg);
    }

    my @notused = grep { not $self->fill_blank_data->{$_}{used} and $_; } sort keys $self->fill_blank_data->%* ;
    if (@notused) {
        $self->_warn(
            "Warning: the following entries from fill.copyright.blanks.yml were not used\n- '"
            .join("'\n- '",@notused)."'\n"
        );
    }

    $self->_warn("No copyright information found") unless $self->files;

    return;
}

sub merge_old_grants ($self, $old_grants) {
    foreach my $file ($self->files) {
        if (my $og = $old_grants->get_grant($file)) {
            # need to split grant if merge modifies the old grant
            # and then merge the merged grant in file stuff
            my $file_grant = $self->get_grant($file);
            my $merged_grant = $file_grant->clone;
            $merged_grant->merge_old_grant($og);
            if ($merged_grant->hash ne $file_grant->hash) {
                $self->delete_grant($file);
                $self->add_grant($file, $merged_grant);
            }
        }
    }
    return;
}

sub add_grant_info ($self, %changes) {
    my $file = delete $changes{file} || croak "missing file parameter";

    my $grant = $self->delete_grant($file)->clone;
    croak "add_grant_info: unknow file $file" unless $grant;

    foreach my $what (sort keys %changes) {
        $grant->$what($changes{$what});
    }

    $self->add_grant($file, $grant);
    return;
}


1;
