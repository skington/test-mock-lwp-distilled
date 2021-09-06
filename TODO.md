## TODO

Note that these were all things that I thought of at the time, so stuck them in
here. There is no guarantee that any of this will get done, or even that I 
still think it's a good idea.

* Save mocks from the file. Do this lazily.
* Recognise that a test had been aborted and maybe don't complain as much.
* If a mock isn't recognised, say which one it matches most closely (maybe only
  unused mocks).
* Implement helper stuff like Test::Mock::LWP::Distilled::Role::Mock::JSON
  which uses LWP::JSON::Tiny and implements distilled_response_from_response
  and response_from_distilled_response.
* Support inherent support of LWP::UserAgent::JSON somehow
* Have a test in a subdirectory so the code that generates file path components
  from the test file name is properly covered.
