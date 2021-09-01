package Test::Mock::LWP::Distilled;

use strict;
use warnings;

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
 extends 'Test::Mock::LWP::Distilled';
 with 'Test::Mock::LWP::Distilled::Role::Mock';
 
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
distill each request made against the I<next unused mock in the file>. If it
matches, it will produce a genuine response from the distilled version and
return it to the calling code. If it doesn't, it dies.

If, when the mock user agent goes out of scope, there are unused mocks left,
it generates a Test::More test failure and dies, so you know something went
wrong. Time to regenerate those mocks and look at the diff!

=head2 Using Test::Mock::LWP::Distilled

There's two things you need to do: set up a mocking class, and using it in your
tests.

=head3 Setting up a mocking class

Your class should be a Moo class that inherits from Test::Mock::LWP::Distilled
I<and> implements L<Test::Mock::LWP::Distilled::Role::Mock>. See its
documentation for complete details, but you should implement the following
methods:

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
