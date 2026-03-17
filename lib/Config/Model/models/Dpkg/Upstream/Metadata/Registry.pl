use strict;
use warnings;

return [
  {
    'author' => [
      'Dominique Dumont'
    ],
    'class_description' => 'This field shall point to external catalogs/registries of software. The field features an array of "Name (of registry) - Entry (ID of software in that catalog)" pairs. The names and entries shall only be names, not complete URIs, to avoid any bias on mirrors etc.',
    'copyright' => [
      '2026, Dominique Dumont'
    ],
    'element' => [
      'Name',
      {
        'description' => 'Valid Name entries for Registry are: bio.tools, biii, OMICtools, SciCrunch, conda:bioconda, opam and PyPI. Other channels of conda can be referenced analogously by their name, for instance conda:conda-forge or conda:r, but may not yet be prepared to be interpreted. Special value of Entry NA means that a catalog/registry is confirmed to not have an entry for this software.',
        'summary' => 'Name (of registry)',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Entry',
      {
        'summary' => 'ID of software in that catalog',
        'type' => 'leaf',
        'value_type' => 'uniline'
      }
    ],
    'name' => 'Dpkg::Upstream::Metadata::Registry'
  }
]
;

