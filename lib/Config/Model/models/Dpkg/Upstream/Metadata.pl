use strict;
use warnings;

return [
  {
    'author' => [
      'Dominique Dumont'
    ],
    'class_description' => 'The upstream metadata file is meant to contain machine-readable metadata about the upstream project, its community and processes.

Information in this file should not be specific to Debian, and be relevant for other distributions as well.

For more details, see L<https://dep-team.pages.debian.net/deps/dep12/>

',
    'copyright' => [
      '2025, Dominique Dumont'
    ],
    'element' => [
      'Archive',
      {
        'description' => 'The name of the large archive that the upstream work is part of, like CPAN.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'ASCL-Id',
      {
        'description' => 'Identification code in the L<http://ascl.net>',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Bug-Database',
      {
        'description' => 'A URL to the list of known bugs for the project.',
        'type' => 'leaf',
        'value_type' => 'string'
      },
      'Bug-Submit',
      {
        'description' => 'A URL that is the place where new bug reports should be sent.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Cite-As',
      {
        'description' => 'The way the authors want their software be cited in publications. The value is a string which might contain a link in valid HTML syntax. (L<http://lists.debian.org/debian-science/2012/05/msg00008.html>)',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Changelog',
      {
        'description' => 'URL to the upstream changelog.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Contact',
      {
        'description' => 'Contact should be specified in debian/copyright',
        'status' => 'deprecated',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'CPE',
      {
        'description' => 'One or more space separated L<http://cpe.mitre.org/> values useful to look up relevant CVEs in the L<https://nvd.nist.gov/home.cfm> and other CVE sources. See CPEtagPackagesDep for information on how this information can be used. Example: "cpe:/a:ethereal_group:ethereal"',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Documentation',
      {
        'description' => 'A URL to online documentation.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Donation',
      {
        'description' => 'A URL to a donation form (or instructions).',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'FAQ',
      {
        'description' => 'A URL to the online FAQ.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Funding',
      {
        'description' => 'One or more sources of funding which have supported this project (e.g. NSF OCI-12345).',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Gallery',
      {
        'description' => 'A URL to a gallery of pictures made with the program (not screenshots).',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Homepage',
      {
        'description' => 'Homepage should be specified in debian/control',
        'status' => 'deprecated',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Other-References',
      {
        'description' => 'A URL to a upstream page containing more references.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Reference',
      {
        'cargo' => {
          'config_class_name' => 'Dpkg::Upstream::Metadata::Reference',
          'type' => 'node'
        },
        'description' => 'One or more bibliographic references. The values for the keys are always scalars, and the keys that correspond to standard BibTeX entries must provide the same content.',
        'type' => 'list'
      },
      'Registration',
      {
        'description' => 'A URL to a registration form (or instructions). This could be registration of bug reporting accounts, registration for counting/contacting users etc.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Registry',
      {
        'cargo' => {
          'config_class_name' => 'Dpkg::Upstream::Metadata::Registry',
          'type' => 'node'
        },
        'description' => 'This field shall point to external catalogs/registries of software. The field features an array of "Name (of registry) - Entry (ID of software in that catalog)" pairs. The names and entries shall only be names, not complete URIs, to avoid any bias on mirrors etc. Example: C< Registry: - Name: bio.tools Entry: clustalw - Name: OMICtools Entry: OMICS_02562 - Name: SciCrunch Entry: SCR_002909> Valid `Name` entries for Registry are: L<https://bio.tools/>, L<https://biii.eu/>, L<https://omictools.com/>, L<https://scicrunch.org/>, L<https://bioconda.github.io/>, L<https://opam.ocaml.org/> and L<https://pypi.org/>. Other channels of conda can be referenced analogously by their name, for instance L<https://conda-forge.org/> or L<https://anaconda.org/r>, but may not yet be prepared to be interpreted. Special value of "Entry" C<NA> means that a catalog/registry is confirmed to not have an entry for this software.',
        'type' => 'list'
      },
      'Repository',
      {
        'description' => 'URL to a repository containing the upstream sources.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Repository-Browse',
      {
        'description' => 'A URL to browse the repository containing the upstream sources.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Screenshots',
      {
        'cargo' => {
          'type' => 'leaf',
          'value_type' => 'uniline'
        },
        'description' => 'One or more URLs to upstream pages containing screenshots (not C<screenshots.debian.net>), represented by a scalar or a sequence of scalars.',
        'type' => 'list'
      },
      'Security-Contact',
      {
        'description' => 'Which person, mailing list, forum,… to send security-related messages in the first place.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Upstream-Contact',
      {
        'description' => 'Upstream-Contact should be specified in debian/copyright',
        'status' => 'deprecated',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Upstream-Name',
      {
        'description' => 'Upstream-Name should be specified in debian/copyright',
        'status' => 'deprecated',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Webservice',
      {
        'description' => 'URL to an web page where the packaged program can also be used.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      }
    ],
    'name' => 'Dpkg::Upstream::Metadata',
    'rw_config' => {
      'auto_create' => '1',
      'auto_delete' => '1',
      'backend' => 'Yaml',
      'config_dir' => 'debian/upstream',
      'file' => 'metadata'
    }
  }
]
;

