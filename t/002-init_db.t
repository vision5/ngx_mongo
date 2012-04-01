# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(1);

plan tests => repeat_each() * (blocks() * 1 + 3 * 3);

$ENV{TEST_NGINX_MONGODB_HOST} ||= '127.0.0.1';
$ENV{TEST_NGINX_MONGODB_PORT} ||= 27017;

our $http_config = <<'_EOC_';
    upstream database {
        server     $TEST_NGINX_MONGODB_HOST:$TEST_NGINX_MONGODB_PORT;
        keepalive  1;
    }
_EOC_

no_shuffle();
run_tests();

__DATA__

=== TEST 1: drop "test" collection
--- http_config eval: $::http_config
--- config
    location /mongo {
        mongo_pass   database;
        mongo_query  command ngx_test "{\"drop\": \"test\"}";
    }
--- request
GET /mongo
--- error_code: 200
--- timeout: 10



=== TEST 2: create "test" collection
--- http_config eval: $::http_config
--- config
    location /mongo {
        mongo_pass   database;
        mongo_query  command ngx_test "{\"create\": \"test\", \"capped\": true, \"size\": 10000}";
    }
--- request
GET /mongo
--- error_code: 200
--- timeout: 10



=== TEST 3: drop "junk" collection
--- http_config eval: $::http_config
--- config
    location /mongo {
        mongo_pass   database;
        mongo_query  command ngx_test "{\"drop\": \"junk\"}";
    }
--- request
GET /mongo
--- error_code: 200
--- timeout: 10



=== TEST 4: create "junk" collection
--- http_config eval: $::http_config
--- config
    location /mongo {
        mongo_pass   database;
        mongo_query  command ngx_test "{\"create\": \"junk\", \"capped\": true, \"size\": 10000}";
    }
--- request
GET /mongo
--- error_code: 200
--- timeout: 10



=== TEST 5: insert (static query - config)
--- http_config eval: $::http_config
--- config
    location /mongo {
        mongo_pass   database;
        mongo_query  insert ngx_test.test "{\"hello\": \"world\"}";
    }
--- request
GET /mongo
--- error_code: 204
--- timeout: 10



=== TEST 6: insert (dynamic query - config)
--- http_config eval: $::http_config
--- config
    location /mongo {
        set $key     "world";
        mongo_pass   database;
        mongo_query  insert ngx_test.test "{\"$key\": {\"population\": 7000000000}}";
    }
--- request
GET /mongo
--- error_code: 204
--- timeout: 10



=== TEST 7: insert (dynamic query - JSON in request body)
--- http_config eval: $::http_config
--- config
    location /mongo {
        mongo_pass   database;
        mongo_query  insert ngx_test.test $request_body;
    }
--- request eval
"POST /mongo\r\n".
"{\"values\": [true, false, null]}"
--- more_headers
Content-Type: application/json
--- error_code: 204
--- timeout: 10



=== TEST 8: insert (dynamic query - 2x BSON in request body)
--- http_config eval: $::http_config
--- config
    location /mongo {
        mongo_pass   database;
        mongo_query  insert ngx_test.test $request_body;
    }
--- request eval
"POST /mongo\r\n".
"\x{31}\x{00}\x{00}\x{00}".                          # document length
"\x{04}".                                            # array
"BSON\x{00}".                                        # "BSON"
"\x{26}\x{00}\x{00}\x{00}".                          # array/document length
"\x{02}".                                            # string
"0\x{00}".                                           # "0"
"\x{08}\x{00}\x{00}\x{00}".                          # "awesome" length
"awesome\x{00}".                                     # "awesome"
"\x{01}".                                            # double
"1\x{00}".                                           # "1"
"\x{33}\x{33}\x{33}\x{33}\x{33}\x{33}\x{14}\x{40}".  # 5.05
"\x{10}".                                            # int32
"2\x{00}".                                           # "2"
"\x{c2}\x{07}\x{00}\x{00}".                          # 1986
"\x{00}".                                            # array/document end
"\x{00}".                                            # document end
"\x{18}\x{00}\x{00}\x{00}".                          # document length
"\x{05}".                                            # binary
"binary\x{00}".                                      # "binary"
"\x{06}\x{00}\x{00}\x{00}".                          # "BINARY" length
"\x{00}".                                            # binary subtype - generic
"BINARY".                                            # "BINARY"
"\x{00}"                                             # document end
--- more_headers
Content-Type: application/x-bson
--- error_code: 204
--- timeout: 10



