#!/usr/bin/env perl
# General tests for Test::Mock::LWP::Distilled.

use strict;
use warnings;
use lib::abs 'lib';

use Test::Mock::LWP::Distilled;

use HTTP::Status qw(:constants);
use Test::Fatal;
use Test::More import => [qw(!like)];
use Test2::Tools::Compare qw(like);

use_ok 'Simple::Mock::Class';
my $test_class = 'Simple::Mock::Class';

subtest 'Environment variable determines default mode' => \&test_mode;
subtest 'Record mode produces new mocks'               => \&test_record_mode;
subtest 'Play mode uses the recorded mocks'            => \&test_play_mode;

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

# When in play mode, requests use the mocks and generate a response from the
# distilled response. If you're out of mocks, or your request doesn't match
# the distilled request of the first mock available, you get an error.

sub test_play_mode {
    # Set up a mock object with two mocks.
    my $mock_object = $test_class->new(mode => 'play');
    @{ $mock_object->mocks } = (
        {
            distilled_request  => '/login',
            distilled_response => 'Welcome!'
        },
        {
            distilled_request  => '/login',
            distilled_response => 'You did that already',
        }
    );

    # We get a response generated from the mock.
    my $response = $mock_object->get('https://some-random.website/login');
    is $response->code, undef, q{Our minimal class didn't bother to set a code};
    is $response->decoded_content, 'Welcome!',
        'We took our response from a mock';
    ok $mock_object->mocks->[0]{used}, 'The first mock is marked as used...';
    ok !$mock_object->mocks->[1]{used}, '...but not the second';

    # If we ask again, we get a new response, even though the distilled
    # request was different.
    $response = $mock_object->get('https://other.website/login');
    is $response->decoded_content, 'You did that already',
        'Response from the second mock, even though the distilled request'
            . ' also matches the first mock';
    ok $mock_object->mocks->[0]{used}, 'The first mock is still used...';
    ok $mock_object->mocks->[1]{used}, '...and now the second is also';

    # If we ask a third time, no dice: there are no mocks left so you can't
    # possibly get anything useful.
    ok my $exception_no_mocks_left
        = exception { $mock_object->get('https://yet-another.website/login') },
        'Trying a third time when there are no mocks left gets us an exception';
    like $exception_no_mocks_left, qr/No mocks left to use/,
        'The exception complains about no mocks left';
    like $exception_no_mocks_left,
        my $re_stack_trace = qr{
            Test::Mock::LWP::Distilled
            .+
            $test_class
            .+
            distill[.]t
        }xsm,
        'We got a stack trace that mentioned useful stuff';

    # Say we haven't used the last mock after all: that works again.
    $mock_object->{mocks}[1]{used} = 0;
    $response = $mock_object->get('https://how-many-websites-are-there/login');
    is $response->decoded_content, 'You did that already',
        'Marking a mock as unused lets us retry it (naughty!)';
    ok $mock_object->{mocks}[1]{used}, 'That mock is marked as used again';

    # But if it doesn't match, we complain.
    $mock_object->{mocks}[1]{used} = 0;
    ok my $exception_mismatch = exception {
        $mock_object->get('https://some-random.website/do_stuff')
    },
        q{If the request doesn't distill to what we expected, error};
    like $exception_mismatch, qr/does not match/,
        q{We complain that the request and mock don't match};
    like $exception_mismatch, qr/do_stuff/, 'We mention the request...';
    like $exception_mismatch, qr/login/,    '...and what we expected';
    like $exception_mismatch, $re_stack_trace, 'We also include a stack trace';
}
