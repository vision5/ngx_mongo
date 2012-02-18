# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

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

=== TEST 1: sanity (buffered mode)
--- http_config eval: $::http_config
--- config
    location /mongo {
        mongo_pass       database;
        mongo_query      command ngx_test "{\"ping\": 1}";
        mongo_buffering  on;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
Content-Length: 17
Content-Type: application/x-bson
! Transfer-Encoding
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 2: sanity (non-buffered mode)
--- http_config eval: $::http_config
--- config
    location /mongo {
        mongo_pass       database;
        mongo_query      command ngx_test "{\"ping\": 1}";
        mongo_buffering  off;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
Content-Length: 17
Content-Type: application/x-bson
! Transfer-Encoding
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 3: sanity (subrequest, buffered mode)
--- http_config eval: $::http_config
--- config
    location /ssi {
        ssi        on;
        ssi_types  text/plain;
        return     200 "<!--#include virtual=\"/mongo\" -->";
    }

    location /mongo {
        mongo_pass       database;
        mongo_query      command ngx_test "{\"ping\": 1}";
        mongo_buffering  on;
    }
--- request
GET /ssi
--- error_code: 200
--- response_headers
! Content-Length
Content-Type: text/plain
Transfer-Encoding: chunked
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 4: sanity (subrequest, non-buffered mode)
--- http_config eval: $::http_config
--- config
    location /ssi {
        ssi        on;
        ssi_types  text/plain;
        return     200 "<!--#include virtual=\"/mongo\" -->";
    }

    location /mongo {
        mongo_pass       database;
        mongo_query      command ngx_test "{\"ping\": 1}";
        mongo_buffering  off;
    }
--- request
GET /ssi
--- error_code: 200
--- response_headers
! Content-Length
Content-Type: text/plain
Transfer-Encoding: chunked
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 5: sanity (subrequest in memory, buffered mode)
--- http_config eval: $::http_config
--- config
    location /ssi {
        ssi        on;
        ssi_types  text/plain;
        return     200 "<!--#include set=\"echo\" virtual=\"/mongo\" --><!--#echo var=\"echo\" -->";
    }

    location /mongo {
        mongo_pass       database;
        mongo_query      command ngx_test "{\"ping\": 1}";
        mongo_buffering  on;
    }
--- request
GET /ssi
--- error_code: 200
--- response_headers
! Content-Length
Content-Type: text/plain
Transfer-Encoding: chunked
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 6: sanity (subrequest in memory, non-buffered mode)
--- http_config eval: $::http_config
--- config
    location /ssi {
        ssi        on;
        ssi_types  text/plain;
        return     200 "<!--#include set=\"echo\" virtual=\"/mongo\" --><!--#echo var=\"echo\" -->";
    }

    location /mongo {
        mongo_pass       database;
        mongo_query      command ngx_test "{\"ping\": 1}";
        mongo_buffering  off;
    }
--- request
GET /ssi
--- error_code: 200
--- response_headers
! Content-Length
Content-Type: text/plain
Transfer-Encoding: chunked
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10
