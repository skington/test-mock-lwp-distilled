package Test::Mock::LWP::Distilled;

use Moo::Role;
use Types::Standard qw(ArrayRef CodeRef Enum HashRef);

# Have you updated the version number in the POD below?
our $VERSION = '0.001';
$VERSION = eval $VERSION;

=head1 NAME

Test::Mock::LWP::Distilled - make and use LWP mocks, distilled to their essence

=head1 VERSION

This is version 0.001.

=head1 SYNOPSIS

 package My::Test::LWP::UserAgent;

 use Moo;
 extends 'LWP::UserAgent';
 with 'Test::Mock::LWP::Distilled';
 
 use LWP::JSON::Tiny;
 
 # The suffix we use for our mock filename, to distinguish it from other mocks.
 sub filename_suffix { 'simple-api' }
 
 # All our requests are GET requests to unique URLs.
 sub distilled_request_from_request {
     my ($self, $request) = @_;
 
     return $request->uri->path;
 }
 
 # The JSON we get back is good to store; there are no passwords or pesky
 # auto-increment fields to ignore.
 sub distilled_response_from_response {
     my ($self, $response) = @_;
 
     return $response->json_content;
 }
 
 sub response_from_distilled_response {
     my ($self, $distilled_response) = @_;
 
     my $response = HTTP::Response::JSON->new;
     $response->json_content($distilled_response);
     return $response;
 }
 
 package Some::Test;
 
 use My::Test::LWP::UserAgent;
 my $ua = My::Test::LWP::UserAgent->new(
     base_dir                     => '/dev/test_data/mock',
     file_name_from_calling_class => 1,
 );
 # Mocks are stored in, and fetched from,
 #/dev/test_data/mock/Some/Test-simple-api.json

=head1 DESCRIPTION

There are plenty of simple LWP-mocking modules. Test::Mock::LWP::Distilled
aims for something slightly more complicated, and therefore a lot more useful.

=head2 Design ethos

Test::Mock::LWP::Distilled does a couple of things beyond just letting you
inject mocks into your tests.

=head3 Automatic recording and replaying of mocks

Set the environment variable REGENERATE_MOCK_FILE=1 and
Test::Mock::LWP::Distilled will talk to a live system and, when it's done,
update a mock file with the results (distilled - see below) of what you
sent to your remote system and what you got back. These are written out in
canonical, pretty-printed JSON so a diff between two versions reveals only
the bits that actually changed.

=head3 Distilling

Requests and responses are I<distilled> to the minimum you need to accurately
represent them. Your request probably always goes to the same host, and URLs
probably start with a common prefix. Even if things are more complex, you
certainly don't need to record every single HTTP header in your request.

And if your request is a bunch of URL-encoded parameters, the distilled
version of your request I<isn't> C<foo=bar&baz=bletch&toto=titi>; it's
actually

 {
     "baz": "bletch",
     "foo": "bar",
     "toto": "tata"
 }

Similarly, if you get JSON back from a remote service, it's probably made as
compact as possible so it can be squirted down the wire as efficiently as
possible. But you can't read that as a human being, so you may as well turn
it into a Perl data structure, which will then be serialised to JSON in a nice
pretty-printed, sorted way.

This is also the place where you occult passwords or other sensitive
information, or otherwise get rid of data that you don't care about. The end
point is, ideally, data that matches real-life data I<as much as your code
cares about>; a trade-off between accuracy and legibility, where you keep as
much information as you can afford, and get rid of chatter that just gets in
your way.

=head2 How This Works

Run your tests using REGENERATE_MOCK_FILE=1 and Test::Mock::LWP::Distilled
will record all requests made using your mock user agent object, remembering
the distilled requests and responses in a mock file.

Run your tests without that environment variable, and the mock user agent will
distill each request, and check it against the I<next unused mock in the file>.
If it matches, it will produce a genuine response from the distilled version
and return it to the calling code. If it doesn't, it dies.

If, when the mock user agent goes out of scope, there are unused mocks left,
it generates a Test::More test failure and dies, so you know something went
wrong. Time to regenerate those mocks and look at the diff!

=head2 Using Test::Mock::LWP::Distilled

There's two things you need to do: set up a mocking class, and using it in your
tests.

=head3 Setting up a mocking class

Your class should be a Moo class that extends LWP::UserAgent (or a subclass of
your choice), and uses the role Test::Mock::LWP::Distilled.
You should implement the following methods, described in more detail below:

=over

=item filename_suffix

Returns the suffix to use in the mock filename. This is so you can potentially
use two or more mock user agents in the same test class or script, and store
their mocks in similar places without one file overwriting the other.

=item distilled_request_from_request

Take a HTTP::Request object and distill just the information in it that you
need to reliably differentiate one request from another, as per How This
Works above.

This will be serialised to JSON in the mock file.

=item distilled_response_from_response

Take a HTTP::Response object and distill it down to the information you need
to store.

This will be serialised to JSON in the mock file.

=item response_from_distilled_response

Take the data structure you generated earlier and generate a HTTP::Response
object from it, so you can feed it to code that expected to be talking to a
live website.

=back

