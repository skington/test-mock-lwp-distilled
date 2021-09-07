#!/usr/bin/env perl
# Tests for Test::Mock::LWP::Distilled::JSON

use strict;
use warnings;
use lib::abs 'lib';

use Test::More import => [qw(!like)];
use Test2::Tools::Compare qw(like T);

use HTTP::Status qw(:constants);
use LWP::JSON::Tiny;

my $test_class = 'Simple::JSON::Mock::Class';
use Simple::JSON::Mock::Class;

subtest 'Distill response from JSON or HTML' => \&test_distill_response;

done_testing();

# If we get JSON back from a server, we turn that into a mock. If we get
# HTML because e.g. the server's broken and we get their standard
# 500 page, we can cope with that and don't crash.

sub test_distill_response {
    my $mock_object = $test_class->new(mode => 'record');

    # Valid JSON gets turned into a Perl data structure.
    $mock_object->_monkey_patched_send_request(
        sub {
            my ($self, $request, $arg, $size) = @_;
            
            return HTTP::Response::JSON->new(
                HTTP_NO_CONTENT, undef, ['Content-Type' => 'application/json'],
                <<'JSON_BODY'
{
    "stuff": [
        "elk",
        "some lard"
    ],
    "source": {
        "url": "http://www.monkeydyne.com/rmcs/dbcomic.phtml?rowid=3026",
        "bitrot": true,
        "still_on_archive_dot_org": "hooray!"
    },
    "was_the_code_a_lie": "yes"
}
JSON_BODY
            );
        }
    );
    $mock_object->get('https://any-url-doesnt-matter.lol');
    like $mock_object->mocks->[0]{distilled_response},
        {
            code         => HTTP_NO_CONTENT,
            json_content => {
                source => {
                    url    => qr{^ \Qhttp://www.monkeydyne.com\E }x,
                    bitrot => T(),
                    still_on_archive_dot_org => 'hooray!',
                },
                stuff              => ['elk', 'some lard'],
                was_the_code_a_lie => 'yes',
            },
        },
        'JSON was turned into a Perl data structure';

    # HTML is returned verbatim.
    $mock_object->_monkey_patched_send_request(
        sub {
            my ($self, $request, $arg, $size) = @_;
            
            return HTTP::Response::JSON->new(
                HTTP_INTERNAL_SERVER_ERROR, undef,
                ['Content-Type' => 'text/html'],
                <<'HTML_BODY'
<html>
<head>
<title>Whoops</title>
</head>
<body>
<p>Well, that didn't work. Huh.</p>
</body>
</html>
HTML_BODY
            );
        }
    );
    $mock_object->get('https://halt-and-catch-fire.lol');
    like $mock_object->mocks->[1]{distilled_response},
        {
            code            => HTTP_INTERNAL_SERVER_ERROR,
            content_type    => 'text/html',
            decoded_content => qr/^<html> .+ Whoops .+ didn't \s work /xsm,
        },
        'Non-JSON is recorded as-is';
    
    # Clean out the mocks to avoid them being dumped to a file.
    @{ $mock_object->mocks } = ();
}