package Dpkg::Copyright::Scanner ;

use strict;
use warnings;

use 5.20.0;
use Exporter::Lite;
use Array::IntSpan;
use Path::Tiny;
use Time::localtime;
use Carp;
use Software::Copyright;
use Dpkg::Copyright::Grant::ByFile;
use Dpkg::Copyright::Grant::ByDir;
use Log::Log4perl qw(get_logger :levels);
use YAML::PP qw/LoadFile/;

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

binmode STDOUT, ':encoding(utf8)';

our @EXPORT_OK = qw(scan_files generate_copyright print_copyright);

my $logger = get_logger(__PACKAGE__);

my $whitespace_list_delimiter = $ENV{'whitespace_list_delimiter'} || "\n ";

# license and copyright sanitisation pilfered from Jonas's
# licensecheck2dep5 Originally GPL-2+, permission to license this
# derivative work to LGPL-2.1+ was given by Jonas.
# see https://lists.alioth.debian.org/pipermail/pkg-perl-maintainers/2015-March/084900.html

# Copyright 2014-2020 Dominique Dumont <dod@debian.org>
# Copyright © 2005-2012 Jonas Smedegaard <dr@jones.dk>
# Description: Reformat licencecheck output to copyright file format
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

sub generate_copyright ( %args ) {
    my $grants_by_dir = scan_files(%args, get_grants => 1);

    printf STDERR "Generating copyright data...\n" unless defined $Test::More::VERSION;

    my $out = $grants_by_dir->debian_full_record(%args);

    print STDERR "Copyright data generation done\n" unless defined $Test::More::VERSION;

    return $out;
}

sub print_copyright ( %args ) {
    my $output = generate_copyright(%args);

    if ($args{out}) {
        $args{out}->spew_utf8( $output );
    }
    else {
        binmode(STDOUT, ":encoding(UTF-8)");
        print $output
    }

    return $output;
}

my $quiet;

sub _warn ($msg) {
    warn $msg unless $quiet;
    return;
}

# from licensecheck.pl
my $ignore_regexp = qr!
# Ignore general backup files
~$|
# Ignore emacs recovery files
(^|/)\.#|
# Ignore vi swap files
\.swp$|
# Ignore baz-style junk files or directories
(^|/),,.*(?:$|/.*$)|
# File-names that should be ignored (never directories)
(^|/)(DEADJOE|\.cvsignore|\.arch-inventory|\.bzrignore|\.gitignore)$|
# File or directory names that should be ignored
(^|/)(CVS|RCS|\.pc|\.deps|\{arch\}|\.arch-ids|\.svn|\.hg|_darcs|\.git|
\.shelf|_MTN|\.bzr(?:\.backup|tags)?)(?:$|/.*$)|
# skip debian files that are too confusing or too short
(?:^|/)debian/((fix.scanned.)?copyright|changelog|NEWS|compat|.*yml|docs|source|patches/series)|
# skip some binary or generated files
\.(gif|png|tif|jpg|pdf|ico|bmp|jpe?g|zip|gz|xz|gmo|jar|gpg|cdy|tfm|ttf|doc|hnt|xslx|o?dvi|vf\d?|vsd|ocp|mp4|[otf]fm|pfb|u3d|otf|e?ps)$
!xi ;

# cleanup the regexp
$ignore_regexp =~ s/#.*\n//g;
$ignore_regexp =~ s/[\s\n]+//g;

sub _compute_ignore_regexps($current_dir) {
    my $scan_data = {};
    my $debian = $current_dir->child('debian');
    my $scan_patterns = $debian->child("copyright-scan-patterns.yml");

    if ($debian->is_dir and $scan_patterns->is_file) {
        $scan_data = LoadFile($scan_patterns->stringify);
    }

    # licensecheck --check is broken ( #842368 ), so --skipped option is useless.
    # let's scan everything and skip later in _parse_lines
    my $data = $scan_data->{ignore} || {};
    return join(
        '|' ,
        (map { '\.'.$_.'$'} @{$data->{suffixes} || []}),
        @{ $data->{pattern} || []},
        $ignore_regexp
    );
}

