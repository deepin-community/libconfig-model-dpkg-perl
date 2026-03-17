use strict;
use warnings;

return [
  {
    'author' => [
      'Dominique Dumont'
    ],
    'class_description' => 'One or more bibliographic references, represented as a mapping or sequence of mappings containing the one or more of the following keys. The values for the keys are always scalars, and the keys that correspond to standard BibTeX entries must provide the same content.

For more details, see L<https://dep-team.pages.debian.net/deps/dep12/>

',
    'copyright' => [
      '2025, Dominique Dumont'
    ],
    'element' => [
      'Author',
      {
        'description' => 'Author list in BibTeX friendly syntax (separating multiple authors by the keyword "and" and using as few as possible abbreviations in the names, as proposed in L<http://nwalsh.com/tex/texhelp/bibtx-23.html>).',
        'type' => 'leaf',
        'value_type' => 'string'
      },
      'Booktitle',
      {
        'description' => 'Title of the book the article is published in',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'DOI',
      {
        'description' => 'This is the digital object identifier of the academic publication describing the packaged work.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Editor',
      {
        'description' => 'Editor of the book the article is published in',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Eprint',
      {
        'description' => 'Hyperlink to the PDF file of the article.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'ISBN',
      {
        'description' => 'International Standard Book Number of the book if the article is part of the book or the reference is a book',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'ISSN',
      {
        'description' => 'International Standard Serial Number of the periodical publication if the article is part of a series',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Journal',
      {
        'description' => 'Abbreviated journal name [To be discussed: which standard to recommend ?].',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Number',
      {
        'description' => 'Issue number.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Pages',
      {
        'description' => 'Article page number(s). [To be discussed] Page number separator must be a single ASCII hyphen. What do we do with condensed notations like 401-10 ?',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'PMID',
      {
        'description' => 'ID number in the L<https://www.ncbi.nlm.nih.gov/pubmed/> database.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Publisher',
      {
        'description' => 'Publisher of the book containing the article',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Title',
      {
        'description' => 'Article title.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Type',
      {
        'description' => 'A L<http://www.bibtex.org/Format> indicating what is cited. Typical values are C<article>, C<book>, or C<inproceedings>. [To be discussed]. In case this field is not present, C<article> is assumed.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'URL',
      {
        'description' => 'Hyperlink to the abstract of the article. This should not point to the full version because this is specified by Eprint. Please also do not drop links to pubmed here because this would be redundant to PMID.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Volume',
      {
        'description' => 'Journal volume.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Year',
      {
        'description' => 'Year of publication',
        'type' => 'leaf',
        'value_type' => 'uniline'
      }
    ],
    'name' => 'Dpkg::Upstream::Metadata::Reference'
  }
]
;