=head3 Using the class in your code

This is mostly a matter of creating a mock user agent and passing it to any
code that would otherwise have used a live user agent, but there's another
consideration you need to make: where the mock file lives.

Test::Mock::LWP::Distilled uses three bits of data to work out the full
path name:

=over

=item C<base_dir>

This is the root directory where your mocks live. This is an argument
passed to the constructor.

=item test name derived from your test file or class

If you pass C<file_name_from_calling_class> to the constructor,
the test name will be derived from the I<package> name. Otherwise, the test
name will be derived from the I<file> name, with any directories called "t"
removed.

=item suffix

This is the concatenation of hyphen C<->, the result of the C<filename_suffix>
method implemented by your user agent, and C<.json>.

=back

Let's assume your mock user agent is the one from the synopsis,
My::Test::LWP::UserAgent, which says

 sub filename_suffix { 'simple-api' }

and you have a file called /dev/company/module/t/vendor/tests.t.

If you've got a simple test file called e.g.
C</dev/company/module/t/vendor/tests.t>, you might want to say

 my $ua = My::Test::LWP::UserAgent->new(
    base_dir => '/dev/company/test_data',
 );

and the mocks will be stored in, and read from,
/dev/company/test_data/vendor/tests-simple-api.json

If it's e.g. a Test::Class::Moose file with a proper package name,
you might want to write something like this:

 package Some::Test::Class::Moose::Test::Class {
    has simple_api_user_agent => (
        ...
        lazy    => 1,
        builder => '_build_simple_api_user_agent',
    );
    sub _build_simple_api_user_agent {
        My::Test::LWP::UserAgent->new(
            base_dir                     => '/dev/company/test_data',
            file_name_from_calling_class => 1,
        );
    }
 }

And your mocks will be stored in, and read from,
/dev/company/test_data/Some/Test/Class/Moose/Test/Class-simple-api.json

=head2 Methods you must implement

=head3 filename_suffix

 Out: $filename_suffix

You must return the suffix to use when generating a filename to store mocks in.

As the resulting file will look like
I<prefix>/I<path>/I<leafname>-I<suffix>.json - note the hyphen before the
suffix - you might consider using kebab-case for this suffix, rather than
camelCase or snake_case.

=cut

requires 'filename_suffix';

=head3 distilled_request_from_request

 In: $request (HTTP::Request object or subclass)
 Out: $distilled_request (JSON-serializable data)

Supplied with a HTTP::Request object (or subclass thereof), you must
return a variable of I<any kind> that can be serialised to JSON (so no globs
or blessed references), that you are confident accurately represents the
distilled essence of this request. All the data you need to say "that's the
request I was talking about", and no more.

You do not need to make each distilled request identical! If your tests
log in multiple times as different users, you probably want to capture the user
they log in as rather than blithely saying "we log in as some user, don't care
which".

But Test::Mock::LWP::Distilled will throw an exception if your tests do not
make the calls you expected, which means that you can rely on all the previous
calls you expected actually having happened.

So suppose you have an external API that lets you log in as a user, and get
some data corresponding to them. The requests might look like this:

 POST /api/login.version1
 Host: api.somevendor.com
 
 username=user1&password=hunter2

 GET /api/user-data.version1
 Host: api.somevendor.com

 POST /api/login.version1
 Host: api.somevendor.com
 
 username=user2&password=12345

 GET /api/user-data.version1
 Host: api.somevendor.com

You would be perfectly justified in distilling these four requests as

 [
     {
          method  => 'POST',
          command => 'login',
          params  => {
              username => 'user1',
          }
     },
     {
         method  => 'GET',
         command => 'user-data',
     },
     {
         method  => 'POST',
         command => 'login',
         params  => {
             username => 'user2',
         }
     },
     {
         method  => 'GET',
         command => 'user-data',
     },
 ]

Most obviously, all of these calls are to the same host, and have the same
C</api/> prefix and the same C<.version1> suffix, so there's no need to store
that.

More interestingly, you don't need to specify the password in the login request
(and arguably you shouldn't because the less you store this sort of thing, even
in a test environment, the better; plus, if you ever change the password you
need to regenerate the mocks, even though none of the test I<behaviour> has
changed).

In fact, a case could be made that you don't need to store the method either.
Only if there's a difference between e.g. GET /api/user-data.version1,
PATCH /api/user-data.version1 and/or DELETE /api/user-data.version1 would you
need to store that.

B<But>, what if your tests also include "if you log in incorrectly, you get
told off and you can't get user data" and "once you've logged out, you can't
reuse your security credentials again"? You might have to add to the user-data
requests, details of the encrypted thingy you got back from the login response,
because you want to distinguish "I just logged in as user B and I'm allowed to
get stuff" from "I'm no longer logged in as user A, so I can't use the old
authentication credentials again".

=cut

requires 'distilled_request_from_request';

=head3 distilled_response_from_response

 In: $response (HTTP::Response object or subclass) 
 Out: $distilled_response (JSON-serialisable data)

