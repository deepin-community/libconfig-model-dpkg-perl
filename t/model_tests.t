# -*- cperl -*-

use warnings;
use strict;

use Config::Model::Tester 4.002;

use lib 't/lib';
use SneakyObject;

$::_use_log4perl_to_warn =1;

run_tests() ;
