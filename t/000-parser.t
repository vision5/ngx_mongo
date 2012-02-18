# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4);

run_tests();

__DATA__

=== TEST 1: ping
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "{\"ping\": 1}";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ping": 1}
--- response_body eval
"\x{0f}\x{00}\x{00}\x{00}".                          # document length
"\x{10}".                                            # int32
"ping\x{00}".                                        # "ping"
"\x{01}\x{00}\x{00}\x{00}".                          # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 2: hello world
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "{\"hello\": \"world\"}";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"hello": "world"}
--- response_body eval
"\x{16}\x{00}\x{00}\x{00}".                          # document length
"\x{02}".                                            # string
"hello\x{00}".                                       # "hello"
"\x{06}\x{00}\x{00}\x{00}".                          # "world" length
"world\x{00}".                                       # "world"
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 3: BSON awesome
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "{\"BSON\": [\"awesome\", 5.05, 1986]}";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"BSON": ["awesome", 5.05, 1986]}
--- response_body eval
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
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 4: world population
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "{\"world\": {\"population\": 7000000000}}";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"world": {"population": 7000000000}}
--- response_body eval
"\x{25}\x{00}\x{00}\x{00}".                          # document length
"\x{03}".                                            # document
"world\x{00}".                                       # "world"
"\x{19}\x{00}\x{00}\x{00}".                          # document/document length
"\x{12}".                                            # int64
"population\x{00}".                                  # "population"
"\x{00}\x{86}\x{3b}\x{a1}\x{01}\x{00}\x{00}\x{00}".  # 7000000000
"\x{00}".                                            # document/document end
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 5: three-valued logic
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "{\"values\": [true, false, null]}";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"values": [true, false, null]}
--- response_body eval
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
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 6: hello world + world population
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "[{\"hello\": \"world\"}, {\"world\": {\"population\": 7000000000}}]";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: [{"hello": "world"}, {"world": {"population": 7000000000}}]
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
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 7: empty
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
! X-Mongo-Query
--- response_body eval
"\x{05}\x{00}\x{00}\x{00}".                          # document length
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 8: embedded - ok
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "{\"ok\": 1.0}";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"ok": 1.0}
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 9: embedded - logout
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "{\"logout\": 1}";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"logout": 1}
--- response_body eval
"\x{11}\x{00}\x{00}\x{00}".                          # document length
"\x{10}".                                            # int32
"logout\x{00}".                                      # "logout"
"\x{01}\x{00}\x{00}\x{00}".                          # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 10: embedded - get nonce
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "{\"getnonce\": 1}";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"getnonce": 1}
--- response_body eval
"\x{13}\x{00}\x{00}\x{00}".                          # document length
"\x{10}".                                            # int32
"getnonce\x{00}".                                    # "getnonce"
"\x{01}\x{00}\x{00}\x{00}".                          # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 11: embedded - nonce
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "{\"nonce\": \"0123456789ABCDEF\", \"ok\": 1.0}";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"nonce": "0123456789ABCDEF", "ok": 1.0}
--- response_body eval
"\x{2d}\x{00}\x{00}\x{00}".                          # document length
"\x{02}".                                            # string
"nonce\x{00}".                                       # "nonce"
"\x{11}\x{00}\x{00}\x{00}".                          # "0123456789ABCDEF" length
"0123456789ABCDEF\x{00}".                            # "0123456789ABCDEF"
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 12: embedded - auth fail
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "{\"errmsg\": \"auth fails\", \"ok\": 0.0}";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"errmsg": "auth fails", "ok": 0.0}
--- response_body eval
"\x{28}\x{00}\x{00}\x{00}".                          # document length
"\x{02}".                                            # string
"errmsg\x{00}".                                      # "errmsg"
"\x{0b}\x{00}\x{00}\x{00}".                          # "auth fails" length
"auth fails\x{00}".                                  # "auth fails"
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}".  # 0
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 13: embedded - get error
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "{\"getLastError\": 1}";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"getLastError": 1}
--- response_body eval
"\x{17}\x{00}\x{00}\x{00}".                          # document length
"\x{10}".                                            # int32
"getLastError\x{00}".                                # "getLastError"
"\x{01}\x{00}\x{00}\x{00}".                          # 1
"\x{00}"                                             # document end
--- timeout: 10



=== TEST 14: embedded - no error
--- config
    add_header  X-Mongo-Namespace  $mongo_request_namespace;
    add_header  X-Mongo-Query      $mongo_request_query;

    location /mongo {
        mongo_query  command ngx_test "{\"n\": 0, \"connectionId\": 0, \"err\": null, \"ok\": 1.0}";
        echo -n      $mongo_request_bson;
    }
--- request
GET /mongo
--- error_code: 200
--- response_headers
X-Mongo-Namespace: ngx_test
X-Mongo-Query: {"n": 0, "connectionId": 0, "err": null, "ok": 1.0}
--- response_body eval
"\x{2f}\x{00}\x{00}\x{00}".                          # document length
"\x{10}".                                            # int32
"n\x{00}".                                           # "n"
"\x{00}\x{00}\x{00}\x{00}".                          # 0
"\x{10}".                                            # int32
"connectionId\x{00}".                                # "connectionId"
"\x{00}\x{00}\x{00}\x{00}".                          # 0
"\x{0a}".                                            # null
"err\x{00}".                                         # "err"
"\x{01}".                                            # double
"ok\x{00}".                                          # "ok"
"\x{00}\x{00}\x{00}\x{00}\x{00}\x{00}\x{f0}\x{3f}".  # 1
"\x{00}"                                             # document end
--- timeout: 10