=== TEST 9: verify
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"\x{16}\x{00}\x{00}\x{00}".                          # document length
"\x{02}".                                            # string
"hello\x{00}".                                       # "hello"
"\x{06}\x{00}\x{00}\x{00}".                          # "world" length
"world\x{00}".                                       # "world"
"\x{00}".                                            # document end
"\x{25}\x{00}\x{00}\x{00}".                          # document length
"\x{03}".                                            # document
"world\x{00}".                                       # "world"
"\x{19}\x{00}\x{00}\x{00}".                          # document/document length
"\x{12}".                                            # int64
"population\x{00}".                                  # "population"
"\x{00}\x{86}\x{3b}\x{a1}\x{01}\x{00}\x{00}\x{00}".  # 7000000000
"\x{00}".                                            # document/document end
"\x{00}".                                            # document end
"\x{1d}\x{00}\x{00}\x{00}".                          # document length
"\x{04}".                                            # array
"values\x{00}".                                      # "values"
"\x{10}\x{00}\x{00}\x{00}".                          # array/document length
"\x{08}".                                            # boolean
"0\x{00}".                                           # "0"
"\x{01}".                                            # true
"\x{08}".                                            # boolean
"1\x{00}".                                           # "1"
"\x{00}".                                            # false
"\x{0a}".                                            # null
"2\x{00}".                                           # "2"
"\x{00}".                                            # array/document end
"\x{00}".                                            # document end
"\x{31}\x{00}\x{00}\x{00}".                          # document length
"\x{04}".                                            # array
"BSON\x{00}".                                        # "BSON"
"\x{26}\x{00}\x{00}\x{00}".                          # array/document length
"\x{02}".                                            # string
"0\x{00}".                                           # "0"
"\x{08}\x{00}\x{00}\x{00}".                          # "awesome" length
"awesome\x{00}".                                     # "awesome"
"\x{01}".                                            # double
"1\x{00}".                                           # "1"
"\x{33}\x{33}\x{33}\x{33}\x{33}\x{33}\x{14}\x{40}".  # 5.05
"\x{10}".                                            # int32
"2\x{00}".                                           # "2"
"\x{c2}\x{07}\x{00}\x{00}".                          # 1986
"\x{00}".                                            # array/document end
"\x{00}".                                            # document end
"\x{18}\x{00}\x{00}\x{00}".                          # document length
"\x{05}".                                            # binary
"binary\x{00}".                                      # "binary"
"\x{06}\x{00}\x{00}\x{00}".                          # "BINARY" length
"\x{00}".                                            # binary subtype - generic
"BINARY".                                            # "BINARY"
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 10: drop users
--- http_config eval: $::http_config
--- config
    location /mongo {
        mongo_pass   database;
        mongo_query  delete ngx_test.system.users "";
    }
--- request
GET /mongo
--- error_code: 204
--- timeout: 10



=== TEST 11: add user
--- http_config eval: $::http_config
--- config
    location /mongo {
        mongo_pass   database;
        mongo_query  insert ngx_test.system.users $request_body;
    }
--- request eval
"POST /mongo\r\n".
"\x{53}\x{00}\x{00}\x{00}".                          # document length
"\x{07}".                                            # object id
"_id\x{00}".                                         # "_id"
"0123456789AB".                                      # 0123456789AB
"\x{02}".                                            # string
"user\x{00}".                                        # "user"
"\x{09}\x{00}\x{00}\x{00}".                          # "ngx_test" length
"ngx_test\x{00}".                                    # "ngx_test"
"\x{02}".                                            # string
"pwd\x{00}".                                         # "pwd"
"\x{21}\x{00}\x{00}\x{00}".                          # "60123dca1c264a62baf497eb485982b2" length
"60123dca1c264a62baf497eb485982b2\x{00}".            # "60123dca1c264a62baf497eb485982b2"
"\x{00}"                                             # document end
--- more_headers
Content-Type: application/x-bson
--- error_code: 204
--- timeout: 10



=== TEST 12: verify user - database object
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  select ngx_test.system.users "{}";
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body eval
"\x{53}\x{00}\x{00}\x{00}".                          # document length
"\x{07}".                                            # object id
"_id\x{00}".                                         # "_id"
"0123456789AB".                                      # 0123456789AB
"\x{02}".                                            # string
"user\x{00}".                                        # "user"
"\x{09}\x{00}\x{00}\x{00}".                          # "ngx_test" length
"ngx_test\x{00}".                                    # "ngx_test"
"\x{02}".                                            # string
"pwd\x{00}".                                         # "pwd"
"\x{21}\x{00}\x{00}\x{00}".                          # "60123dca1c264a62baf497eb485982b2" length
"60123dca1c264a62baf497eb485982b2\x{00}".            # "60123dca1c264a62baf497eb485982b2"
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 13: verify user - correct password
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



=== TEST 14: verify user - wrong password
--- http_config eval: $::http_config
--- config
    location /mongo {
        mongo_pass   database;
        mongo_auth   "ngx_test" "wrong_pass";
        mongo_query  select ngx_test.test "{\"hello\": \"world\"}";
    }
--- request
GET /mongo
--- error_code: 502
--- timeout: 10