Supplied with a HTTP::Response object (or subclass thereof), you must return a
variable or data structure that represents the essential nature of this
response. As with L</distilled_request_from_request>, the point is to winnow
away the unnecessary chaff and keep only that information you and your tests
need.

So, to take the simple example from above with four requests, you might
plausibly distill them down to

 [
     {},
     {
         username => 'user1',
         # data returned for the first user
     },
     {},
     {
         username => 'user2,
         # data returned for the second user
     }
 ]

because all of the calls were successes, and the login requests didn't return
any content.

But if you added tests that you got knocked back if you logged in with
incorrect credentials, I<and> your code decided what to do by looking at the
HTTP code of the response first, then falling back to the JSON contents, you
should also include an HTTP code in your distilled responses.

And if your distilled I<requests> included some encrypted thingy that they
remembered from a previous call, then you I<need> to include that in your
distilled response. Maybe your data structure wants to become e.g.

 {
     headers => {
         authentication => '...',
     },
     data => {},
 }

vs

 {
     data => {
         username => 'user1',
         # etc. etc.
     }
 }

=cut

requires 'distilled_response_from_response';

=head3 response_from_distilled_response

 In: $distilled_response (JSON-serialisable data)
 Out: $respone (HTTP::Response object or subclass)

Passed the distilled response that, in a previous run of your test code when
the environment variable REGENERATE_MOCK_FILE was set, you generated from a
real-life HTTP::Response object (or a subclass thereof), you must return a
HTTP::Response (or subclass thereof) that I<your calling code> will be able to
interpret reliably.

Note the emphasis! It's OK to not bother returning all sorts of e.g. date,
crypto etc. headers if your code doesn't care about that stuff. You won't end
up replicating I<exactly> the way a live system behaves, but if your code
doesn't care about that, why should you? Consider this an intersection of YAGNI
and Postel's Law.

B<But>, if your code behaves differently based on the HTTP code, you need to
set this. If, as in the extended example above, you have an encrypted thingy
returned from a login attempt, you need to populate the appropriate header.

=cut

requires 'response_from_distilled_response';

=head2 Attributes supplied

The following attributes are provided by Test::Mock::LWP::Distilled to your
class.

=head3 mode

Either C<record> or C<play>. By default determined by the environment
variable REGENERATE_MOCK_FILE: if set, the mode is C<record>, otherwise the
mode is C<play>.

When recording, a request triggers a I<live> request to the remote website; the
live response is returned to the calling code, and a new mock is recorded
from the distilled request and distilled response.

When playing, a request triggers a check that the next unused mock's distilled
request is identical to the distilled version of the current request; if so,
the mock is marked as having been used, and a response is generated from the
distilled response in the mock.

=cut

has 'mode' => (
    is  => 'rw',
    isa => Enum [qw(record play)],
    default => sub {
        $ENV{REGENERATE_MOCK_FILE} ? 'record' : 'play',
    },
);

=head3 mocks

An arrayref of mock hashrefs, each of which contain the keys
C<distilled_request> and C<distilled_response>.

=cut

has 'mocks' => (
    is      => 'ro',
    isa     => ArrayRef[HashRef],
    default => sub { [] },
);

=head2 Methods supplied

=head3 send_request

As per LWP::UserAgent::send_request, but:

=over

=item In record mode

It calls the original send_request method, and records the distilled request
and distilled response as new mocks

=item In play mode

It looks for the next unused mock, checks that its distilled request matches
the distilled version of the supplied request, and if so returns a response
generated from the distilled response in the mock. Otherwise dies with an
exception.

=back

=cut

# Explicitly support monkey-patching because the way around works involves
# lexical variables that we can't get access to afterwards.
# The presence of %Class::Method::Modifiers::MODIFIER_CACHE is
# misleading: it doesn't include a reference to $orig, which is what we
# want to monkey-patch, so we have to monkey-patch explicitly.
has '_monkey_patched_send_request' => (
    is  => 'rw',
    isa => CodeRef,
);

around send_request => sub {
    my ($orig, $self, $request, $arg, $size) = @_;

    # For testing purposes we want to let people override the original
    # method, but don't use this in production!
    if ($self->_monkey_patched_send_request && $ENV{HARNESS_ACTIVE}) {
        $orig = $self->_monkey_patched_send_request;
    }

    if ($self->mode eq 'record') {
        my $response = $self->$orig($request, $arg, $size);
        push @{ $self->mocks }, {
            distilled_request  =>
                $self->distilled_request_from_request($request),
            distilled_response =>
                $self->distilled_response_from_response($response),
        };
        return $response;
    } else {
        ...
    }
};

=head1 SEE ALSO

L<Test::Mock::LWP>, L<Mock::LWP::Request>, L<Test::Mock::LWP::Dispatch>,
L<Test::Mock::LWP::Conditional>, and almost certainly others.

=head1 AUTHOR

Sam Kington <skington@cpan.org>

The source code for this module is hosted on GitHub
L<https://github.com/skington/test-mock-lwp-distilled> - this is probably the
best place to look for suggestions and feedback.

=head1 COPYRIGHT

FIXME TBD.

=head1 LICENSE

This library is free software and may be distributed under the same terms as
perl itself.

=cut

1;
