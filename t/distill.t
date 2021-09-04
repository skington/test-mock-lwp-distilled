#!/usr/bin/env perl
# General tests for Test::Mock::LWP::Distilled.

use strict;
use warnings;
use lib::abs 'lib';

use Test::Mock::LWP::Distilled;

use HTTP::Status qw(:constants);
use Test::More import => [qw(!like)];
use Test2::Tools::Compare qw(like);

use_ok 'Simple::Mock::Class';
my $test_class = 'Simple::Mock::Class';

subtest 'Environment variable determines default mode' => \&test_mode;
subtest 'Record mode produces new mocks'               => \&test_record_mode;

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

# When in record mode, requests attempt to contact a live server and record
# a new mock.

sub test_record_mode {
    # Create a new mock object, which only records the path of the URI.
    # Make sure that the responses relate to something in the URI *other*
    # than the path, so we can be sure this is us doing things.
    my $mock_object = $test_class->new(mode => 'record');
    $mock_object->_monkey_patched_send_request(
        sub {
            my ($self, $request, $arg, $size) = @_;

            my $response = HTTP::Response->new;
            $response->code(HTTP_I_AM_A_TEAPOT);
            $response->content($request->uri->host . ' says yes');
            return $response;
        }
    );

    # Ask for a remote URL. We talked to our monkey-patched code, as expected,
    # and the results are recorded in mocks.
    like $mock_object->mocks, [], 'No mocks at first';
    my $response = $mock_object->get('https://wossname.lol/get-badgers');
    is $response->code, HTTP_I_AM_A_TEAPOT, 'Surprising HTTP code returned';
    is $response->decoded_content,
        my $expected_content = 'wossname.lol says yes',
        'Surprising content returned';
    like $mock_object->mocks,
        [
            my $badger_mock = {
                distilled_request  => '/get-badgers',
                distilled_response => $expected_content,
            }
        ],
        'This was recorded in our mocks';

    # Further mocks get added to the list.
    $mock_object->get('ftp://hooray-henry/upper-class/twit');
    like $mock_object->mocks,
        [
            $badger_mock,
            {
                distilled_request  => '/upper-class/twit',
                distilled_response => 'hooray-henry says yes',
            }
        ],
        'A further request gets added to the mocks';
}

