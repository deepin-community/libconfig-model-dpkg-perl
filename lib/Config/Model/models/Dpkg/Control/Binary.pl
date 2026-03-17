use strict;
use warnings;

return [
  {
    'accept' => [
      '.*',
      {
        'description' => 'Additional user-defined fields

Fields in the main source control information file with names starting X, followed by one or more of the letters BCS and a hyphen -, will be copied to the output files. Only the part of the field name after the hyphen will be used in the output file. Where the letter B is used the field will appear in binary package control files, where the letter S is used in Debian source control files and where C is used in upload control (.changes) files.

For details, see L<section 5.7 of Debian policy|https://www.debian.org/doc/debian-policy/ch-controlfields.html>',
        'summary' => 'User defined field',
        'type' => 'leaf',
        'value_type' => 'string'
      }
    ],
    'author' => [
      'Dominique Dumont'
    ],
    'copyright' => [
      '2010,2011 Dominique Dumont'
    ],
    'element' => [
      'Architecture',
      {
        'description' => 'If a program needs to specify an architecture specification string in some place, it should select one of the strings provided by dpkg-architecture -L. The strings are in the format os-arch, though the OS part is sometimes elided, as when the OS is Linux. 
A package may specify an architecture wildcard. Architecture wildcards are in the format any (which matches every architecture), os-any, or any-cpu. For more details, see L<Debian policy|http://www.debian.org/doc/debian-policy/ch-customized-programs.html#s-arch-spec>',
        'mandatory' => '1',
        'type' => 'leaf',
        'value_type' => 'string'
      },
      'Multi-Arch',
      {
        'choice' => [
          'no',
          'same',
          'foreign',
          'allowed'
        ],
        'description' => 'This field is used to indicate how this package should behave on a multi-arch installations. This field should not be present in packages with the Architecture: all field.',
        'help' => {
          'allowed' => 'allows reverse-dependencies to indicate in their Depends field that they need a package from a foreign architecture, but has no effect otherwise.',
          'foreign' => 'the package is not co-installable with itself, but should be allowed to satisfy the dependency of a package of a different arch from itself.',
          'no' => 'the package is not co-installable and it must not be used to satisfy the dependency of any package of another architecture than its own.',
          'same' => 'the package is co-installable with itself, but it must not be used to satisfy the dependency of any package of a different architecture from itself.'
        },
        'type' => 'leaf',
        'value_type' => 'enum'
      },
      'Section',
      {
        'compute' => {
          'formula' => '$source',
          'use_as_upstream_default' => '1',
          'variables' => {
            'source' => '- - source Section'
          }
        },
        'type' => 'leaf',
        'value_type' => 'uniline',
        'warn_unless' => {
          'area' => {
            'code' => '(not defined) or m!^((contrib|non-free)/)?[\\w\\-]+$!;',
            'msg' => 'Bad area. Should be \'non-free\' or \'contrib\''
          },
          'section' => {
            'code' => '(not defined) or m!^([-\\w]+/)?(admin|cli-mono|comm|database|devel|debug|doc|editors|education|electronics|embedded|fonts|games|gnome|golang|graphics|gnu-r|gnustep|hamradio|haskell|httpd|interpreters|introspection|java|javascript|kde|kernel|libs|libdevel|lisp|localization|mail|math|metapackages|misc|net|news|ocaml|oldlibs|otherosfs|perl|php|python|ruby|rust|science|shells|sound|tex|text|utils|vcs|video|web|x11|xfce|zope)$!;',
            'msg' => 'Bad section.'
          }
        }
      },
      'Priority',
      {
        'choice' => [
          'required',
          'important',
          'standard',
          'optional',
          'extra'
        ],
        'compute' => {
          'formula' => '$source',
          'use_as_upstream_default' => '1',
          'variables' => {
            'source' => '- - source Priority'
          }
        },
        'type' => 'leaf',
        'value_type' => 'enum'
      },
      'Essential',
      {
        'description' => 'The package is an essential package as defined by Debian Policy. The following
rules apply to the package:

'.'=over

'.'=item *

Essential packages are considered essential for the system to work.
The packaging system (APT and dpkg) will warn and refuse to uninstall
them without some very insistent force options.

'.'=item *

Other packages are not required to declare explicit dependencies on
essential packages as a side-effect of the above except as needed to
ensure that the given essential package is upgraded to a given minimum
version.

'.'=item *

Once installed, essential packages must function at all times no
matter where dpkg is in its installation or upgrade process. During
bootstrapping or installation, this requirement is relaxed.

'.'=back

Note that if you are looking for a way to prevent accidental uninstallation, please consider using C<Protected: yes> instead.
',
        'summary' => 'The package is essential as defined by Debian Policy',
        'type' => 'leaf',
        'value_type' => 'boolean'
      },
      'XB-Important',
      {
        'description' => 'This is the prototype field that led to `Protected`, which should be used instead.

It makes `apt` (but not `dpkg`) require extra confirmation before removing the package.',
        'status' => 'deprecated',
        'summary' => 'Obsolete and incomplete variant of the Protected field',
        'type' => 'leaf',
        'upstream_default' => 'no',
        'value_type' => 'boolean'
      },
      'Protected',
      {
        'description' => 'Declare this package as a system critical package. When the field is set to C<yes>, both C<apt>
and C<dpkg> will assume that removing the package B<may> break the system. As a consequence,
they will require extra confirmation (or "force" options) before removing the package.
This field basically provides "uninstall" protection similar to that of C<Essential> packages
without the other benefits and requirements that come with C<Essential> packages. In a Debian
context, this field is generally applicable to packages like bootloaders, kernels, and other
packages that might be necessary for booting the system.
',
        'help' => {
          'no' => 'The package is a regular package.  This is the default and recommended.',
          'yes' => 'The package is protected and attempts to uninstall it will cause strong warnings to the user that they might be breaking the system.'
        },
        'migrate_from' => {
          'formula' => '$xbi',
          'variables' => {
            'xbi' => '- XB-Important'
          }
        },
        'summary' => 'Mark as Protected (uninstall protection)',
        'type' => 'leaf',
        'upstream_default' => 'no',
        'value_type' => 'boolean'
      },
      'Depends',
      {
        'cargo' => {
          'class' => 'Config::Model::Dpkg::Dependency',
          'type' => 'leaf',
          'value_type' => 'uniline',
          'warn_if_match' => {
            '^perl$' => {
              'fix' => '$_ = \'${perl:Depends}\';',
              'msg' => 'perl dependency better written as ${perl:Depends}'
            }
          },
          'warn_unless' => {
            'libtiff4 transition' => {
              'code' => 'not defined $_ or not /libtiff4/ or /libtiff4\\s*\\(>=\\s*3.9.5-2\\s*\\)/',
              'fix' => '$_ = \'libtiff4 (>= 3.9.5-2)\';',
              'msg' => 'libtiff4 is transtioning to versioned symbols. New packages should build-depend on libtiff4 (>= 3.9.5-2).'
            }
          }
        },
        'class' => 'Config::Model::Dpkg::DependencyList',
        'description' => 'The Depends field should be used if the depended-on package is required for the depending package to provide a significant amount of functionality. See also L<debian policy|https://www.debian.org/doc/debian-policy/ch-relationships.html>',
        'duplicates' => 'warn',
        'summary' => 'declares an absolute dependency.',
        'type' => 'list'
      },
      'Recommends',
      {
        'cargo' => {
          'class' => 'Config::Model::Dpkg::Dependency',
          'type' => 'leaf',
          'value_type' => 'uniline'
        },
        'class' => 'Config::Model::Dpkg::DependencyList',
        'description' => 'This field should list packages that would be found together with this one in all but unusual installations. See also L<debian policy|https://www.debian.org/doc/debian-policy/ch-relationships.html>',
        'duplicates' => 'warn',
        'summary' => 'declares a strong, but not absolute, dependency.',
        'type' => 'list'
      },
      'Suggests',
      {
        'cargo' => {
          'class' => 'Config::Model::Dpkg::Dependency',
          'type' => 'leaf',
          'value_type' => 'uniline'
        },
        'class' => 'Config::Model::Dpkg::DependencyList',
        'description' => 'Using this field tells the packaging system and the user that the listed packages are related to this one and can perhaps enhance its usefulness, but that installing this one without them is perfectly reasonable. See also L<debian policy|https://www.debian.org/doc/debian-policy/ch-relationships.html> ',
        'duplicates' => 'warn',
        'summary' => 'declare that one package may be more useful with one or more others.',
        'type' => 'list'
      },
      'Enhances',
      {
        'cargo' => {
          'class' => 'Config::Model::Dpkg::Dependency',
          'type' => 'leaf',
          'value_type' => 'uniline'
        },
        'description' => 'This field is similar to Suggests but works in the opposite direction. It is used to declare that a package can enhance the functionality of another package. See also L<debian policy|https://www.debian.org/doc/debian-policy/ch-relationships.html>',
        'summary' => 'declare that a package can enhance the functionality of another package',
        'type' => 'list'
      },
      'Pre-Depends',
      {
        'cargo' => {
          'class' => 'Config::Model::Dpkg::Dependency',
          'type' => 'leaf',
          'value_type' => 'uniline'
        },
        'class' => 'Config::Model::Dpkg::DependencyList',
        'description' => 'This field is like Depends, except that it also forces dpkg to complete installation of the packages named before even starting the installation of the package which declares the pre-dependency.  See also L<debian policy|https://www.debian.org/doc/debian-policy/ch-relationships.html>',
        'type' => 'list'
      },
      'Breaks',
      {
        'cargo' => {
          'class' => 'Config::Model::Dpkg::Dependency',
          'type' => 'leaf',
          'value_type' => 'uniline'
        },
        'class' => 'Config::Model::Dpkg::DependencyList',
        'description' => 'When one binary package declares that it breaks another, dpkg will refuse to allow the package which declares Breaks to be unpacked unless the broken package is deconfigured first, and it will refuse to allow the broken package to be reconfigured. See also L<debian policy|https://www.debian.org/doc/debian-policy/ch-relationships.html>',
        'type' => 'list'
      },
      'Conflicts',
      {
        'cargo' => {
          'class' => 'Config::Model::Dpkg::Dependency',
          'type' => 'leaf',
          'value_type' => 'uniline'
        },
        'class' => 'Config::Model::Dpkg::DependencyList',
        'description' => 'When one binary package declares a conflict with another using a Conflicts field, dpkg will refuse to allow them to be unpacked on the system at the same time. This is a stronger restriction than Breaks, which prevents the broken package from being configured while the breaking package is in the "Unpacked" state but allows both packages to be unpacked at the same time. See also L<debian policy|https://www.debian.org/doc/debian-policy/ch-relationships.html>',
        'type' => 'list'
      },
      'Provides',
      {
        'cargo' => {
          'type' => 'leaf',
          'value_type' => 'uniline'
        },
        'class' => 'Config::Model::Dpkg::DependencyList',
        'description' => 'declare the functionality brought by this package. Be sure to read the chapter about virtual package in L<debian policy|https://www.debian.org/doc/debian-policy/ch-relationships.html> before using this parameter',
        'type' => 'list'
      },
      'Replaces',
      {
        'cargo' => {
          'class' => 'Config::Model::Dpkg::Dependency',
          'type' => 'leaf',
          'value_type' => 'uniline'
        },
        'class' => 'Config::Model::Dpkg::DependencyList',
        'description' => 'declare that this package should overwrite files in certain other packages, or completely replace other packages. Be sure to read the section 7.6 of L<debian policy|https://www.debian.org/doc/debian-policy/ch-relationships.html> before using this parameter',
        'type' => 'list'
      },
      'Built-Using',
      {
        'cargo' => {
          'class' => 'Config::Model::Dpkg::Dependency',
          'type' => 'leaf',
          'value_type' => 'uniline',
          'warn_unless_match' => {
            '\\$\\{[[:alnum:]][[:alnum:]\\-:]+\\}' => {
              'msg' => 'Built-Using should be filled with a substvar.'
            }
          }
        },
        'class' => 'Config::Model::Dpkg::DependencyList',
        'description' => 'Some binary packages incorporate parts of other packages when built but do not have to depend on those packages. Examples include linking with static libraries or incorporating source code from another package during the build. In this case, the source packages of those other packages are a required part of the complete source (the binary package is not reproducible without them).

A Built-Using field must list the corresponding source package for any such binary package incorporated during the build, including an "exactly equal" ("=") version relation on the version that was used to build that binary package.

A package using the source code from the gcc-4.6-source binary package built from the gcc-4.6 source package would have this field in its control file:

     Built-Using: gcc-4.6 (= 4.6.0-11)

A package including binaries from grub2 and loadlin would have this field in its control file:

     Built-Using: grub2 (= 1.99-9), loadlin (= 1.6e-1)',
        'duplicates' => 'warn',
        'summary' => 'Additional source packages used to build the binary',
        'type' => 'list'
      },
      'Package-Type',
      {
        'choice' => [
          'tdeb',
          'udeb'
        ],
        'description' => 'If this field is present, the package is not a regular Debian package, but either a udeb generated for the Debian installer or a tdeb containing translated debconf strings.',
        'migrate_from' => {
          'formula' => '$xc',
          'variables' => {
            'xc' => '- XC-Package-Type'
          }
        },
        'summary' => 'The type of the package, if not a regular Debian one',
        'type' => 'leaf',
        'value_type' => 'enum'
      },
      'XC-Package-Type',
      {
        'choice' => [
          'tdeb',
          'udeb'
        ],
        'description' => 'If this field is present, the package is not a regular Debian package, but either a udeb generated for the Debian installer or a tdeb containing translated debconf strings.',
        'status' => 'deprecated',
        'summary' => 'The type of the package, if not a regular Debian one',
        'type' => 'leaf',
        'value_type' => 'enum'
      },
      'Synopsis',
      {
        'description' => 'In a source template control file or binary control file, the Description field contains a description of the binary package, consisting of two parts, the synopsis or the short description, and the long description.

Im cme, the 2 parts have their own entry: Synopsis and Description. 

This is the Synopsis, i.e. the first part.',
        'mandatory' => '1',
        'type' => 'leaf',
        'value_type' => 'uniline',
        'warn_if_match' => {
          '.{80,}' => {
            'msg' => 'Synopsis is too long. '
          }
        }
      },
      'Description',
      {
        'description' => 'In a source template control file or binary control file, the Description field contains a description of the binary package, consisting of two parts, the synopsis or the short description, and the long description.

Im cme, the 2 parts have their own entry: Synopsis and Description. 

This is the long description, i.e. the 2nd part.',
        'mandatory' => '1',
        'type' => 'leaf',
        'value_type' => 'string',
        'warn_if_match' => {
          'Debian GNU/Linux' => {
            'fix' => 's!Debian GNU/Linux!Debian!g;',
            'msg' => 'deprecated in favor of Debian'
          },
          '[^\\n]{80,}' => {
            'fix' => 'eval { require Text::Autoformat   ; } ;
if ($@) { CORE::warn "cannot fix without Text::Autoformat"}
else {
        import Text::Autoformat ;
        $_ = autoformat($_, {all => 1}) ;
	chomp;
}',
            'msg' => 'Line too long in description'
          },
          '\\n[\\-\\*]' => {
            'fix' => 's/\\n([\\-\\*])/\\n $1/g; $_ ;',
            'msg' => 'lintian like possible-unindented-list-in-extended-description. i.e. "-" or "*" without leading white space'
          },
          '^\\s*\\n' => {
            'fix' => 's/[\\s\\s]+// ;',
            'msg' => 'Description must not start with an empty line'
          },
          'automagically.*dh-make-perl' => {
            'msg' => 'Description contains dh-make-perl boilerplate'
          }
        }
      },
      'Homepage',
      {
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'XB-Python-Version',
      {
        'status' => 'deprecated',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'XB-Ruby-Versions',
      {
        'description' => 'indicate the versions of the interpreter
supported by the library',
        'level' => 'hidden',
        'status' => 'deprecated',
        'type' => 'leaf',
        'value_type' => 'uniline',
        'warp' => {
          'follow' => {
            'maintainer' => '- - source Maintainer',
            'source' => '- - source Source'
          },
          'rules' => [
            '$maintainer =~ m!Debian Ruby!i or $source =~ /^ruby/',
            {
              'level' => 'normal'
            }
          ]
        }
      },
      'X-DhRuby-Root',
      {
        'description' => 'Used by C<dh_ruby> to request "multi-binary" layout and where the root for the given
package is.

Please refer to L<dh_ruby|https://manpages.debian.org/dh_ruby> documentation for more details.
',
        'summary' => 'For multi-binary layout with the dh_ruby tool',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Build-Profiles',
      {
        'description' => 'Build-Profiles specifies the condition for which that binary package does or does not build. 

This is expressed as a list of lists of (optionally negated) profile names, forming a conjunctive normal form expression in the same syntax as in the Build-Depends field.

For instance:

    Build-Profiles: <!cross> <!nocheck>

See L<https://wiki.debian.org/BuildProfileSpec#The_Build-Profiles_field> for more details.',
        'match' => '^<!?[a-z0-9.-]+(?:\\s+!?[a-z0-9.-]+)*>(?:\\s+<!?[a-z0-9.-]+(?:\\s+!?[a-z0-9.-]+)*>)*$',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'XB-Installer-Menu-Item',
      {
        'description' => '=pod

This field is only relevant for C<udeb> packages (debian-installer).

The field is used to declare where in the installer menu this package\'s menu item should
be placed (assuming it has any menu item). For packages targeting the Debian archive,
any new package should have its menu item number aligned with the debian-installer team
before upload.

A menu item is 4-5 digits (In the range C<< 1000 <= X <= 99999 >>). In rare cases, the menu
item can be architecture dependent. For architecture dependent menu item values, use a
custom substvar.

See L<https://d-i.debian.org/doc/internals/apa.html> for the full list of menu item ranges
and for how to request a number.
',
        'level' => 'hidden',
        'summary' => 'Package\'s order in the debian-installer menu (udeb-only)',
        'type' => 'leaf',
        'value_type' => 'uniline',
        'warp' => {
          'follow' => {
            'pkg_type' => '- Package-Type'
          },
          'rules' => [
            '$pkg_type eq "udeb"',
            {
              'level' => 'normal'
            }
          ]
        }
      },
      'X-DH-Build-For-Type',
      {
        'choice' => [
          'host',
          'target'
        ],
        'description' => 'B<Special-purpose only>. B<This field is a special purpose field and is rarely needed.>
B<Leave it out unless you know you need it or someone told you to use it.>

This field is used when building a cross-compiling C-compiler (or similar cases).  Some packages need
to be built for the target (DEB_B<TARGET>_ARCH) rather than the host (DEB_B<HOST>_ARCH) architecture.
',
        'help' => {
          'host' => 'The package should be compiled for C<DEB_HOST_ARCH>, which is the default behavior.',
          'target' => 'The package should be compiled for C<DEB_TARGET_ARCH>.

For steps that look at the values from C<dpkg-architecture> B<and> that are specific to this
package, the C<DEB_TARGET_> variants are used instead of the C<DEB_HOST_> variants. In C<debhelper>,
this usually affects C<dh_makeshlibs> and C<dh_shlibdeps>. In C<debputy>, it affects the parts of the
manifest that are run in a package specific context, such as the parts beneath the C<packages>
root-level keyword.

This value is exceedingly rare to the point where if you do not know you need it,
then you are not looking for this value (or the field in general).
'
        },
        'summary' => 'For cross-compiling cross-compilers',
        'type' => 'leaf',
        'upstream_default' => 'host',
        'value_type' => 'enum'
      },
      'X-Time64-Compat',
      {
        'description' => 'Special purpose field related to the 64-bit time transition.

It is used to inform packaging helpers what the original (non-transitioned) package name
was when the auto-detection is inadequate. The non-transitioned package name is then
conditionally provided in the C<${{t64:Provides}}> substitution variable.

The field only works for architecture dependent packages.
',
        'summary' => '(Special purpose) Compat name for time64_t transition',
        'type' => 'leaf',
        'value_type' => 'uniline'
      }
    ],
    'license' => 'LGPL2',
    'name' => 'Dpkg::Control::Binary'
  }
]
;

