#!/usr/bin/env perl
# General tests for Test::Mock::LWP::Distilled.

use strict;
use warnings;
use lib::abs 'lib';

use Test::Mock::LWP::Distilled;

use Test::More;

use_ok 'Simple::Mock::Class';
my $test_class = 'Simple::Mock::Class';

subtest 'Environment variable determines default mode' => \&test_mode;

done_testing();

# The environment variable REGENERATE_MOCK_FILE determines the initial
# mode for any Test::Mock::LWP::Distilled-using class.

sub test_mode {
    {
        local $ENV{REGENERATE_MOCK_FILE};
        my $mock_object = $test_class->new;
        is $mock_object->mode, 'play',
            'Without an environment variable, we play mocks';
    }
    {
        local $ENV{REGENERATE_MOCK_FILE} = 1;
        my $mock_object = $test_class->new;
        is $mock_object->mode, 'record',
            'With the environment variable set, we record mocks';
    }
}

