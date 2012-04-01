# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4);

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

=== TEST 1: mass chunk 1/1 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    1;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 2: mass chunk 1/1 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    1;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 3: mass chunk 1/1 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    1;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 4: mass chunk 2/1 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    2;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 5: mass chunk 2/1 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    2;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 6: mass chunk 2/1 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    2;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 7: mass chunk 3/1 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    3;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 8: mass chunk 3/1 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    3;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 9: mass chunk 3/1 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    3;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 10: mass chunk 4/1 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    4;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 11: mass chunk 4/1 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    4;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 12: mass chunk 4/1 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    4;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 13: mass chunk 5/1 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    5;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 14: mass chunk 5/1 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    5;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 15: mass chunk 5/1 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    5;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 16: mass chunk 6/1 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    6;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 17: mass chunk 6/1 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    6;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 18: mass chunk 6/1 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    6;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 19: mass chunk 7/1 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    7;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 20: mass chunk 7/1 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    7;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 21: mass chunk 7/1 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    7;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 22: mass chunk 8/1 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    8;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 23: mass chunk 8/1 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    8;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 24: mass chunk 8/1 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    8;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 25: mass chunk 9/1 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    9;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 26: mass chunk 9/1 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    9;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 27: mass chunk 9/1 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    9;
        mass_chunk_max_chunks  1;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 28: mass chunk 1/3 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    1;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 29: mass chunk 1/3 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    1;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 30: mass chunk 1/3 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    1;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 31: mass chunk 2/3 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    2;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 32: mass chunk 2/3 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    2;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 33: mass chunk 2/3 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    2;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 34: mass chunk 3/3 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    3;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 35: mass chunk 3/3 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    3;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 36: mass chunk 3/3 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    3;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 37: mass chunk 4/3 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    4;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 38: mass chunk 4/3 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    4;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 39: mass chunk 4/3 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    4;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 40: mass chunk 5/3 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    5;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 41: mass chunk 5/3 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    5;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 42: mass chunk 5/3 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    5;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 43: mass chunk 6/3 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    6;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 44: mass chunk 6/3 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    6;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 45: mass chunk 6/3 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    6;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 46: mass chunk 7/3 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    7;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 47: mass chunk 7/3 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    7;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 48: mass chunk 7/3 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    7;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 49: mass chunk 8/3 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    8;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 50: mass chunk 8/3 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    8;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 51: mass chunk 8/3 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    8;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 52: mass chunk 9/3 - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    9;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 53: mass chunk 9/3 - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    9;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 54: mass chunk 9/3 - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    9;
        mass_chunk_max_chunks  3;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 55: mass chunk 1/max - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    1;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 56: mass chunk 1/max - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    1;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 57: mass chunk 1/max - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    1;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 58: mass chunk 2/max - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    2;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 59: mass chunk 2/max - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    2;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 60: mass chunk 2/max - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    2;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 61: mass chunk 3/max - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    3;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 62: mass chunk 3/max - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    3;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 63: mass chunk 3/max - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    3;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 64: mass chunk 4/max - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    4;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 65: mass chunk 4/max - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    4;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 66: mass chunk 4/max - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    4;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 67: mass chunk 5/max - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    5;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 68: mass chunk 5/max - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    5;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 69: mass chunk 5/max - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    5;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 70: mass chunk 6/max - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    6;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 71: mass chunk 6/max - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    6;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 72: mass chunk 6/max - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    6;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 73: mass chunk 7/max - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    7;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 74: mass chunk 7/max - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    7;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 75: mass chunk 7/max - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    7;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 76: mass chunk 8/max - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    8;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 77: mass chunk 8/max - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    8;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 78: mass chunk 8/max - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    8;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10



=== TEST 79: mass chunk 9/max - sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    9;

        mongo_pass             database;
        mongo_query            command ngx_test "{\"ping\": 1}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body chomp
[{"ok":1.0}]
--- timeout: 10



=== TEST 80: mass chunk 9/max - database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    9;

        mongo_pass             database;
        mongo_query            select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.test
X-Mongo-Query: {"$query": {}, "$orderby": {"$natural": 1}}
--- response_body eval
"[".
"{\"hello\":\"world\"}".
",".
"{\"world\":{\"population\":7000000000}}".
",".
"{\"values\":[true,false,null]}".
",".
"{\"BSON\":[\"awesome\",5.05,1986]}".
",".
"{\"binary\":\"42494e415259\"}".
"]"
--- timeout: 10



=== TEST 81: mass chunk 9/max - users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mass_chunk             on;
        mass_chunk_max_size    9;

        mongo_pass             database;
        mongo_query            select ngx_test.system.users "{}";
        mongo_json             on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test.system.users
X-Mongo-Query: {}
--- response_body chomp
[{"_id":"303132333435363738394142","user":"ngx_test","pwd":"60123dca1c264a62baf497eb485982b2"}]
--- timeout: 10
