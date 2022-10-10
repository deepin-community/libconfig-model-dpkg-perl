use strict;
use warnings;

return [
  {
    'class_description' => 'describes how autopkgtest interprets and executes tests found in Debian source packages.

See L<https://salsa.debian.org/ci-team/autopkgtest/raw/master/doc/README.package-tests.rst>',
    'element' => [
      'Tests',
      {
        'cargo' => {
          'type' => 'leaf',
          'value_type' => 'uniline'
        },
        'description' => 'Tests names. names of the scripts used for tests. For instance, if set to \'fred\', autopkgtest will try to exexcute C<debian/tests/fred>.

Alternatively, a test command can be specified in C<Test-Command> parameter.',
        'type' => 'list'
      },
      'Test-Command',
      {
        'description' => 'Command executed to perform the tests.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Restrictions',
      {
        'choice' => [
          'rw-build-tree',
          'breaks-testbed',
          'needs-root',
          'build-needed',
          'allow-stderr',
          'isolation-container',
          'isolation-machine',
          'needs-internet',
          'needs-reboot',
          'needs-recommends',
          'flaky',
          'skippable',
          'skip-not-installable',
          'hint-testsuite-triggers',
          'superficial'
        ],
        'description' => 'Declares some restrictions or problems with the tests defined in this stanza. Depending on the test environment capabilities, user requests, and so on, restrictions can cause tests to be skipped or can cause the test to be run in a different manner.',
        'help' => {
          'allow-stderr' => 'Output to stderr is not considered a failure. This is useful for tests which write e. g. lots of logging to stderr.',
          'breaks-testbed' => 'The test, when run, is liable to break the testbed system. This includes causing data loss, causing services that the machine is running to malfunction, or permanently disabling services; it does not include causing services on the machine to temporarily fail.

When this restriction is present the test will usually be skipped unless the testbed\'s virtualisation arrangements are sufficiently powerful, or alternatively if the user explicitly requests.
',
          'build-needed' => 'The tests need to be run from a built source tree. The test runner will build the source tree (honouring the source package\'s build dependencies), before running the tests. However, the tests are not entitled to assume that the source package\'s build dependencies will be installed when the test is run.

Please use this considerately, as for large builds it unnecessarily builds the entire project when you only need a tiny subset (like the tests/ subdirectory). It is often possible to run C<make -C tests> instead, or copy the test code to C<$AUTOPKGTEST_TMP> and build it there with some custom commands. This cuts down the load on the Continuous Integration servers and also makes tests more robust as it prevents accidentally running them against the built source tree instead of the installed packages.
',
          'flaky' => 'The test is expected to fail intermittently, and is not suitable for gating continuous integration. This indicates a bug in either the package under test, a dependency or the test itself, but such bugs can be difficult to fix, and it is often difficult to know when the bug has been fixed without running the test for a while. If a flaky test succeeds, it will be treated like any other successful test, but if it fails it will be treated as though it had been skipped.',
          'hint-testsuite-triggers' => 'This test exists purely as a hint to suggest when rerunning the tests is likely to be useful.  Specifically, it exists to influence the way dpkg-source generates the Testsuite-Triggers .dsc header from test metadata: the Depends for this test are to be added to Testsuite-Triggers.  (Just as they are for any other test.)

The test with the hint-testsuite-triggers restriction should not actually be run.

The packages listed as Depends for this test are usually indirect dependencies, updates to which are considered to pose a risk of regressions in other tests defined in this package.

There is currently no way to specify this hint on a per-test basis; but in any case the debian.org machinery is not able to think about triggering individual tests.',
          'isolation-container' => 'The test wants to start services or open network TCP ports. This commonly fails in a simple chroot/schroot, so tests need to be run in their own container (e. g. autopkgtest-virt-lxc) or their own machine/VM (e. g. autopkgtest-virt-qemu or autopkgtest-virt-null). When running the test in a virtualization server which does not provide this (like autopkgtest-schroot) it will be skipped.',
          'isolation-machine' => 'The test wants to interact with the kernel, reboot the machine, or other things which fail in a simple schroot and even a container. Those tests need to be run in their own machine/VM (e. g. autopkgtest-virt-qemu or autopkgtest-virt-null). When running the test in a virtualization server which does not provide this it will be skipped.',
          'needs-internet' => 'The test needs unrestricted internet access. See L<https://salsa.debian.org/ci-team/autopkgtest/raw/master/doc/README.package-tests.rst>',
          'needs-reboot' => 'The test wants to reboot the machine using /tmp/autopkgtest-reboot. See L<https://salsa.debian.org/ci-team/autopkgtest/raw/master/doc/README.package-tests.rst>',
          'needs-recommends' => 'Enable installation of recommended packages in apt for the test dependencies. This does not affect build dependencies.',
          'needs-root' => 'The test script must be run as root.',
          'rw-build-tree' => 'The test(s) needs write access to the built source tree (so it may need to be copied first). Even with this restriction, the test is not allowed to make any change to the built source tree which (i) isn\'t cleaned up by debian/rules clean, (ii) affects the future results of any test, or (iii) affects binary packages produced by the build tree in the future.',
          'skip-not-installable' => 'This test might have test dependencies that can\'t be fulfilled on all architectures. Therefore, when apt-get installs the dependencies, it will fail. Don\'t treat this as a test failure, but instead treat it as if the test was skipped.',
          'skippable' => 'The test might need to be skipped for reasons that cannot be described by an existing restriction such as isolation-machine or breaks-testbed, but must instead be detected at runtime. If the test exits with status 77 (a convention borrowed from Automake), it will be treated as though it had been skipped. If it exits with any other status, its success or failure will be derived from the exit status and stderr as usual. Test authors must be careful to ensure that `kippable tests never exit with status 77 for reasons that should be treated as a failure.',
          'superficial' => 'The test does not provide significant test coverage, so if it passes, that does not necessarily mean that the package under test is actually functional. If a superficial test fails, it will be treated like any other failing test, but if it succeeds, this is only a weak indication of success. Continuous integration systems should treat a package where all non-superficial tests are skipped as equivalent to a package where all tests are skipped.

For example, a C library might have a superficial test that simply compiles, links and executes a "hello world" program against the library under test but does not attempt to make use of the library\'s functionality, while a Python or Perl library might have a superficial test that runs "import foo" or "require Foo;" but does not attempt to use the library beyond that.'
        },
        'type' => 'check_list'
      },
      'Features',
      {
        'description' => 'Declares some additional capabilities or good properties of the tests defined in this stanza. Any unknown features declared will be completely ignored. See below for the defined features.
',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Depends',
      {
        'description' => 'Declares that the specified packages must be installed for the test to go ahead. This supports all features of dpkg dependencies (see L<https://www.debian.org/doc/debian-policy/#document-ch-relationships>), plus the following extensions:

@ stands for the package(s) generated by the source package containing the tests; each dependency (strictly, or-clause, which may contain |s but not commas) containing @ is replicated once for each such binary package, with the binary package name substituted for each @ (but normally @ should occur only once and without a version restriction).

@builddeps@ will be replaced by the package\'s C<Build-Depends:>, C<Build-Depends-Indep:>, and build-essential. This is useful if you have many build dependencies which are only necessary for running the test suite and you don\'t want to replicate them in the test C<Depends:>. However, please use this sparingly, as this can easily lead to missing binary package dependencies being overlooked if they get pulled in via build dependencies.

If no Depends field is present, C<Depends: @> is assumed. Note that the source tree\'s Build-Dependencies are not necessarily installed, and if you specify any Depends, no binary packages from the source are installed unless explicitly requested.
',
        'type' => 'leaf',
        'upstream_default' => '@',
        'value_type' => 'string'
      },
      'Tests-Directory',
      {
        'description' => 'Replaces the path segment debian/tests in the filenames of the test programs with path. I. e., the tests are run by executing built/source/tree/path/testname. path must be a relative path and is interpreted starting from the root of the built source tree.

This allows tests to live outside the debian/ metadata area, so that they can more palatably be shared with non-Debian distributions.
',
        'type' => 'leaf',
        'value_type' => 'uniline'
      },
      'Classes',
      {
        'description' => 'Most package tests should work in a minimal environment and are usually not hardware specific. However, some packages like the kernel, X.org, or graphics drivers should be tested on particular hardware, and also run on a set of different platforms rather than just a single virtual testbeds.

This field can specify a list of abstract class names such as "desktop" or "graphics-driver". Consumers of autopkgtest can then map these class names to particular machines/platforms/policies. Unknown class names should be ignored.

This is purely an informational field for autopkgtest itself and will be ignored.',
        'type' => 'leaf',
        'value_type' => 'uniline'
      }
    ],
    'gist' => '{Tests:0}{Test-Command}',
    'name' => 'Dpkg::Tests::Control'
  }
]
;

