## TODO

Note that these were all things that I thought of at the time, so stuck them in
here. There is no guarantee that any of this will get done, or even that I 
still think it's a good idea.

* Get the inheritance from LWP::UserAgent *and* moosification of role stuff
  working
* Distilled requests
* Distilled responses: record mocks, store them, and read them
* Get the name of the file from either the calling class or the file, to
  distinguish (a) Test::Class::Moose etc. from (b) standalone tests running
  as t/001-wossname.t
* Complain if mocks were found out of order, or unused mocks weren't used.
* Recognise that a test had been aborted and maybe don't complain as much.
* If a mock isn't recognised, say which one it matches most closely (maybe only
  unused mocks).
* Implement helper stuff like Test::Mock::LWP::Distilled::Role::Mock::JSON
  which uses LWP::JSON::Tiny and implements distilled_response_from_response
  and response_from_distilled_response.
* Support inherent support of LWP::UserAgent::JSON somehow
* Do we need to do the make_immutable incantation that doesn't inline the constructor?
