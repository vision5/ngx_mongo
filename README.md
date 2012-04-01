About
=====
`ngx_mongo` is an upstream module that allows `nginx` to communicate directly
with `MongoDB` database.


Status
======
This module is considered stable and it's compatible with the following nginx
releases:

- 1.1.4+ (tested with 1.1.4 to 1.1.18).


Configuration directives
========================
mongo_auth
----------
* **syntax**: `mongo_auth username password`
* **default**: `none`
* **context**: `server`, `location`, `if location`

Set optional authentication details.


mongo_pass
----------
* **syntax**: `mongo_pass upstream`
* **default**: `none`
* **context**: `location`, `if location`

Set database address, this can be either: `IP:port` or name of existing upstream
block.


mongo_query
-----------
* **syntax**: `mongo_query operation database[.collection] query|$request_body`
* **default**: `none`
* **context**: `location`, `if location`

Set query details.

Valid operations are:

- `command`,
- `select`,
- `insert`,
- `update`,
- `upsert`,
- `delete`.

Query passed via `$request_body` can be either in `BSON` (with `Content-Type`
set to `application/x-bson`) or `JSON` format.


mongo_json
----------
* **syntax**: `mongo_json on|off`
* **default**: `off`
* **context**: `http`, `server`, `location`, `if location`

Convert output from `BSON` (default) to `JSON` format.


mongo_bind
----------
* **syntax**: `mongo_bind address`
* **default**: `none`
* **context**: `http`, `server`, `location`

Set local address that should be used when connecting to the database.


mongo_connect_timeout
---------------------
* **syntax**: `mongo_connect_timeout timeout`
* **default**: `60s`
* **context**: `http`, `server`, `location`

Configure connection timeout.


mongo_send_timeout
------------------
* **syntax**: `mongo_send_timeout timeout`
* **default**: `60s`
* **context**: `http`, `server`, `location`

Configure send timeout.


mongo_read_timeout
------------------
* **syntax**: `mongo_read_timeout timeout`
* **default**: `60s`
* **context**: `http`, `server`, `location`

Configure read timeout.


mongo_buffering
---------------
* **syntax**: `mongo_buffering on|off`
* **default**: `on`
* **context**: `http`, `server`, `location`

Enable or disable buffering of the database response.


mongo_buffer_size
-----------------
* **syntax**: `mongo_buffer_size size`
* **default**: `4k|8k`
* **context**: `http`, `server`, `location`

Configure buffers used to read database response.


mongo_buffers
-------------
* **syntax**: `mongo_buffers number size`
* **default**: `8 4k|8k`
* **context**: `http`, `server`, `location`

Configure buffers used to read database response.


mongo_busy_buffers_size
-----------------------
* **syntax**: `mongo_busy_buffers_size size`
* **default**: `8k|16k`
* **context**: `http`, `server`, `location`

Configure buffers used to read database response.


mongo_next_upstream
-------------------
* **syntax**: `mongo_next_upstream error|timeout|off ...`
* **default**: `error timeout`
* **context**: `http`, `server`, `location`

Configure in which case query should be passed to another server.


Configuration variables
=======================
$mongo_request_namespace
------------------------
Full namespace (`database[.collection]`) used to query database.


$mongo_request_query
--------------------
`JSON` object used to query database. This variable is empty when
query is passed in request body.


$mongo_request_bson
-------------------
`BSON` object used to query database.


Sample configurations
=====================
Sample configuration #1
-----------------------
Return content of the `cats` collection from the `test` database.

    http {
        upstream database {
            server     127.0.0.1:27017;
            keepalive  1;
        }

        server {
            location = /cats {
                mongo_pass   database;
                mongo_query  select test.cats "{}";
            }

            location = /cats.json {
                mongo_pass   database;
                mongo_query  select test.cats "{}";
                mongo_json   on;
            }
        }
    }


Sample configuration #2
-----------------------
Insert object(s) passed in the request body to the `cats` collection
in the `test` database.

    http {
        upstream database {
            server     127.0.0.1:27017;
            keepalive  1;
        }

        server {
            location / {
                mongo_pass   database;
                mongo_auth   user pass;
                mongo_query  insert test.cats $request_body;
            }
        }
    }


Testing
=======
`ngx_mongo` comes with complete test suite based on [Test::Nginx](http://github.com/agentzh/test-nginx).

You can test it by running:

`$ prove`


License
=======
    Copyright (c) 2011-2012, Simpl <foss@simpl.it>
    Copyright (c) 2011-2012, FRiCKLE <info@frickle.com>
    Copyright (c) 2011-2012, Piotr Sikora <piotr.sikora@frickle.com>
    Copyright (c) 2002-2011, Igor Sysoev <igor@sysoev.ru>
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:
    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
    A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
    HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
    SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
    LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
    DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
    THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


See also
========
- [ngx_postgres](http://github.com/FRiCKLE/ngx_postgres),
- [ngx_drizzle](http://github.com/chaoslawful/drizzle-nginx-module),
- [ngx_rds_json](http://github.com/agentzh/rds-json-nginx-module).
