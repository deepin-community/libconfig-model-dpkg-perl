package Config::Model::Dpkg::Copyright ;

use strict;
use warnings;

use 5.020;
use IO::Pipe;

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

use base qw/Config::Model::Node/;
use Path::Tiny;
use Data::Dumper;

use Config::Model::DumpAsData;
use Dpkg::Copyright::Scanner qw/scan_files/;
use Dpkg::Copyright::Grant::ByDir;
use Dpkg::Copyright::Grant::Plain;

use Scalar::Util qw/weaken/;
use Storable qw/dclone/;

my $join_path = "\n "; # used to group Files

sub get_joined_path ($self, $paths) {
    return join ($join_path, sort @$paths);
}

sub split_path ($self,$path) {
    return ( sort ( ref $path ? @$path : split ( /[\s\n]+/ , $path ) ) );
}

sub _say ($self,@msg) {
    say @msg unless $self->{quiet};
    return;
}

sub _split_previous_data ($self) {
    my $files_obj = $self->grab("Files");

    my $old_split_files = Dpkg::Copyright::Grant::ByDir->new(current_dir =>  path('.'));

    my $debian_paths = {};
    foreach my $paths_str ($files_obj->fetch_all_indexes) {
        my $node = $files_obj->fetch_with_id($paths_str) ;
        my $dumper = Config::Model::DumpAsData->new;
        my $data = $dumper->dump_as_data( node => $node );

        my $grant = Dpkg::Copyright::Grant::Plain->new(
            copyright => $data->{Copyright},
            license => $data->{License}{short_name},
            license_text => $data->{License}{full_license} // '', # may be empty
            comment => $data->{Comment} // '', # may be empty
        );

        foreach my $path ($self->split_path($paths_str)) {
            if ($path =~ /\*$/) {
                # a bit of a hack since main_grant should be derived
                # from the content of the directory
                $old_split_files->get_dir($path)->set_main_grant($grant);
            }
            else {
                $old_split_files->add_grant($path, $grant);
            }
        }
    }

    return $old_split_files;
}

sub _set_license_data_for_a_path ($self, $new_data, $paths, $lic_usage_count ) {
    my $l = $new_data->{License}{short_name};

    # if full_license is not provided in datum, check global license(s)
    my $ok = 0;
    my @sub_licenses = split m![,\s]+ (?:and/or|or|and) [,\s]+!x,$l;
    my $lic_count = 0;
    my @empty_licenses = grep {
        my $text = $self->grab_value(steps => qq!License:"$_" text!, check =>'no') ;
        $ok++ if $text;
        $lic_count += $lic_usage_count->{$_} // 0 ;
        not $text; # to get list of empty licenses
    } @sub_licenses;

    my $full_license = $new_data->{License}{full_license};
    if ($ok eq scalar @sub_licenses) {
        $self->_say("Removing dummy license text from license $l for path ",$paths);
        delete $new_data->{License}{full_license};
    }
    elsif (not $full_license or $full_license =~ /Please fill license/) {
        my $filler = "Please fill license $l from header of $paths";
        if ($lic_count > 1 ) {
            for my $lic (@empty_licenses) {
                $self->_say("Adding dummy global license text for license $lic for path ",$paths);
                $self->load(qq!License:"$lic" text="$filler"!)
            };
        }
        else {
            $self->_say("Adding dummy license text for license $l for path ",$paths);
            $new_data->{License}{full_license} = $filler;
        }
    }
    return;
}