sub _get_data_from_files  ( %args ) {
    my $current_dir = $args{from_dir} || path('.');
    my $count = 0;

    my $grants = Dpkg::Copyright::Grant::ByFile->new(
        current_dir => $current_dir,
        quiet => $quiet,
    );

    my $ign_regexps = _compute_ignore_regexps($current_dir);

    my @skipped;

    if ($args{in}) {
        # used for tests
        foreach my $line ($args{in}->lines_utf8) {
            # old test files begin with ./
            $line =~ s!^\./!!;
            if (++$count % 1000 == 0 and not defined $Test::More::VERSION) {
                print STDERR "parsed $count lines from input file\r";
            }
            _parse_one_line($grants, $line, \@skipped);
        }
    }
    else {
        my $length = length($current_dir->stringify) + 1;
        my $lic_cmd = 'licensecheck --encoding utf8 --copyright --machine '
            .'--lines=300 --shortname-scheme=debian,spdx --recursive '
            . "'--ignore=%s' %s";
        my $cmd = sprintf($lic_cmd, $ign_regexps, $current_dir);
        open(my $pipe, "-|", $cmd) or die "Can't open '$cmd' : $!\n";;
        binmode($pipe, ":encoding(UTF-8)");

        while (my $raw_line = $pipe->getline) {
            last unless defined $raw_line;
            my $line = substr($raw_line, $length);
            if (++$count % 1000 == 0 and not defined $Test::More::VERSION) {
                print STDERR "parsed $count lines from licensecheck\r";
            }
            if ($args{dump}) {
                print $line;
            }
            else {
                _parse_one_line($grants, $line, \@skipped);
            }
        }

        $pipe->close or die $! ? "Error closing licensecheck pipe: $!\n"
                               : "Exit status ".$?." $cmd\n";
    }

    if ($count > 1000 and not defined $Test::More::VERSION) {
        print STDERR "\n";
    }

    exit 0 if $args{dump};

    if (@skipped) {
        my $msg= "The following files were skipped:\n";
        map {
             $msg .= "- $_\n";
         } @skipped;
        $msg .= "You may want to add a line in debian/copyright-scan-patterns.yml\n"
            ."or ask the author to add more default patterns to scan\n\n";
        _warn $msg;
    }

    return ($grants);
}

sub _parse_one_line ($grants, $line, $skipped) {
    chomp $line;
    my ($f,$l,$c) = split /\t/, $line;
    $f =~ s!^\./!!;

    $grants->add ( $f, $l, $c);

    return;
}

# option to skip UNKNOWN ?
# load a file to override some entries ?
sub scan_files ( %args ) {
    $quiet = $args{quiet} // 0;

    my $grants = _get_data_from_files( %args );

    # When README.* has no license info, get it from LICENSE file
    $grants->_copy_license_in_readme_info();

    $grants->squash_copyright_years;

    $grants->warn_user_about_problems;

    my $dir = Dpkg::Copyright::Grant::ByDir->new(current_dir => path('.'));
    $dir->add_all_grants($grants);
    return $dir;
}

1;

__END__

=encoding utf8

=head1 NAME

 Dpkg::Copyright::Scanner - Scan files to provide copyright data

=head1 SYNOPSIS

 use Dpkg::Copyright::Scanner qw/print_copyright scan_files/;

 # print copyright data on STDOUT
 print_copyright;

 # return a data structure containing copyright information
 my @copyright_data = scan_files();


=head1 DESCRIPTION

This modules scans current package directory to extract copyright and
license information. Information are packed in a way to ease review and
maintenance. Files information is grouped with wildcards ('*') to reduce
the list of files.

=head2 About LICENSE and README files

Projects often store global copyright information, i.e. information
that apply to all files of a project (unless specified otherwise in
some files) in README or LICENSE or COPYING file.

The information contained in these files id merged and applied to the
directory entry that contain them.

I.e files like:

 foo_comp/README: (c) 2018 Joe, GPL-2
 foo_comp/LICENSE: (c) 2017 Max, GPL-3

