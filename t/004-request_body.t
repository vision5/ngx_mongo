# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() + 2 * 2 + 4 * 3);

$ENV{TEST_NGINX_MONGODB_HOST} ||= '127.0.0.1';
$ENV{TEST_NGINX_MONGODB_PORT} ||= 27017;

our $http_config = <<'_EOC_';
    upstream database {
        server     $TEST_NGINX_MONGODB_HOST:$TEST_NGINX_MONGODB_PORT;
        keepalive  1;
    }
_EOC_

run_tests();

__DATA__

=== TEST 1: valid JSON in request body - command
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  command ngx_test $request_body;
    }
--- request eval
"POST /mongo\r\n".
"{\"ping\": 1}"
--- more_headers
Content-Type: application/json
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
! X-Mongo-Query
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 2: valid JSON in request body - query
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  select ngx_test.test $request_body;
    }
--- request eval
"POST /mongo\r\n".
"{\"hello\": \"world\"}"
--- more_headers
Content-Type: application/json
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
! X-Mongo-Query
--- response_body eval
"\x{16}\x{00}\x{00}\x{00}".                          # document length
"\x{02}".                                            # string
"hello\x{00}".                                       # "hello"
"\x{06}\x{00}\x{00}\x{00}".                          # "world" length
"world\x{00}".                                       # "world"
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 3: valid JSON in request body - status
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  insert ngx_test.junk $request_body;
    }
--- request eval
"POST /mongo\r\n".
"{\"junk\": \"junk\"}"
--- more_headers
Content-Type: application/json
--- error_code: 204
--- response_headers
X-Mongo-Namespace: ngx_test.junk
! X-Mongo-Query
--- timeout: 10



=== TEST 4: invalid JSON in request body - command
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  command ngx_test $request_body;
    }
--- request eval
"POST /mongo\r\n".
"{\"ping\" 1}"
--- more_headers
Content-Type: application/json
--- error_code: 500
--- timeout: 10



=== TEST 5: invalid JSON in request body - query
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  select ngx_test.test $request_body;
    }
--- request eval
"POST /mongo\r\n".
"{\"hello\" \"world\"}"
--- more_headers
Content-Type: application/json
--- error_code: 500
--- timeout: 10



=== TEST 6: invalid JSON in request body - status
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  insert ngx_test.junk $request_body;
    }
--- request eval
"POST /mongo\r\n".
"{\"junk\" \"junk\"}"
--- more_headers
Content-Type: application/json
--- error_code: 500
--- timeout: 10



=== TEST 7: valid BSON in request body - command
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  command ngx_test $request_body;
    }
--- request eval
"POST /mongo\r\n".
"\x{0f}\x{00}\x{00}\x{00}".                          # document length
"\x{10}".                                            # int32
"ping\x{00}".                                        # "ping"
"\x{01}\x{00}\x{00}\x{00}".                          # 1
"\x{00}"                                             # document end
--- more_headers
Content-Type: application/x-bson
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
! X-Mongo-Query
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 8: valid BSON in request body - query
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  select ngx_test.test $request_body;
    }
--- request eval
"POST /mongo\r\n".
"\x{16}\x{00}\x{00}\x{00}".                          # document length
"\x{02}".                                            # string
"hello\x{00}".                                       # "hello"
"\x{06}\x{00}\x{00}\x{00}".                          # "world" length
"world\x{00}".                                       # "world"
"\x{00}"                                             # document end
--- more_headers
Content-Type: application/x-bson
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
! X-Mongo-Query
--- response_body eval
"\x{16}\x{00}\x{00}\x{00}".                          # document length
"\x{02}".                                            # string
"hello\x{00}".                                       # "hello"
"\x{06}\x{00}\x{00}\x{00}".                          # "world" length
"world\x{00}".                                       # "world"
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 9: valid BSON in request body - status
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  insert ngx_test.junk $request_body;
    }
--- request eval
"POST /mongo\r\n".
"\x{14}\x{00}\x{00}\x{00}".                          # document length
"\x{02}".                                            # string
"junk\x{00}".                                        # "junk"
"\x{05}\x{00}\x{00}\x{00}".                          # "junk" length
"junk\x{00}".                                        # "junk"
"\x{00}"                                             # document end
--- more_headers
Content-Type: application/x-bson
--- error_code: 204
--- response_headers
X-Mongo-Namespace: ngx_test.junk
! X-Mongo-Query
--- timeout: 10



=== TEST 10: invalid BSON in request body - command
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  command ngx_test $request_body;
    }
--- request eval
"POST /mongo\r\n".
"\x{0f}\x{00}\x{00}\x{00}".                          # document length
"\x{69}".                                            # int32
"ping\x{00}".                                        # "ping"
"\x{01}\x{00}\x{00}\x{00}".                          # 1
"\x{00}"                                             # document end
--- more_headers
Content-Type: application/x-bson
--- error_code: 500
--- timeout: 10



=== TEST 11: invalid BSON in request body - query
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  select ngx_test.test $request_body;
    }
--- request eval
"POST /mongo\r\n".
"\x{16}\x{00}\x{00}\x{00}".                          # document length
"\x{69}".                                            # string
"hello\x{00}".                                       # "hello"
"\x{06}\x{00}\x{00}\x{00}".                          # "world" length
"world\x{00}".                                       # "world"
"\x{00}"                                             # document end
--- more_headers
Content-Type: application/x-bson
--- error_code: 500
--- timeout: 10



=== TEST 12: invalid BSON in request body - status
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  insert ngx_test.junk $request_body;
    }
--- request eval
"POST /mongo\r\n".
"\x{14}\x{00}\x{00}\x{00}".                          # document length
"\x{69}".                                            # string
"junk\x{00}".                                        # "junk"
"\x{05}\x{00}\x{00}\x{00}".                          # "junk" length
"junk\x{00}".                                        # "junk"
"\x{00}"                                             # document end
--- more_headers
Content-Type: application/x-bson
--- error_code: 500
--- timeout: 10