sub load_new_data_in_config_tree ($self, $data) {
    # count license usage to decide whether to add a global license
    # or a single entry. Skip unknown or public-domain licenses
    my %lic_usage_count;
    map { $lic_usage_count{$_}++ if $_ and not /unknown|public/i}
        map {split /\s+or\s+/, $_->{License}{short_name} // ''; }
        $data->@* ;

    # load new data in config tree
    foreach my $datum ($data->@*) {
        my $paths = delete $datum->{Files};
        $self->_set_license_data_for_a_path ( $datum, $paths, \%lic_usage_count );

        eval {
            $self->grab("Files")
                ->fetch_with_id($paths)
                ->load_data( data => $datum, check =>'yes' );
            1;
        } or do {
            die "Error: Data extracted from source file is corrupted:\n$@"
                ."This usually mean that cme or licensecheck (or both) "
                ."have a bug. You may work-around this issue by adding an override entry in "
                ."fill.copyright.blanks file. See "
                ."https://github.com/dod38fr/config-model/wiki/Updating-debian-copyright-file-with-cme "
                ."for instructions. Last but not least, please file a bug against libconfig-model-dpkg-perl.\n";
        };
    }
    return;
}

sub prune_empty_licenses ($self) {
    my $lic_obj = $self->fetch_element('License');
    foreach my $l ($lic_obj->fetch_all_indexes) {
        $lic_obj->delete($l)
            unless $lic_obj->fetch_with_id($l)->fetch_element_value('text');
    }
    return;
}

# $args{in} can contains the output of licensecheck (for tests)
sub update ($self, %args) {

    $self->{quiet} = $args{quiet} // 0;

    my $old_grants_by_dir = $self->_split_previous_data;

    my $new_grants_by_dir = scan_files( %args, get_grants => 1 );

    $new_grants_by_dir->merge_old_dir($old_grants_by_dir);

    my $current_dir = $args{from_dir} || path('.');

    # delete existing data in config tree. A more subtle solution to track which entry is
    # deleted or altered (when individual files are removed, renamed) is too complex.
    $self->grab("Files")->clear;

    my @data = $new_grants_by_dir->debian_full_data;
    $self->load_new_data_in_config_tree(\@data);

    # delete license without text
    $self->prune_empty_licenses;

    $self->_apply_fix_scan_copyright_file($current_dir) ;

    # normalize again after all the modifications
    $self->load("Files:.sort");

    $self->fetch_element("License")-> prune_unused_licenses;

    $self->instance->clear_changes; # too many changes to show users
    $self->notify_change(note => "updated copyright from source file"); # force a save

    my @msgs = (
        "Please follow the instructions given in ".__PACKAGE__." man page,",
        "section \"Tweak results\" if some license and copyright entries are wrong.",
        "Other information, like license text, can be added directly in debian/copyright file ",
        "and will be merged correctly next time this command is run.",
        "See also https://github.com/dod38fr/config-model/wiki/Updating-debian-copyright-file-with-cme"
    );

    return @msgs;
}

sub _apply_fix_scan_copyright_file ($self, $current_dir) {
    # read a debian/fix.scanned.copyright file to patch scanned data
    my $debian = $current_dir->child('debian'); # may be missing in test environment
    if ($debian->is_dir) {
        my @fixes = $current_dir->child('debian')->children(qr/fix\.scanned\.copyright$/x);
        $self->_say( "Note: loading @fixes fixes from copyright fix files") if @fixes;
        foreach my $fix ( @fixes) {
            my @l = grep { /[^\s]/ } grep { ! m!^(?:#|//)!  } $fix->lines_utf8;
            eval {
                $self->load( steps => join(' ',@l) , caller_is_root => 1 );
                1;
            } or do {
                my $e = $@;
                my $msg = $e->full_message;
                Config::Model::Exception::User->throw(
                    object => $self,
                    message => "Error while applying fix.scanned.copyright file:\n\t".$msg
                );
            }
        }
    }
    return;
}

1;

__END__

=encoding utf8

=head1 NAME

Config::Model::Dpkg::Copyright - Fill the File sections of debian/copyright file

=head1 SYNOPSIS

 # this modules is used by cme when invoked with this command
 $ cme update dpkg-copyright

=head1 DESCRIPTION

This commands helps with the tedious task of maintening
C<debian/copyright> file. When you package a new release of a
software, you can run C<cme update dpkg-copyright> to update the
content of the copyright file.

This command scans current package directory to extract copyright and
license information and store them in the Files sections of
debian/copyright file.

In debian package directory:

* run 'cme update dpkg-copyright' or 'cme update dpkg'
* check the result with your favorite VCS diff tool. (you do use
  a VCS for your package files, do you ?)

Note: this command is experimental.

=head1 Debian copyright data

The C<Files: debian/*> section from C<debian/copyright> is often the
only place containing copyright information for the files created by
Debian maintainer. So all C<Files> entries beginning with C<debian/>
are preserved during update. However, entries not matching an existing
file or directory are removed.


=head1 Tweak results

Results can be tweaked either by:

=over

=item *

Changing the list of files to scan or ignore. (By default, licensecheck will decide
which file to scan or not.)

=item *

Specifying information for individual files

=item *

Tweaking the copyright entries created by grouping and coaslescing
information.

=back

The first 2 ways are described in
L<Dpkg::Copyright::Scanner/"Selecting or ignoring files to scan">
and L<Dpkg::Copyright::Scanner/"Filling the blanks">.

The last way is described below:

=head2 Tweak copyright entries

Since the extraction of copyright information from source file is
based on comments, the result is sometimes lackluster. Your may
specify instruction to alter or set specific copyright entries in
C<debian/fix.scanned.copyright> file
(or C<< debian/<source-package>.fix.scanned.copyright >>).

L<cme> stores the copyright information in a tree. Entries in
C<fix.scanned.copyright> provide instructions for traversing the cme tree
and modifying entries. You can have a view of C<debian/copyright> file
translated in this syntax by running C<cme dump --format cml
dpkg-copyright>.  Each line of this file will be handled by
L<Config::Model::Loader> to modify copyright information; the full
syntax is documented in L<Config::Model::Loader/"load string syntax"> section.

=head2 Example

If the extracted copyright contains:

 Files: *
 Copyright: 2014-2015, Adam Kennedy <adamk@cpan.org> "foobar
 License: Artistic or GPL-1+

You may add this line in C<debian/fix.scanned.copyright> file:

 ! Files:"*" Copyright=~s/\s*".*//

This way, the copyright information will be updated from the file
content but the extra C<"foobar> will always be removed during
updates.

Comments are accepted in Perl and C++ style from the beginning of the line.
Lines breaks are ignored.

Here's another more complex example:

 // added a global license, MIT license text is filled by Config::Model
 ! copyright License:MIT

 # don't forget '!' to go back to tree root
 ! copyright Files:"pan/general/map-vector.h" Copyright="2001,Andrei Alexandrescu"
   License short_name=MIT
 # delete license text since short_name points to global  MIT license
   full_license~

 # use a loop there vvvvvv to clean up that vvvvvvvvvvvvvvvvvvvvvvv in all copyrights
 ! copyright   Files:~/.*/     Copyright=~s/all\s*rights\s*reserved//i

 # defeat spammer by replacing all '@' in emails of 3rdparty files
 # the operation :~/^3party/ loops over all Files entries that match ^3rdparty
 # and modify the copyright entry with a Perl substitution
 ! Files:~/^3rdparty/ Copyright=~s/@/(at)/

Sometimes, you might want to find an entry that spans multiple lines.
You can do this by double quoting the whole value:

 ! Files:"uulib/crc32.h
 uulib/uustring.h" Copyright="2019 John Doe"

=head1 Under the hood

This section explains how cme merges the information from the existing
C<debian/copyright> file (the "old" information) with the information
extracted by I<licensecheck> (the "new" information):

=over

=item *

The old and new information are compared in the form of file lists:

=over

=item *

New file entries are kept as is in the new list.

=item *

When a file entry is found in both old and new lists, the new © and
license short names are checked. If they are unknown, the information
from the old list is copied in the new list.

=item *

Old files entries not found in the new list are deleted.

=back

=item *

File entries are coalesced in the new list to reduce redundancies (this mechanism is explained in this L<blog|https://ddumont.wordpress.com/2015/04/05/improving-creation-of-debian-copyright-file>)

=item *

License entries are created, either attached to Files specification or as global licenses. License text is added for known license (actually known by L<Software::License>)

=item *

Directories (path ending with C</*>) from old list then checked:

=over

=item *

Directory is found in the new list: the old information is clobbered by new information.

=item *

Directory not found in new list but exists: the old information is copied in the new list.

=item *

Directory is not found: the old information is discarded

=back

=item *

Files entries are sorted and the new C<debian/copyright> is generated.

=back

=head1 update

Updates data using the output
L<Dpkg::Copyright::Scanner/scan_files">.

Parameters in C<%args>:

=over

=item quiet

set to 1 to suppress progress messages. Should be used only in tests.

=back

Otherwise, C<%args> is passed to C<scan_files>

=head1 AUTHOR

Dominique Dumont <dod@debian.org>

=cut