yield the following copyright entries:

 foo_comp/*:
 Copyright: 2018 Joe
   2019 Max
 License: GPL-2 or GPL-3

 README:
 Copyright: 2018 Joe
 License: GPL-2

=head1 Ignoring files to scan

By default, scanner scans all source files and skip binary files,
backup and archive files.

If needed, this behavior can tuned with
C<debian/copyright-scan-patterns.yml> file. This YAML file contains a
list of suffixes or patterns to ignore that are added to the default
list. Any file that is ignored will be shown as "skipped".

This file must have the following structure (all fields are optional
and order does not matter):

 ---
 ignore :
   suffixes :
     - yml
   pattern :
     - /t/
     - /models/
     - /debian/
     - /Changes

Do not specify the dot with the suffixes. This will be added by the scanner.

=head1 Filling the blanks

Sometimes, upstream coders are not perfect: some source files cannot
be parsed correctly or some legal information is missing.

All scanned files, even without copyright or license will be used. A
warning will be shown for each file with missing information.

Instead of patching upstream source files to fill the blank, you can
specify the missing information in a special file. This file is
C<debian/fill.copyright.blanks.yml>. It should contain a "mapping"
YAML structure (i.e. a hash), where the key is a Perl pattern used to
match a path. 

If the source of the package contains a lot of files without legal
information, you may need to specify there information for a whole
directory (See the C</src> dir in the example below).

For instance:

 ---
 debian:
   copyright: 2015, Marcel
   license: Expat
 src/:
   copyright: 2016. Joe
   license: Expat
 share/pkgs/openSUSE/systemd/onedsetup:
   copyright: 2015, Marcel
 share/vendor/ruby/gems/rbvmomi/lib/rbvmomi.*\.rb:
   license: Expat
 .*/NOTICE:
   skip: 1
 share/websockify/:
   license: LGPL-2
 src/sunstone/:
   license: Apache-2.0
   forwarded-comment: found main license in foo.cc
 src/garbled/:
   'override-copyright': 2016 Marcel Mézigue
   comment: for bookkeeping

Patterns are matched from the beginning a
path. I.e. C<share/websockify/> pattern will match
C<share/websockify/foo.rb> but will not match
C<web/share/websockify/foo.rb>.

Patterns are tried in reversed sorted order. I.e. the data attached to
more specific path (e.g. C<3rdparty/foo/blah.c>) are applied before
more generic patterns (e.g. C<3rdparty/foo/>

The C<license> key must contain a license short name as returned by
C<license_check>.

When C<skip> is true, the file is skipped like a file without any
information.

The C<forwared-comment> value is copied verbation to the C<Comment>
field of the target entry in Debian copyright file (unless C<skip> is
true).

The C<comment> value is ignored and can be used for book keeping.

The C<override-copyright> and C<override-license> keys can be used to
ignore the copyright information coming from the source and provide
the correct information. Use this as last resort for instance when the
encoding of the owner is not ascii or utf-8 or when the license data
is corrupted. Note that a warning will be shown each time an override
key is used.

=head1 METHODS

=head2 print_copyright

Print copyright information on STDOUT like L<scan-copyrights>.

=head2 scan_files ( %args )

Return a data structure with copyright and license information.

The structure is a list of list:

 [
   [
     [ path1 ,path2, ...],
     copyright,
     license_short_name
   ],
   ...
 ]

Example:

 [
  [
    [ '*' ],
    '1994-2001, by Frank Pilhofer.',
    'GPL-2+'
  ],
  [
    [ 'pan/*' ],
    '2002-2006, Charles Kerr <charles@rebelbase.com>',
    'GPL-2'
  ],
  [
    [
      'pan/data/parts.cc',
      'pan/data/parts.h'
    ],
    '2002-2007, Charles Kerr <charles@rebelbase.com>',
    'GPL-2'
  ],
 ]

Parameters in C<%args>:

=over

=item quiet

set to 1 to suppress progress messages. Should be used only in tests.

=item long

set to 1 to avoid squashing copyright ids. Useful to avoid output with wild cards.

=back


=head1 Encoding

The output of L<licensecheck> is expected to be utf-8. Which means
that the source files scanned by L<licensecheck> should also be
encoded in utf-8. This program will abort if invalid utf-8 characters
are found.

=head1 BUGS

Extracting license and copyright data from unstructured comments is not reliable.
User must check manually the files when no copyright info is found or when the
license is unknown.

Source files are assumed to be utf8 (or ascii). Using files with invalid characters
will break C<cme>. In this case, you can:

=over

=item *

Patch source files to use utf-8 encoding.

=item *

Use the "fill copyright blank" mechanism described above with
C<copyright-override> to provide an owner name with the correct
encoding.

=item *

File a bug against licensecheck package to find a better solution.

=back

=head1 SEE ALSO

L<licensecheck>, C<licensecheck2dep5> from C<cdbs> package

=head1 AUTHOR

Dominique Dumont <dod@debian.org>

=cut

