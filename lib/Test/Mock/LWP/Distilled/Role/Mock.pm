package Test::Mock::LWP::Distilled::Role::Mock;

use Moo::Role;

=head1 NAME

Test::Mock::LWP::Distilled::Role::Mock - methods your mock class must implement

=head1 DESCRIPTION

This is a Moo role which defines the methods your mock class must implement.

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

1;
