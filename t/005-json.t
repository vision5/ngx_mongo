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

=== TEST 1: sanity
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  command ngx_test "{\"ping\": 1}";
        mongo_json   on;
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



=== TEST 2: database
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  select ngx_test.test "={\"$query\": {}, \"$orderby\": {\"$natural\": 1}}";
        mongo_json   on;
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



=== TEST 3: users
--- http_config eval: $::http_config
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_pass   database;
        mongo_query  select ngx_test.system.users "{}";
        mongo_json   on;
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
