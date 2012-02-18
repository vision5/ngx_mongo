# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4 - 3 * 1 - 3 * 3);

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

=== TEST 1: no auth - command
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  command ngx_test "{\"ping\": 1}";
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 2: no auth - query
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  select ngx_test.test "{\"hello\": \"world\"}";
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"hello": "world"}
--- response_body eval
"\x{16}\x{00}\x{00}\x{00}".                          # document length
"\x{02}".                                            # string
"hello\x{00}".                                       # "hello"
"\x{06}\x{00}\x{00}\x{00}".                          # "world" length
"world\x{00}".                                       # "world"
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 3: no auth - status
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  insert ngx_test.junk "{\"junk\": \"junk\"}";
    }
--- request
GET /mongo
--- error_code: 204
--- response_headers
X-Mongo-Namespace: ngx_test.junk
X-Mongo-Query: {"junk": "junk"}
--- timeout: 10



=== TEST 4: auth elsewhere - command
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /auth {
        mongo_auth   "ngx_test" "ngx_test";
    }

    location /mongo {
        mongo_pass   database;
        mongo_query  command ngx_test "{\"ping\": 1}";
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 5: auth elsewhere - query
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /auth {
        mongo_auth   "ngx_test" "ngx_test";
    }

    location /mongo {
        mongo_pass   database;
        mongo_query  select ngx_test.test "{\"hello\": \"world\"}";
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"hello": "world"}
--- response_body eval
"\x{16}\x{00}\x{00}\x{00}".                          # document length
"\x{02}".                                            # string
"hello\x{00}".                                       # "hello"
"\x{06}\x{00}\x{00}\x{00}".                          # "world" length
"world\x{00}".                                       # "world"
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 6: auth elsewhere - status
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /auth {
        mongo_auth   "ngx_test" "ngx_test";
    }

    location /mongo {
        mongo_pass   database;
        mongo_query  insert ngx_test.junk "{\"junk\": \"junk\"}";
    }
--- request
GET /mongo
--- error_code: 204
--- response_headers
X-Mongo-Namespace: ngx_test.junk
X-Mongo-Query: {"junk": "junk"}
--- timeout: 10



=== TEST 7: auth / correct password - command
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_auth   "ngx_test" "ngx_test";
        mongo_query  command ngx_test "{\"ping\": 1}";
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 8: auth / correct password - query
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_auth   "ngx_test" "ngx_test";
        mongo_query  select ngx_test.test "{\"hello\": \"world\"}";
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"hello": "world"}
--- response_body eval
"\x{16}\x{00}\x{00}\x{00}".                          # document length
"\x{02}".                                            # string
"hello\x{00}".                                       # "hello"
"\x{06}\x{00}\x{00}\x{00}".                          # "world" length
"world\x{00}".                                       # "world"
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 9: auth / correct password - status
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_auth   "ngx_test" "ngx_test";
        mongo_query  insert ngx_test.junk "{\"junk\": \"junk\"}";
    }
--- request
GET /mongo
--- error_code: 204
--- response_headers
X-Mongo-Namespace: ngx_test.junk
X-Mongo-Query: {"junk": "junk"}
--- timeout: 10



=== TEST 10: auth / wrong password - command
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_auth   "ngx_test" "wrong_pass";
        mongo_query  command ngx_test "{\"ping\": 1}";
    }
--- request
GET /mongo
--- error_code: 502
--- timeout: 10



=== TEST 11: auth / wrong password - query
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_auth   "ngx_test" "wrong_pass";
        mongo_query  select ngx_test.test "{\"hello\": \"world\"}";
    }
--- request
GET /mongo
--- error_code: 502
--- timeout: 10



=== TEST 12: auth / wrong password - status
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_auth   "ngx_test" "wrong_pass";
        mongo_query  insert ngx_test.junk "{\"junk\": \"junk\"}";
    }
--- request
GET /mongo
--- error_code: 502
--- timeout: 10
