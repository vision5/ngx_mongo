/*
 * Copyright (c) 2011-2012, Simpl <foss@simpl.it>
 * Copyright (c) 2011-2012, FRiCKLE <info@frickle.com>
 * Copyright (c) 2011-2012, Piotr Sikora <piotr.sikora@frickle.com>
 * Copyright (c) 2002-2011, Igor Sysoev <igor@sysoev.ru>
 * All rights reserved.
 *
 * This project was fully funded by Simpl (www.simpl.it) for use on
 * the open-source website Tagmata (www.tagmata.com).
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>
#include <ngx_md5.h>

#include <yajl/yajl_parse.h>


#define NGX_HTTP_MONGO_REQ_HEADER_SIZE  (4 * sizeof(int32_t))
#define NGX_HTTP_MONGO_RES_HEADER_SIZE  (7 * sizeof(int32_t) + sizeof(int64_t))

#define NGX_HTTP_MONGO_OP_REPLY            1
#define NGX_HTTP_MONGO_OP_UPDATE        2001
#define NGX_HTTP_MONGO_OP_INSERT        2002
#define NGX_HTTP_MONGO_OP_QUERY         2004
#define NGX_HTTP_MONGO_OP_DELETE        2006

#define NGX_HTTP_MONGO_BSON_DOUBLE      0x01
#define NGX_HTTP_MONGO_BSON_STRING      0x02
#define NGX_HTTP_MONGO_BSON_BSON        0x03
#define NGX_HTTP_MONGO_BSON_ARRAY       0x04
#define NGX_HTTP_MONGO_BSON_BOOLEAN     0x08
#define NGX_HTTP_MONGO_BSON_NULL        0x0A
#define NGX_HTTP_MONGO_BSON_INT32       0x10
#define NGX_HTTP_MONGO_BSON_INT64       0x12


typedef struct ngx_http_mongo_bson_s  ngx_http_mongo_bson_t;


typedef struct {
    ngx_str_t                   name;
    ngx_str_t                   sv;
    ngx_http_complex_value_t   *cv;
    ngx_str_t                  *cmd;
} ngx_conf_str_t;


typedef struct {
    ngx_str_t                   name;
    int32_t                     code;
    unsigned                    cmd:1;
    int32_t                     flags;
    int32_t                     extra;
} ngx_http_mongo_opcode_t;


typedef struct {
    ngx_http_upstream_conf_t    upstream;

    ngx_http_mongo_opcode_t    *opcode;
    ngx_conf_str_t              auth_user;
    ngx_conf_str_t              auth_pass;
    ngx_str_t                   auth_digest;
    ngx_str_t                   database;
    ngx_conf_str_t              namespace;
    ngx_conf_str_t              query;

    int32_t                     limit;
    int32_t                     skip;

    ngx_buf_t                  *bson;
} ngx_http_mongo_loc_conf_t;


typedef struct {
    ngx_http_mongo_loc_conf_t  *conf;

    ngx_str_t                  *auth_user;
    ngx_str_t                  *auth_pass;
    ngx_str_t                   auth_digest;
    ngx_str_t                   database;
    ngx_str_t                  *namespace;
    ngx_str_t                  *query;

    ngx_buf_t                  *bson;

    ngx_chain_t                *init_request;
    ngx_chain_t                *real_request;

    int32_t                     request_id;
    ngx_str_t                   nonce;
} ngx_http_mongo_ctx_t;


typedef struct {
    ngx_str_t                   json;
    int32_t                     len;
    ngx_buf_t                  *bson;
} ngx_http_mongo_predefined_t;


struct ngx_http_mongo_bson_s {
    ngx_http_mongo_bson_t      *parent;
    u_char                     *start;
    ngx_int_t                   array_idx;
};


typedef struct {
    ngx_buf_t                  *buf;
    ngx_pool_t                 *pool;

    ngx_http_mongo_bson_t      *bson;

    ngx_str_t                   key;
} ngx_http_mongo_json_to_bson_ctx_t;


static ngx_int_t ngx_http_mongo_handler(ngx_http_request_t *r);

static ngx_chain_t *ngx_http_mongo_create_header(ngx_http_request_t *r,
    ngx_http_mongo_opcode_t *opcode, int32_t extra_len);
static ngx_chain_t *ngx_http_mongo_create_predefined_request(
    ngx_http_request_t *r, ngx_int_t id, ngx_int_t flush);
static ngx_chain_t *ngx_http_mongo_create_auth_request(ngx_http_request_t *r);

static ngx_int_t ngx_http_mongo_create_request(ngx_http_request_t *r);
static ngx_int_t ngx_http_mongo_reinit_request(ngx_http_request_t *r);

static ngx_int_t ngx_http_mongo_process_wire(ngx_http_request_t *r,
    int32_t request_id, int32_t single, int32_t read_ahead);
static ngx_int_t ngx_http_mongo_process_logout(ngx_http_request_t *r);
static ngx_int_t ngx_http_mongo_process_nonce(ngx_http_request_t *r);
static ngx_int_t ngx_http_mongo_process_auth(ngx_http_request_t *r);
static ngx_int_t ngx_http_mongo_process_status(ngx_http_request_t *r);
static ngx_int_t ngx_http_mongo_process_header(ngx_http_request_t *r);

static void ngx_http_mongo_abort_request(ngx_http_request_t *r);
static void ngx_http_mongo_finalize_request(ngx_http_request_t *r,
    ngx_int_t rc);

static ngx_int_t ngx_http_mongo_input_filter_init(void *data);
static ngx_int_t ngx_http_mongo_copy_filter(ngx_event_pipe_t *p,
    ngx_buf_t *buf);
static ngx_int_t ngx_http_mongo_non_buffered_copy_filter(void *data,
    ssize_t bytes);

static ngx_int_t ngx_http_mongo_request_namespace_variable(
    ngx_http_request_t *r, ngx_http_variable_value_t *v, uintptr_t data);
static ngx_int_t ngx_http_mongo_request_query_variable(ngx_http_request_t *r,
    ngx_http_variable_value_t *v, uintptr_t data);
static ngx_int_t ngx_http_mongo_request_bson_variable(ngx_http_request_t *r,
    ngx_http_variable_value_t *v, uintptr_t data);

static ngx_buf_t *ngx_http_mongo_bson_empty(ngx_pool_t *pool);
static ngx_http_mongo_bson_t *ngx_http_mongo_bson_palloc(ngx_pool_t *pool,
    ngx_buf_t *buf, ngx_http_mongo_bson_t *parent);
static ngx_http_mongo_bson_t *ngx_http_mongo_bson_finish(
    ngx_http_mongo_bson_t *bson, ngx_buf_t *buf);

static ngx_int_t ngx_http_mongo_json_to_bson_check(
    ngx_http_mongo_json_to_bson_ctx_t *ctx, size_t len);
static void ngx_http_mongo_json_to_bson_header(
    ngx_http_mongo_json_to_bson_ctx_t *ctx, int8_t type);

static int ngx_http_mongo_json_to_bson_null(void *data);
static int ngx_http_mongo_json_to_bson_boolean(void *data, int value);
static int ngx_http_mongo_json_to_bson_integer(void *data, long long value);
static int ngx_http_mongo_json_to_bson_double(void *data, double value);
static int ngx_http_mongo_json_to_bson_string(void *data,
    const unsigned char *value, size_t len);
static int ngx_http_mongo_json_to_bson_map_key(void *data,
    const unsigned char *value, size_t len);
static int ngx_http_mongo_json_to_bson_start_map(void *data);
static int ngx_http_mongo_json_to_bson_end_map(void *data);
static int ngx_http_mongo_json_to_bson_start_array(void *data);
static int ngx_http_mongo_json_to_bson_end_array(void *data);

static ngx_buf_t *ngx_http_mongo_json_to_bson(ngx_str_t *json,
    ngx_pool_t *pool);
static ngx_buf_t *ngx_http_mongo_json_chain_to_bson(ngx_chain_t *in, size_t len,
    ngx_pool_t *pool);

static ngx_int_t ngx_http_mongo_init(ngx_cycle_t *cycle);
static ngx_int_t ngx_http_mongo_add_variables(ngx_conf_t *cf);
static void *ngx_http_mongo_create_loc_conf(ngx_conf_t *cf);
static char *ngx_http_mongo_merge_loc_conf(ngx_conf_t *cf, void *parent,
    void *child);

static char *ngx_conf_str_set(ngx_conf_t *cf, ngx_conf_str_t *cfs, ngx_str_t *s,
    const char *name, ngx_str_t *cmd, ngx_int_t not_empty);
static ngx_str_t *ngx_conf_str_get(ngx_http_request_t *r, ngx_conf_str_t *cfs,
    ngx_int_t not_empty);

static char *ngx_http_mongo_pass(ngx_conf_t *cf, ngx_command_t *cmd,
    void *conf);
static char *ngx_http_mongo_auth(ngx_conf_t *cf, ngx_command_t *cmd,
    void *conf);
static char *ngx_http_mongo_query(ngx_conf_t *cf, ngx_command_t *cmd,
    void *conf);


static ngx_conf_bitmask_t  ngx_http_mongo_next_upstream_masks[] = {
    { ngx_string("error"),   NGX_HTTP_UPSTREAM_FT_ERROR },
    { ngx_string("timeout"), NGX_HTTP_UPSTREAM_FT_TIMEOUT },
    { ngx_string("off"),     NGX_HTTP_UPSTREAM_FT_OFF },
    { ngx_null_string, 0 }
};


static ngx_command_t  ngx_http_mongo_commands[] = {

    { ngx_string("mongo_pass"),
      NGX_HTTP_LOC_CONF|NGX_HTTP_LIF_CONF|NGX_CONF_TAKE1,
      ngx_http_mongo_pass,
      NGX_HTTP_LOC_CONF_OFFSET,
      0,
      NULL },

    { ngx_string("mongo_auth"),
      NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_HTTP_LIF_CONF|NGX_CONF_TAKE2,
      ngx_http_mongo_auth,
      NGX_HTTP_LOC_CONF_OFFSET,
      0,
      NULL },

    { ngx_string("mongo_query"),
      NGX_HTTP_LOC_CONF|NGX_HTTP_LIF_CONF|NGX_CONF_ANY,
      ngx_http_mongo_query,
      NGX_HTTP_LOC_CONF_OFFSET,
      0,
      NULL },

    { ngx_string("mongo_bind"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_http_upstream_bind_set_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_mongo_loc_conf_t, upstream.local),
      NULL },

    { ngx_string("mongo_connect_timeout"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_msec_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_mongo_loc_conf_t, upstream.connect_timeout),
      NULL },

    { ngx_string("mongo_send_timeout"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_msec_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_mongo_loc_conf_t, upstream.send_timeout),
      NULL },

    { ngx_string("mongo_read_timeout"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_msec_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_mongo_loc_conf_t, upstream.read_timeout),
      NULL },

    { ngx_string("mongo_buffering"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_FLAG,
      ngx_conf_set_flag_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_mongo_loc_conf_t, upstream.buffering),
      NULL },

    { ngx_string("mongo_buffer_size"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_size_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_mongo_loc_conf_t, upstream.buffer_size),
      NULL },

    { ngx_string("mongo_buffers"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE2,
      ngx_conf_set_bufs_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_mongo_loc_conf_t, upstream.bufs),
      NULL },

    { ngx_string("mongo_busy_buffers_size"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_size_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_mongo_loc_conf_t, upstream.busy_buffers_size_conf),
      NULL },

    { ngx_string("mongo_next_upstream"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_1MORE,
      ngx_conf_set_bitmask_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_mongo_loc_conf_t, upstream.next_upstream),
      &ngx_http_mongo_next_upstream_masks },

      ngx_null_command
};


static ngx_http_variable_t  ngx_http_mongo_vars[] = {

    { ngx_string("mongo_request_namespace"), NULL,
      ngx_http_mongo_request_namespace_variable, 0,
      NGX_HTTP_VAR_NOCACHEABLE|NGX_HTTP_VAR_NOHASH, 0 },

    { ngx_string("mongo_request_query"), NULL,
      ngx_http_mongo_request_query_variable, 0,
      NGX_HTTP_VAR_NOCACHEABLE|NGX_HTTP_VAR_NOHASH, 0 },

    { ngx_string("mongo_request_bson"), NULL,
      ngx_http_mongo_request_bson_variable, 0,
      NGX_HTTP_VAR_NOCACHEABLE|NGX_HTTP_VAR_NOHASH, 0 },

    { ngx_null_string, NULL, NULL, 0, 0, 0 }
};


static ngx_http_module_t  ngx_http_mongo_module_ctx = {
    ngx_http_mongo_add_variables,          /* preconfiguration */
    NULL,                                  /* postconfiguration */

    NULL,                                  /* create main configuration */
    NULL,                                  /* init main configuration */

    NULL,                                  /* create server configuration */
    NULL,                                  /* merge server configuration */

    ngx_http_mongo_create_loc_conf,        /* create location configuration */
    ngx_http_mongo_merge_loc_conf          /* merge location configuration */
};


ngx_module_t  ngx_http_mongo_module = {
    NGX_MODULE_V1,
    &ngx_http_mongo_module_ctx,            /* module context */
    ngx_http_mongo_commands,               /* module directives */
    NGX_HTTP_MODULE,                       /* module type */
    NULL,                                  /* init master */
    ngx_http_mongo_init,                   /* init module */
    NULL,                                  /* init process */
    NULL,                                  /* init thread */
    NULL,                                  /* exit thread */
    NULL,                                  /* exit process */
    NULL,                                  /* exit master */
    NGX_MODULE_V1_PADDING
};


static yajl_callbacks  ngx_http_mongo_json_to_bson_callbacks = {
    ngx_http_mongo_json_to_bson_null,
    ngx_http_mongo_json_to_bson_boolean,
    ngx_http_mongo_json_to_bson_integer,
    ngx_http_mongo_json_to_bson_double,
    NULL,
    ngx_http_mongo_json_to_bson_string,
    ngx_http_mongo_json_to_bson_start_map,
    ngx_http_mongo_json_to_bson_map_key,
    ngx_http_mongo_json_to_bson_end_map,
    ngx_http_mongo_json_to_bson_start_array,
    ngx_http_mongo_json_to_bson_end_array
};


#define NGX_HTTP_MONGO_OK         0
#define NGX_HTTP_MONGO_LOGOUT     1
#define NGX_HTTP_MONGO_GET_NONCE  2
#define NGX_HTTP_MONGO_AUTH_FAIL  3
#define NGX_HTTP_MONGO_GET_ERROR  4
#define NGX_HTTP_MONGO_NO_ERROR   5


static ngx_http_mongo_predefined_t  ngx_http_mongo_predefined[] = {
    { ngx_string("{\"ok\": 1.0}"), 0x11, NULL },
    { ngx_string("{\"logout\": 1}"), 0x11, NULL },
    { ngx_string("{\"getnonce\": 1}"), 0x13, NULL },
    { ngx_string("{\"errmsg\": \"auth fails\", \"ok\": 0.0}"), 0x28, NULL },
    { ngx_string("{\"getLastError\": 1}"), 0x17, NULL },
    { ngx_string("{\"n\": 0, \"connectionId\": 0, \"err\": null, \"ok\": 1.0}"),
      0x2f, NULL },
    { ngx_null_string, 0, NULL }
};


static ngx_http_mongo_opcode_t  ngx_http_mongo_opcodes[] = {
    { ngx_string("command"), NGX_HTTP_MONGO_OP_QUERY,  1, 0x00, 3 },
    { ngx_string("select"),  NGX_HTTP_MONGO_OP_QUERY,  0, 0x00, 3 },
    { ngx_string("insert"),  NGX_HTTP_MONGO_OP_INSERT, 0, 0x00, 1 },
    { ngx_string("update"),  NGX_HTTP_MONGO_OP_UPDATE, 0, 0x02, 2 },
    { ngx_string("upsert"),  NGX_HTTP_MONGO_OP_UPDATE, 0, 0x03, 2 },
    { ngx_string("delete"),  NGX_HTTP_MONGO_OP_DELETE, 0, 0x00, 2 },
    { ngx_null_string, 0, 0, 0, 0 }
};


#define ngx_str_last(str)            (u_char *) ((str)->data + (str)->len)
#define ngx_conf_str_empty(str)      ((str)->sv.len == 0 && (str)->cv == NULL)


static ngx_int_t                     ngx_http_mongo_auth_used;
static ngx_http_upstream_handler_pt  ngx_http_mongo_send_request;


static ngx_int_t
ngx_http_mongo_handler(ngx_http_request_t *r)
{
    ngx_http_mongo_loc_conf_t  *mlcf;
    ngx_http_mongo_ctx_t       *mctx;
    ngx_http_upstream_t        *u;
    ngx_md5_t                   md5;
    ngx_int_t                   rc;
    u_char                     *dot;
    u_char                      buf[16];

    if (ngx_http_upstream_create(r) != NGX_OK) {
        return NGX_HTTP_INTERNAL_SERVER_ERROR;
    }

    mctx = ngx_pcalloc(r->pool, sizeof(ngx_http_mongo_ctx_t));
    if (mctx == NULL) {
        return NGX_HTTP_INTERNAL_SERVER_ERROR;
    }

    mlcf = ngx_http_get_module_loc_conf(r, ngx_http_mongo_module);

    mctx->conf = mlcf;

    if (!ngx_conf_str_empty(&mlcf->auth_user)) {
        mctx->auth_user = ngx_conf_str_get(r, &mlcf->auth_user, 1);
        if (mctx->auth_user == NULL) {
            return NGX_HTTP_INTERNAL_SERVER_ERROR;
        }

        mctx->auth_pass = ngx_conf_str_get(r, &mlcf->auth_pass, 1);
        if (mctx->auth_pass == NULL) {
            return NGX_HTTP_INTERNAL_SERVER_ERROR;
        }

        if (mlcf->auth_digest.len > 0) {
            mctx->auth_digest = mlcf->auth_digest;

        } else {
            ngx_md5_init(&md5);
            ngx_md5_update(&md5, mctx->auth_user->data, mctx->auth_user->len);
            ngx_md5_update(&md5, ":mongo:", sizeof(":mongo:") - 1);
            ngx_md5_update(&md5, mctx->auth_pass->data, mctx->auth_pass->len);
            ngx_md5_final(buf, &md5);

            mctx->auth_digest.data = ngx_pnalloc(r->pool, 32);
            mctx->auth_digest.len = 32;

            ngx_hex_dump(mctx->auth_digest.data, buf, 16);
         }
    }

    mctx->namespace = ngx_conf_str_get(r, &mlcf->namespace, 1);
    if (mctx->namespace == NULL) {
        return NGX_HTTP_INTERNAL_SERVER_ERROR;
    }

    if (mlcf->database.len > 0) {
        mctx->database = mlcf->database;

    } else {
        dot = ngx_strlchr(mctx->namespace->data,
                          ngx_str_last(mctx->namespace), '.');

        if (dot == ngx_str_last(mctx->namespace)
            || (mlcf->opcode->cmd && dot != NULL)
            || (!mlcf->opcode->cmd && dot == NULL))
        {
            ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                          "mongo: invalid namespace \"%V\"",
                          mctx->namespace);
            return NGX_HTTP_INTERNAL_SERVER_ERROR;
        }

        if (mlcf->opcode->cmd) {
            mctx->database = *mctx->namespace;

        } else {
            mctx->database.data = mctx->namespace->data;
            mctx->database.len = dot - mctx->namespace->data;
        }
    }

    if (!mlcf->upstream.pass_request_body) {
        mctx->query = ngx_conf_str_get(r, &mlcf->query, 0);
        if (mctx->query == NULL) {
            return NGX_HTTP_INTERNAL_SERVER_ERROR;
        }

        if (mlcf->bson) {
            mctx->bson = mlcf->bson;

        } else {
            mctx->bson = ngx_http_mongo_json_to_bson(mctx->query, r->pool);
            if (mctx->bson == NULL) {
                ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                              "mongo: invalid JSON \"%V\"", mctx->query);
                return NGX_HTTP_INTERNAL_SERVER_ERROR;
            }
        }
    }

    mctx->request_id = (int32_t) r->connection->number;

    ngx_http_set_ctx(r, mctx, ngx_http_mongo_module);

    u = r->upstream;

    ngx_str_set(&u->schema, "mongodb://");
    u->output.tag = (ngx_buf_tag_t) &ngx_http_mongo_module;

    u->conf = &mlcf->upstream;

    u->create_request = ngx_http_mongo_create_request;
    u->reinit_request = ngx_http_mongo_reinit_request;
    u->abort_request = ngx_http_mongo_abort_request;
    u->finalize_request = ngx_http_mongo_finalize_request;

    if (ngx_http_mongo_auth_used) {
        u->process_header = ngx_http_mongo_process_logout;

    } else if (mlcf->opcode->code != NGX_HTTP_MONGO_OP_QUERY) {
        u->process_header = ngx_http_mongo_process_status;

    } else {
        u->process_header = ngx_http_mongo_process_header;
    }

    u->buffering = mlcf->upstream.buffering;

    u->pipe = ngx_pcalloc(r->pool, sizeof(ngx_event_pipe_t));
    if (u->pipe == NULL) {
        return NGX_HTTP_INTERNAL_SERVER_ERROR;
    }

    u->pipe->input_filter = ngx_http_mongo_copy_filter;
    u->pipe->input_ctx = r;

    u->input_filter_init = ngx_http_mongo_input_filter_init;
    u->input_filter = ngx_http_mongo_non_buffered_copy_filter;
    u->input_filter_ctx = r;

    if (ngx_http_mongo_send_request == NULL) {
        u->request_sent = 1;
    }

    rc = ngx_http_read_client_request_body(r, ngx_http_upstream_init);

    if (rc >= NGX_HTTP_SPECIAL_RESPONSE) {
        return rc;
    }

    return NGX_DONE;
}


static ngx_chain_t *
ngx_http_mongo_create_header(ngx_http_request_t *r,
    ngx_http_mongo_opcode_t *opcode, int32_t extra_len)
{
    ngx_http_mongo_ctx_t  *mctx;
    ngx_chain_t           *cl;
    ngx_buf_t             *b;
    int32_t                len, limit, skip;
    int32_t                zero = 0;
    char                  *null = '\0';

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    len = NGX_HTTP_MONGO_REQ_HEADER_SIZE + opcode->extra * sizeof(int32_t);

    if (opcode->cmd) {
        len += mctx->database.len + sizeof(".$cmd");
        limit = -1;
        skip = 0;

    } else {
        len += mctx->namespace->len + 1;
        limit = mctx->conf->limit;
        skip = mctx->conf->skip;
    }

    b = ngx_create_temp_buf(r->pool, len);
    if (b == NULL) {
        return NULL;
    }

    len += extra_len;

    b->last = ngx_copy(b->last, &len, sizeof(int32_t));      /* messageLength */
    b->last = ngx_copy(b->last, &mctx->request_id,               /* requestID */
                       sizeof(int32_t));
    b->last = ngx_copy(b->last, &zero, sizeof(int32_t));        /* responseTo */
    b->last = ngx_copy(b->last, &opcode->code, sizeof(int32_t));    /* opCode */

    switch (opcode->code) {
    case NGX_HTTP_MONGO_OP_QUERY:
        b->last = ngx_copy(b->last, &opcode->flags, sizeof(int32_t));

        if (opcode->cmd) {
            b->last = ngx_copy(b->last, mctx->database.data,
                               mctx->database.len);
            b->last = ngx_copy(b->last, ".$cmd", sizeof(".$cmd") - 1);

        } else {
            b->last = ngx_copy(b->last, mctx->namespace->data,
                               mctx->namespace->len);
        }

        b->last = ngx_copy(b->last, &null, sizeof(char));
        b->last = ngx_copy(b->last, &skip, sizeof(int32_t));
        b->last = ngx_copy(b->last, &limit, sizeof(int32_t));
        break;

    case NGX_HTTP_MONGO_OP_INSERT:
        b->last = ngx_copy(b->last, &opcode->flags, sizeof(int32_t));
        b->last = ngx_copy(b->last, mctx->namespace->data,
                           mctx->namespace->len);
        b->last = ngx_copy(b->last, &null, sizeof(char));
        break;

    case NGX_HTTP_MONGO_OP_UPDATE:
    case NGX_HTTP_MONGO_OP_DELETE:
        b->last = ngx_copy(b->last, &zero, sizeof(int32_t));
        b->last = ngx_copy(b->last, mctx->namespace->data,
                           mctx->namespace->len);
        b->last = ngx_copy(b->last, &null, sizeof(char));
        b->last = ngx_copy(b->last, &opcode->flags, sizeof(int32_t));
        break;

    default:
        return NULL;
    }

    if (b->last != b->end) {
        return NULL;
    }

    cl = ngx_alloc_chain_link(r->pool);
    if (cl == NULL) {
        return NULL;
    }

    cl->buf = b;
    cl->next = NULL;

    return cl;
}


static ngx_chain_t *
ngx_http_mongo_create_predefined_request(ngx_http_request_t *r, ngx_int_t id,
    ngx_int_t flush)
{
    ngx_http_mongo_ctx_t  *mctx;
    ngx_chain_t           *cl, *head;
    ngx_buf_t             *b;

    ngx_log_debug2(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: create predefined request: \"%V\" (flush: %d)",
                   &ngx_http_mongo_predefined[id].json, flush);

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    /* header */
    cl = ngx_http_mongo_create_header(r, &ngx_http_mongo_opcodes[0],
                                      ngx_http_mongo_predefined[id].len);
    if (cl == NULL) {
        return NULL;
    }

    head = cl;

    /* BSON */
    b = ngx_alloc_buf(r->pool);
    if (b == NULL) {
        return NULL;
    }

    ngx_memcpy(b, ngx_http_mongo_predefined[id].bson, sizeof(ngx_buf_t));

    cl->next = ngx_alloc_chain_link(r->pool);
    if (cl->next == NULL) {
        return NULL;
    }

    cl = cl->next;

    b->flush = flush ? 1 : 0;

    cl->buf = b;
    cl->next = NULL;

    return head;
}


static ngx_chain_t *
ngx_http_mongo_create_auth_request(ngx_http_request_t *r)
{
    ngx_http_mongo_ctx_t  *mctx;
    ngx_chain_t           *cl, *head;
    ngx_buf_t             *b;
    ngx_md5_t              md5;
    ngx_str_t              s;
    u_char                 buf[16], key[32];

    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: create auth request");

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    s.len = 87 + mctx->auth_user->len + mctx->nonce.len;

    s.data = ngx_pnalloc(r->pool, s.len);
    if (s.data == NULL) {
        return NULL;
    }

    ngx_md5_init(&md5);
    ngx_md5_update(&md5, mctx->nonce.data, mctx->nonce.len);
    ngx_md5_update(&md5, mctx->auth_user->data, mctx->auth_user->len);
    ngx_md5_update(&md5, mctx->auth_digest.data, 32);
    ngx_md5_final(buf, &md5);

    ngx_hex_dump(key, buf, 16);

    (void) ngx_snprintf(s.data, s.len, "{\"authenticate\": 1, \"user\":"
                        " \"%V\", \"nonce\": \"%V\", \"key\": \"%*s\"}",
                        mctx->auth_user, &mctx->nonce, 32, key);

    b = ngx_http_mongo_json_to_bson(&s, r->pool);
    if (b == NULL) {
        ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                      "mongo: invalid JSON \"%V\"", &s);
        return NULL;
    }

    /* header */
    cl = ngx_http_mongo_create_header(r, &ngx_http_mongo_opcodes[0],
                                      ngx_buf_size(b));
    if (cl == NULL) {
        return NULL;
    }

    head = cl;

    /* BSON */
    cl->next = ngx_alloc_chain_link(r->pool);
    if (cl->next == NULL) {
        return NULL;
    }

    cl = cl->next;

    b->flush = 1;

    cl->buf = b;
    cl->next = NULL;

    return head;
}


static ngx_int_t
ngx_http_mongo_create_request(ngx_http_request_t *r)
{
    ngx_http_mongo_ctx_t  *mctx;
    ngx_table_elt_t       *ctype;
    ngx_chain_t           *cl, *body;
    ngx_buf_t             *b, *bson;
    int32_t                blen;

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    if (mctx->conf->upstream.pass_request_body) {
        ctype = r->headers_in.content_type;

        if (ctype != NULL
            && ctype->value.len == sizeof("application/x-bson") - 1
            && ngx_strcmp(ctype->value.data, "application/x-bson") == 0)
        {
            ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                           "mongo: create request: BSON query in request body");

            body = r->upstream->request_bufs;
            bson = NULL;
            blen = r->headers_in.content_length_n;

        } else {
            ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                           "mongo: create request: JSON query in request body");

            mctx->bson = ngx_http_mongo_json_chain_to_bson(
                             r->upstream->request_bufs,
                             r->headers_in.content_length_n, r->pool);

            if (mctx->bson == NULL) {
                ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                              "mongo: invalid JSON in request body");
                return NGX_ERROR;
            }

            body = NULL;
            bson = mctx->bson;
            blen = ngx_buf_size(bson);
        }

    } else {
        ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                       "mongo: create request: JSON query");

        body = NULL;
        bson = mctx->bson;
        blen = ngx_buf_size(bson);
    }

    /* header */
    cl = ngx_http_mongo_create_header(r, mctx->conf->opcode, blen);
    if (cl == NULL) {
        return NGX_ERROR;
    }

    mctx->real_request = cl;

    /* BSON(s) */
    if (body) {
        while (body) {
            b = ngx_alloc_buf(r->pool);
            if (b == NULL) {
                return NGX_ERROR;
            }

            ngx_memcpy(b, body->buf, sizeof(ngx_buf_t));

            cl->next = ngx_alloc_chain_link(r->pool);
            if (cl->next == NULL) {
                return NGX_ERROR;
            }

            cl = cl->next;
            cl->buf = b;

            body = body->next;
        }

    } else {
        b = ngx_alloc_buf(r->pool);
        if (b == NULL) {
            return NGX_ERROR;
        }

        ngx_memcpy(b, bson, sizeof(ngx_buf_t));

        cl->next = ngx_alloc_chain_link(r->pool);
        if (cl->next == NULL) {
            return NGX_ERROR;
        }

        cl = cl->next;
        cl->buf = b;
    }

    if (mctx->conf->opcode->code != NGX_HTTP_MONGO_OP_QUERY) {
        cl->next = ngx_http_mongo_create_predefined_request(
                       r, NGX_HTTP_MONGO_GET_ERROR, 1);
        if (cl->next == NULL) {
            return NGX_ERROR;
        }

    } else {
        b->flush = 1;
        cl->next = NULL;
    }

    if (ngx_http_mongo_auth_used) {
        cl = ngx_http_mongo_create_predefined_request(
                 r, NGX_HTTP_MONGO_LOGOUT, 0);
        if (cl == NULL) {
            return NGX_ERROR;
        }

        mctx->init_request = cl;
        cl = cl->next;

        if (mctx->auth_user) {
            cl->next = ngx_http_mongo_create_predefined_request(
                           r, NGX_HTTP_MONGO_GET_NONCE, 1);
            if (cl->next == NULL) {
                return NGX_ERROR;
            }

        } else {
            cl->next = mctx->real_request;
        }

    } else {
        mctx->init_request = mctx->real_request;
    }

    r->upstream->request_bufs = mctx->init_request;

    return NGX_OK;
}


static ngx_int_t
ngx_http_mongo_reinit_request(ngx_http_request_t *r)
{
    ngx_http_mongo_ctx_t  *mctx;
    ngx_http_upstream_t   *u;
    ngx_chain_t           *cl;

    if (ngx_http_mongo_send_request == NULL) {
        ngx_http_mongo_send_request = r->upstream->write_event_handler;
        return NGX_OK;
    }

    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: reinit request");

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    for (cl = mctx->real_request; cl; cl = cl->next) {
        cl->buf->pos = cl->buf->start;
        cl->buf->file_pos = 0;
    }

    if (mctx->real_request != mctx->init_request) {
        for (cl = mctx->real_request; cl; cl = cl->next) {
            cl->buf->pos = cl->buf->start;
            cl->buf->file_pos = 0;
        }
    }

    u = r->upstream;

    u->request_bufs = mctx->init_request;

    if (ngx_http_mongo_auth_used) {
        u->process_header = ngx_http_mongo_process_logout;

    } else if (mctx->conf->opcode->code != NGX_HTTP_MONGO_OP_QUERY) {
        u->process_header = ngx_http_mongo_process_status;

    } else {
        u->process_header = ngx_http_mongo_process_header;
    }

    return NGX_OK;
}


static ngx_int_t
ngx_http_mongo_process_wire(ngx_http_request_t *r, int32_t request_id,
    int32_t single, int32_t read_ahead)
{
    ngx_buf_t  *b;

    b = &r->upstream->buffer;

    ngx_log_debug2(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: process wire: %uz/%uz (header)",
                   ngx_buf_size(b), NGX_HTTP_MONGO_RES_HEADER_SIZE);

    if (ngx_buf_size(b) < (off_t) NGX_HTTP_MONGO_RES_HEADER_SIZE) {
        return NGX_AGAIN;
    }

    if ((int32_t) b->pos[8] != request_id) {             /* header.responseTo */
        ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                      "mongo: received response for different request,"
                      " got: %ud expected: %ud",
                      (int32_t) b->pos[8], request_id);
        return NGX_ERROR;
    }

    if (b->pos[16] & 0x02) {                    /* responseFlags.QueryFailure */
        ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                      "mongo: received response for invalid query");
        return NGX_ERROR;
    }

    if ((int32_t) b->pos[12] != NGX_HTTP_MONGO_OP_REPLY             /* opCode */
        || (int64_t) b->pos[20] != 0                              /* cursorId */
        || (single && (int32_t) b->start[28] != 0)            /* startingFrom */
        || (single && (int32_t) b->start[32] != 1))         /* numberReturned */
    {
        ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                      "mongo: received invalid wire header");
        return NGX_ERROR;
    }

    if (single && read_ahead) {
        ngx_log_debug2(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                       "mongo: process wire: %uz/%uz (read ahead)",
                       ngx_buf_size(b) - NGX_HTTP_MONGO_RES_HEADER_SIZE,
                       (int32_t) b->pos[0] - NGX_HTTP_MONGO_RES_HEADER_SIZE);

        if (read_ahead > 0
            && (int32_t) b->pos[0]                    /* header.messageLength */
            != read_ahead + NGX_HTTP_MONGO_RES_HEADER_SIZE)
        {
            ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                          "mongo: received wrong BSON"
                          " (header length mismatatch, got: %ud expected: %ud)",
                          (int32_t) b->pos[0] - NGX_HTTP_MONGO_RES_HEADER_SIZE,
                          read_ahead);
            return NGX_ERROR;
        }

        if (ngx_buf_size(b) < (int32_t) b->pos[0]) {  /* header.messageLength */
            return NGX_AGAIN;
        }

        if ((int32_t) b->pos[0]                       /* header.messageLength */
            != (int32_t) b->pos[NGX_HTTP_MONGO_RES_HEADER_SIZE]     /* length */
               + NGX_HTTP_MONGO_RES_HEADER_SIZE)
        {
            ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                          "mongo: received invalid BSON (length mismatch)");
            return NGX_ERROR;
        }

        if (read_ahead > 0
            && (int32_t) b->pos[NGX_HTTP_MONGO_RES_HEADER_SIZE]     /* length */
            != read_ahead)
        {
            ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                          "mongo: received wrong BSON"
                          " (BSON length mismatatch, got :%ud expected: %ud)",
                          (int32_t) b->pos[NGX_HTTP_MONGO_RES_HEADER_SIZE],
                          read_ahead);
            return NGX_ERROR;
        }
    }

    return NGX_OK;
}


static ngx_int_t
ngx_http_mongo_process_logout(ngx_http_request_t *r)
{
    ngx_http_mongo_ctx_t         *mctx;
    ngx_http_mongo_predefined_t  *e;
    ngx_http_upstream_t          *u;
    ngx_buf_t                    *b;
    ngx_int_t                     rc;

    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: process logout");

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    b = &r->upstream->buffer;

    e = &ngx_http_mongo_predefined[NGX_HTTP_MONGO_OK];

    rc = ngx_http_mongo_process_wire(r, mctx->request_id, 1, e->len);
    if (rc != NGX_OK) {
        return rc;
    }

    b->pos += NGX_HTTP_MONGO_RES_HEADER_SIZE;

    if (ngx_memcmp(b->pos, e->bson->pos, e->len)) {
        ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                      "mongo: received wrong BSON"
                      " (doesn't match \"logout\" response)");
        return NGX_ERROR;
    }

    b->pos += e->len;

    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: logged out");

    u = r->upstream;

    if (mctx->auth_user) {
        u->process_header = ngx_http_mongo_process_nonce;

    } else if (mctx->conf->opcode->code != NGX_HTTP_MONGO_OP_QUERY) {
        u->process_header = ngx_http_mongo_process_status;

    } else {
        u->process_header = ngx_http_mongo_process_header;
    }

    return u->process_header(r);
}


static ngx_int_t
ngx_http_mongo_process_nonce(ngx_http_request_t *r)
{
    ngx_http_mongo_ctx_t         *mctx;
    ngx_http_mongo_predefined_t  *e;
    ngx_http_upstream_t          *u;
    ngx_buf_t                    *b;
    ngx_int_t                     rc;

    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: process nonce");

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    b = &r->upstream->buffer;

    rc = ngx_http_mongo_process_wire(r, mctx->request_id, 1, -1);
    if (rc != NGX_OK) {
        return rc;
    }

    b->pos += NGX_HTTP_MONGO_RES_HEADER_SIZE;

    if ((int32_t) b->pos[0] < 28
        || b->pos[4] != NGX_HTTP_MONGO_BSON_STRING
        || ngx_strcmp("nonce", b->pos + 5))
    {
        goto invalid;
    }

    mctx->nonce.len = (int32_t) b->pos[11];

    if ((int32_t) b->pos[0] != 28 + (int32_t) mctx->nonce.len) {
        goto invalid;
    }

    mctx->nonce.data = ngx_pnalloc(r->pool, mctx->nonce.len);
    if (mctx->nonce.data == NULL) {
        return NGX_ERROR;
    }

    ngx_memcpy(mctx->nonce.data, b->pos + 15, mctx->nonce.len);

    e = &ngx_http_mongo_predefined[NGX_HTTP_MONGO_OK];

    if (ngx_memcmp(b->pos + 15 + mctx->nonce.len,
                   e->bson->pos + sizeof(int32_t),
                   e->len - sizeof(int32_t)))
    {
        goto invalid;
    }

    b->pos += 28 + mctx->nonce.len;

    mctx->nonce.len--;

    ngx_log_debug2(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: nonce: \"%V\" (len: %uz)",
                   &mctx->nonce, mctx->nonce.len);

    u = r->upstream;

    u->request_sent = 0;
    u->request_bufs = ngx_http_mongo_create_auth_request(r);
    if (u->request_bufs == NULL) {
        return NGX_ERROR;
    }

    u->process_header = ngx_http_mongo_process_auth;

    ngx_http_mongo_send_request(r, u);

    return u->process_header(r);

invalid:

    ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                  "mongo: received wrong BSON"
                  " (doesn't match \"getnonce\" response)");
    return NGX_ERROR;
}


static ngx_int_t
ngx_http_mongo_process_auth(ngx_http_request_t *r)
{
    ngx_http_mongo_ctx_t         *mctx;
    ngx_http_mongo_predefined_t  *e;
    ngx_http_upstream_t          *u;
    ngx_buf_t                    *b;
    ngx_int_t                     rc;

    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: process auth");

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    b = &r->upstream->buffer;

    rc = ngx_http_mongo_process_wire(r, mctx->request_id, 1, -1);
    if (rc != NGX_OK) {
        return rc;
    }

    b->pos += NGX_HTTP_MONGO_RES_HEADER_SIZE;

    e = &ngx_http_mongo_predefined[NGX_HTTP_MONGO_OK];

    if ((int32_t) b->pos[0] != e->len
        || ngx_memcmp(b->pos, e->bson->pos, e->len))
    {

        e = &ngx_http_mongo_predefined[NGX_HTTP_MONGO_AUTH_FAIL];

        if ((int32_t) b->pos[0] != e->len
            || ngx_memcmp(b->pos, e->bson->pos, e->len))
        {
            ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                          "mongo: received wrong BSON"
                          " (doesn't match \"authentication\" response)");
            return NGX_ERROR;

        } else {
            b->pos += e->len;

            ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                          "mongo: authentication failed for \"%V\"",
                          mctx->auth_user);

            u = r->upstream;

            u->headers_in.status_n = NGX_HTTP_BAD_GATEWAY;
            u->headers_in.content_length_n = 0;
            u->keepalive = 1;

            return NGX_OK;
        }
    }

    b->pos += e->len;

    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: authentication succeeded for \"%V\"",
                   mctx->auth_user);

    u = r->upstream;

    u->request_sent = 0;
    u->request_bufs = mctx->real_request;

    if (mctx->conf->opcode->code != NGX_HTTP_MONGO_OP_QUERY) {
        u->process_header = ngx_http_mongo_process_status;

    } else {
        u->process_header = ngx_http_mongo_process_header;
    }

    ngx_http_mongo_send_request(r, u);

    return u->process_header(r);
}


static ngx_int_t
ngx_http_mongo_process_status(ngx_http_request_t *r)
{
    ngx_http_mongo_ctx_t         *mctx;
    ngx_http_mongo_predefined_t  *e;
    ngx_http_upstream_t          *u;
    ngx_buf_t                    *b;
    ngx_int_t                     rc;

    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: process status");

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    b = &r->upstream->buffer;

    rc = ngx_http_mongo_process_wire(r, mctx->request_id, 1, -1);
    if (rc != NGX_OK) {
        return rc;
    }

    b->pos += NGX_HTTP_MONGO_RES_HEADER_SIZE;

    e = &ngx_http_mongo_predefined[NGX_HTTP_MONGO_NO_ERROR];

    if ((int32_t) b->pos[0] != e->len
        || ngx_memcmp(b->pos, e->bson->pos, 7)
        || ngx_memcmp(b->pos + 11, e->bson->pos + 11, 14)
        || ngx_memcmp(b->pos + 29, e->bson->pos + 29, 18))
    {
        b->pos += (int32_t) b->pos[0];

        ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                      "mongo: query failed");
        return NGX_ERROR;
    }

    b->pos += e->len;

    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: query processed successfully");

    u = r->upstream;

    u->headers_in.status_n = NGX_HTTP_NO_CONTENT;
    u->headers_in.content_length_n = 0;
    u->keepalive = 1;

    return NGX_OK;
}


static ngx_int_t
ngx_http_mongo_process_header(ngx_http_request_t *r)
{
    ngx_http_mongo_ctx_t  *mctx;
    ngx_http_upstream_t   *u;
    ngx_buf_t             *b;
    ngx_int_t              rc;

    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: process header");

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    b = &r->upstream->buffer;

    rc = ngx_http_mongo_process_wire(r, mctx->request_id, 0, 0);
    if (rc != NGX_OK) {
        return rc;
    }

    u = r->upstream;

    u->headers_in.status_n = NGX_HTTP_OK;
    u->headers_in.content_length_n = (int32_t) b->pos[0]
                                     - NGX_HTTP_MONGO_RES_HEADER_SIZE;

    if (u->headers_in.content_length_n) {
        ngx_str_set(&r->headers_out.content_type, "application/x-bson");
        r->headers_out.content_type_len = sizeof("application/x-bson") - 1;
        r->headers_out.content_type_lowcase = NULL;
    }

    b->pos += NGX_HTTP_MONGO_RES_HEADER_SIZE;

    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: header processed successfully");

    return NGX_OK;
}


static void
ngx_http_mongo_abort_request(ngx_http_request_t *r)
{
    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: abort request");
}


static void
ngx_http_mongo_finalize_request(ngx_http_request_t *r, ngx_int_t rc)
{
    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "mongo: finalize request, rc:%d", rc);
}


static ngx_int_t
ngx_http_mongo_input_filter_init(void *data)
{
    ngx_http_request_t   *r = data;
    ngx_http_upstream_t  *u;

    u = r->upstream;

    u->pipe->length = u->headers_in.content_length_n;
    u->length = u->headers_in.content_length_n;

    return NGX_OK;
}


/*
 * source: ngx_event_pipe_copy_input_filter
 * + p->length verification for upstream keepalive module
 */
static ngx_int_t
ngx_http_mongo_copy_filter(ngx_event_pipe_t *p, ngx_buf_t *buf)
{
    ngx_buf_t           *b;
    ngx_chain_t         *cl;
    ngx_http_request_t  *r;

    if (buf->pos == buf->last) {
        goto keepalive;
    }

    if (p->free) {
        cl = p->free;
        b = cl->buf;
        p->free = cl->next;
        ngx_free_chain(p->pool, cl);

    } else {
        b = ngx_alloc_buf(p->pool);
        if (b == NULL) {
            return NGX_ERROR;
        }
    }

    ngx_memcpy(b, buf, sizeof(ngx_buf_t));
    b->shadow = buf;
    b->tag = p->tag;
    b->last_shadow = 1;
    b->recycled = 1;
    buf->shadow = b;

    cl = ngx_alloc_chain_link(p->pool);
    if (cl == NULL) {
        return NGX_ERROR;
    }

    cl->buf = b;
    cl->next = NULL;

    ngx_log_debug1(NGX_LOG_DEBUG_EVENT, p->log, 0,
                   "mongo: input buf #%d", b->num);

    if (p->in) {
        *p->last_in = cl;
    } else {
        p->in = cl;
    }
    p->last_in = &cl->next;

    if (p->length == -1) {
        return NGX_OK;
    }

    p->length -= b->last - b->pos;

keepalive:

    if (p->length == 0) {
        r = p->input_ctx;
        p->upstream_done = 1;
        r->upstream->keepalive = 1;

    } else if (p->length < 0) {
        r = p->input_ctx;
        p->upstream_done = 1;

        ngx_log_error(NGX_LOG_WARN, r->connection->log, 0,
                      "mongo: upstream sent too much data");
    }

    return NGX_OK;
}


/*
 * source: ngx_http_upstream_non_buffered_filter
 * + u->length verification for upstream keepalive module
 */
static ngx_int_t
ngx_http_mongo_non_buffered_copy_filter(void *data, ssize_t bytes)
{
    ngx_http_request_t   *r = data;
    ngx_buf_t            *b;
    ngx_chain_t          *cl, **ll;
    ngx_http_upstream_t  *u;

    u = r->upstream;

    for (cl = u->out_bufs, ll = &u->out_bufs; cl; cl = cl->next) {
        ll = &cl->next;
    }

    cl = ngx_chain_get_free_buf(r->pool, &u->free_bufs);
    if (cl == NULL) {
        return NGX_ERROR;
    }

    *ll = cl;

    cl->buf->flush = 1;
    cl->buf->memory = 1;

    b = &u->buffer;

    cl->buf->pos = b->last;
    b->last += bytes;
    cl->buf->last = b->last;
    cl->buf->tag = u->output.tag;

    if (u->length == -1) {
        return NGX_OK;
    }

    u->length -= bytes;

    if (u->length == 0) {
        u->keepalive = 1;

    } else if (u->length < 0) {
        ngx_log_error(NGX_LOG_WARN, r->connection->log, 0,
                      "mongo: upstream sent too much data");
    }

    return NGX_OK;
}


static ngx_int_t
ngx_http_mongo_request_namespace_variable(ngx_http_request_t *r,
    ngx_http_variable_value_t *v, uintptr_t data)
{
    ngx_http_mongo_loc_conf_t  *mlcf;
    ngx_http_mongo_ctx_t       *mctx;
    ngx_str_t                  *var;

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    if (mctx) {
        var = mctx->namespace;

    } else {
        mlcf = ngx_http_get_module_loc_conf(r, ngx_http_mongo_module);

        if (mlcf->namespace.cv) {
            v->not_found = 1;
            return NGX_OK;
        }

        var = &mlcf->namespace.sv;
    }

    if (var && var->len) {
        v->valid = 1;
        v->no_cacheable = 0;
        v->not_found = 0;

        v->len = var->len;
        v->data = var->data;

    } else {
        v->not_found = 1;
    }

    return NGX_OK;
}


static ngx_int_t
ngx_http_mongo_request_query_variable(ngx_http_request_t *r,
    ngx_http_variable_value_t *v, uintptr_t data)
{
    ngx_http_mongo_loc_conf_t  *mlcf;
    ngx_http_mongo_ctx_t       *mctx;
    ngx_str_t                  *var;

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    if (mctx) {
        var = mctx->query;

    } else {
        mlcf = ngx_http_get_module_loc_conf(r, ngx_http_mongo_module);

        if (mlcf->upstream.pass_request_body || mlcf->query.cv) {
            v->not_found = 1;
            return NGX_OK;

        }

        var = &mlcf->query.sv;
    }

    if (var && var->len) {
        v->valid = 1;
        v->no_cacheable = 0;
        v->not_found = 0;

        v->len = var->len;
        v->data = var->data;

    } else {
        v->not_found = 1;
    }

    return NGX_OK;
}


static ngx_int_t
ngx_http_mongo_request_bson_variable(ngx_http_request_t *r,
    ngx_http_variable_value_t *v, uintptr_t data)
{
    ngx_http_mongo_loc_conf_t  *mlcf;
    ngx_http_mongo_ctx_t       *mctx;
    ngx_buf_t                  *var;

    mctx = ngx_http_get_module_ctx(r, ngx_http_mongo_module);

    if (mctx) {
        var = mctx->bson;

    } else {
        mlcf = ngx_http_get_module_loc_conf(r, ngx_http_mongo_module);

        if (mlcf->upstream.pass_request_body || mlcf->query.cv) {
            v->not_found = 1;
            return NGX_OK;
        }

        var = mlcf->bson;
    }

    if (var && ngx_buf_size(var)) {
        v->valid = 1;
        v->no_cacheable = 0;
        v->not_found = 0;

        v->len = ngx_buf_size(var);
        v->data = var->pos;

    } else {
        v->not_found = 1;
    }

    return NGX_OK;
}


static ngx_buf_t *
ngx_http_mongo_bson_empty(ngx_pool_t *pool)
{
    ngx_buf_t  *out;

    out = ngx_create_temp_buf(pool, 5);
    if (out == NULL) {
        return NULL;
    }

    *out->last++ = 0x05;
    *out->last++ = 0x00;
    *out->last++ = 0x00;
    *out->last++ = 0x00;
    *out->last++ = 0x00;

    return out;
}


static ngx_http_mongo_bson_t *
ngx_http_mongo_bson_palloc(ngx_pool_t *pool, ngx_buf_t *buf,
    ngx_http_mongo_bson_t *parent)
{
    ngx_http_mongo_bson_t  *bson;

    bson = ngx_palloc(pool, sizeof(ngx_http_mongo_bson_t));
    if (bson == NULL) {
        return NULL;
    }

    bson->parent = parent;

    bson->start = buf->last;
    buf->last += sizeof(int32_t);

    bson->array_idx = -1;

    return bson;
}


static ngx_http_mongo_bson_t *
ngx_http_mongo_bson_finish(ngx_http_mongo_bson_t *bson, ngx_buf_t *buf)
{
    int32_t  len;

    *buf->last++ = 0x00;

    len = buf->last - bson->start;
    ngx_memcpy(bson->start, &len, sizeof(int32_t));

    return bson->parent;
}


static ngx_int_t
ngx_http_mongo_json_to_bson_check(ngx_http_mongo_json_to_bson_ctx_t *ctx,
    size_t len)
{
    if (ctx->bson == NULL) {
        return NGX_ERROR;
    }

    len += 3 * sizeof(int8_t)
           + (ctx->bson->array_idx > -1 ? NGX_INT64_LEN : ctx->key.len);

    if (ctx->buf->last + len >= ctx->buf->end) {
        return NGX_ERROR;
    }

    return NGX_OK;
}


static void
ngx_http_mongo_json_to_bson_header(ngx_http_mongo_json_to_bson_ctx_t *ctx,
    int8_t type)
{
    ngx_buf_t  *b;

    b = ctx->buf;

    *b->last++ = type;

    if (ctx->bson->array_idx > -1) {
        b->last = ngx_snprintf(b->last, NGX_INT64_LEN, "%d",
                               ctx->bson->array_idx++);
    } else {
        b->last = ngx_copy(b->last, ctx->key.data, ctx->key.len);
    }

    *b->last++ = 0x00;
}


static int
ngx_http_mongo_json_to_bson_null(void *data)
{
    ngx_http_mongo_json_to_bson_ctx_t  *ctx = data;

    if (ngx_http_mongo_json_to_bson_check(ctx, 0)) {
        return 0;
    }

    ngx_http_mongo_json_to_bson_header(ctx, NGX_HTTP_MONGO_BSON_NULL);

    return 1;
}


static int
ngx_http_mongo_json_to_bson_boolean(void *data, int value)
{
    ngx_http_mongo_json_to_bson_ctx_t  *ctx = data;

    if (ngx_http_mongo_json_to_bson_check(ctx, sizeof(int8_t))) {
        return 0;
    }

    ngx_http_mongo_json_to_bson_header(ctx, NGX_HTTP_MONGO_BSON_BOOLEAN);
    *ctx->buf->last++ = value ? 0x01 : 0x00;

    return 1;
}


static int
ngx_http_mongo_json_to_bson_integer(void *data, long long value)
{
    ngx_http_mongo_json_to_bson_ctx_t  *ctx = data;

    if (value < -0x7fffffff - 1 || value > 0x7fffffff) {
        if (ngx_http_mongo_json_to_bson_check(ctx, sizeof(int64_t))) {
            return 0;
        }

        ngx_http_mongo_json_to_bson_header(ctx, NGX_HTTP_MONGO_BSON_INT64);
        ctx->buf->last = ngx_copy(ctx->buf->last, &value, sizeof(int64_t));

    } else {
        if (ngx_http_mongo_json_to_bson_check(ctx, sizeof(int32_t))) {
            return 0;
        }

        ngx_http_mongo_json_to_bson_header(ctx, NGX_HTTP_MONGO_BSON_INT32);
        ctx->buf->last = ngx_copy(ctx->buf->last, &value, sizeof(int32_t));
    }

    return 1;
}


static int
ngx_http_mongo_json_to_bson_double(void *data, double value)
{
    ngx_http_mongo_json_to_bson_ctx_t  *ctx = data;

    if (ngx_http_mongo_json_to_bson_check(ctx, sizeof(double))) {
        return 0;
    }

    ngx_http_mongo_json_to_bson_header(ctx, NGX_HTTP_MONGO_BSON_DOUBLE);
    ctx->buf->last = ngx_copy(ctx->buf->last, &value, sizeof(double));

    return 1;
}


static int
ngx_http_mongo_json_to_bson_string(void *data, const unsigned char *value,
    size_t len)
{
    ngx_http_mongo_json_to_bson_ctx_t  *ctx = data;
    ngx_buf_t                          *b;

    len++; /* trailing '\0' */

    if (ngx_http_mongo_json_to_bson_check(ctx, sizeof(int32_t) + len)) {
        return 0;
    }

    b = ctx->buf;

    ngx_http_mongo_json_to_bson_header(ctx, NGX_HTTP_MONGO_BSON_STRING);
    b->last = ngx_copy(b->last, &len, sizeof(int32_t));
    b->last = ngx_copy(b->last, value, len - 1);
    *b->last++ = 0x00;

    return 1;
}


static int
ngx_http_mongo_json_to_bson_map_key(void *data, const unsigned char *value,
    size_t len)
{
    ngx_http_mongo_json_to_bson_ctx_t  *ctx = data;

    ctx->key.data = (u_char *) value;
    ctx->key.len = len;

    return 1;
}


static int
ngx_http_mongo_json_to_bson_start_map(void *data)
{
    ngx_http_mongo_json_to_bson_ctx_t  *ctx = data;

    if (ctx->bson) {
        ngx_http_mongo_json_to_bson_header(ctx, NGX_HTTP_MONGO_BSON_BSON);
    }

    ctx->bson = ngx_http_mongo_bson_palloc(ctx->pool, ctx->buf, ctx->bson);
    if (ctx->bson == NULL) {
        return 0;
    }

    return 1;
}


static int
ngx_http_mongo_json_to_bson_end_map(void *data)
{
    ngx_http_mongo_json_to_bson_ctx_t  *ctx = data;

    ctx->bson = ngx_http_mongo_bson_finish(ctx->bson, ctx->buf);

    return 1;
}


static int
ngx_http_mongo_json_to_bson_start_array(void *data)
{
    ngx_http_mongo_json_to_bson_ctx_t  *ctx = data;

    if (!ctx->bson) {
        return 1;
    }

    ngx_http_mongo_json_to_bson_header(ctx, NGX_HTTP_MONGO_BSON_ARRAY);

    ctx->bson = ngx_http_mongo_bson_palloc(ctx->pool, ctx->buf, ctx->bson);
    if (ctx->bson == NULL) {
        return 0;
    }

    ctx->bson->array_idx = 0;

    return 1;
}


static int
ngx_http_mongo_json_to_bson_end_array(void *data)
{
    ngx_http_mongo_json_to_bson_ctx_t  *ctx = data;

    if (!ctx->bson) {
        return 1;
    }

    ctx->bson = ngx_http_mongo_bson_finish(ctx->bson, ctx->buf);
    if (ctx->bson == NULL) {
        return 0;
    }

    return 1;
}


static ngx_buf_t *
ngx_http_mongo_json_to_bson(ngx_str_t *json, ngx_pool_t *pool)
{
    ngx_http_mongo_json_to_bson_ctx_t   ctx;
    yajl_handle                         yajl;
    ngx_buf_t                          *out;

    ngx_log_debug2(NGX_LOG_DEBUG_HTTP, pool->log, 0,
                   "mongo: parse JSON \"%V\" (len: %uz)", json, json->len);

    if (json->len == 0) {
        return ngx_http_mongo_bson_empty(pool);
    }

    out = ngx_create_temp_buf(pool, 32 + 2 * json->len);
    if (out == NULL) {
        return NULL;
    }

    ctx.buf = out;
    ctx.pool = pool;
    ctx.bson = NULL;

    yajl = yajl_alloc(&ngx_http_mongo_json_to_bson_callbacks, NULL, &ctx);
    if (yajl == NULL) {
        return NULL;
    }

    yajl_config(yajl, yajl_allow_comments, 1);

    if (yajl_parse(yajl, json->data, json->len) != yajl_status_ok) {
        return NULL;
    }

    if (yajl_complete_parse(yajl) != yajl_status_ok) {
        return NULL;
    }

    return out;
}


static ngx_buf_t *
ngx_http_mongo_json_chain_to_bson(ngx_chain_t *in, size_t len, ngx_pool_t *pool)
{
    ngx_http_mongo_json_to_bson_ctx_t   ctx;
    yajl_handle                         yajl;
    ngx_buf_t                          *out;
    ngx_chain_t                        *cl;

    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, pool->log, 0,
                   "mongo: parse JSON chain (len: %uz)", len);

    out = ngx_create_temp_buf(pool, 32 + 2 * len);
    if (out == NULL) {
        return NULL;
    }

    ctx.buf = out;
    ctx.pool = pool;
    ctx.bson = NULL;

    yajl = yajl_alloc(&ngx_http_mongo_json_to_bson_callbacks, NULL, &ctx);
    if (yajl == NULL) {
        return NULL;
    }

    yajl_config(yajl, yajl_allow_comments, 1);

    for (cl = in; cl; cl = cl->next) {
        if (yajl_parse(yajl, cl->buf->pos, ngx_buf_size(cl->buf))
            != yajl_status_ok)
        {
            return NULL;
        }
    }

    if (yajl_complete_parse(yajl) != yajl_status_ok) {
        return NULL;
    }

    return out;
}


static ngx_int_t
ngx_http_mongo_init(ngx_cycle_t *cycle)
{
    ngx_http_mongo_predefined_t  *e;
    ngx_uint_t                    i;

    e = ngx_http_mongo_predefined;
    for (i = 0; e[i].json.len; i++) {
        e[i].bson = ngx_http_mongo_json_to_bson(&e[i].json, cycle->pool);
        if (e[i].bson == NULL) {
            ngx_log_error(NGX_LOG_EMERG, cycle->log, 0,
                          "mongo: invalid JSON \"%V\""
                          " embedded in ngx_mongo", &e[i].json);
            return NGX_ERROR;
        }

        if (ngx_buf_size(e[i].bson) != e[i].len) {
            ngx_log_error(NGX_LOG_EMERG, cycle->log, 0,
                          "mongo: BSON length mismatch for \"%V\""
                          " embedded in ngx_mongo", &e[i].json);
            return NGX_ERROR;
        }
    }

    return NGX_OK;
}


static ngx_int_t
ngx_http_mongo_add_variables(ngx_conf_t *cf)
{
    ngx_http_variable_t  *var, *v;

    ngx_http_mongo_auth_used = 0;

    for (v = ngx_http_mongo_vars; v->name.len; v++) {
        var = ngx_http_add_variable(cf, &v->name, v->flags);
        if (var == NULL) {
            return NGX_ERROR;
        }

        var->get_handler = v->get_handler;
        var->data = v->data;
    }

    return NGX_OK;
}


static void *
ngx_http_mongo_create_loc_conf(ngx_conf_t *cf)
{
    ngx_http_mongo_loc_conf_t  *conf;

    conf = ngx_pcalloc(cf->pool, sizeof(ngx_http_mongo_loc_conf_t));
    if (conf == NULL) {
        return NULL;
    }

    /*
     * set by ngx_pcalloc():
     *
     *     conf->upstream.* = 0 / NULL
     *     conf->opcode = NULL
     *     conf->auth_user.* = 0 / NULL
     *     conf->auth_pass.* = 0 / NULL
     *     conf->auth_digest = { 0, NULL }
     *     conf->database = { 0, NULL }
     *     conf->namespace.* = 0 / NULL
     *     conf->query.* = 0 / NULL
     *     conf->limit = 0
     *     conf->skip = 0
     *     conf->bson = NULL
     */

    conf->upstream.connect_timeout = NGX_CONF_UNSET_MSEC;
    conf->upstream.send_timeout = NGX_CONF_UNSET_MSEC;
    conf->upstream.read_timeout = NGX_CONF_UNSET_MSEC;

    conf->upstream.buffering = NGX_CONF_UNSET;
    conf->upstream.buffer_size = NGX_CONF_UNSET_SIZE;
    conf->upstream.busy_buffers_size_conf = NGX_CONF_UNSET_SIZE;

    /* the hardcoded values */
    conf->upstream.cyclic_temp_file = 0;
    conf->upstream.ignore_client_abort = 0;
    conf->upstream.send_lowat = 0;
    conf->upstream.max_temp_file_size = 0;
    conf->upstream.temp_file_write_size = 0;
    conf->upstream.intercept_errors = 1;
    conf->upstream.intercept_404 = 1;
    conf->upstream.pass_request_headers = 0;
    conf->upstream.pass_request_body = 0;

    return conf;
}


static char *
ngx_http_mongo_merge_loc_conf(ngx_conf_t *cf, void *parent, void *child)
{
    ngx_http_mongo_loc_conf_t  *prev = parent;
    ngx_http_mongo_loc_conf_t  *conf = child;
    size_t                      size;

    ngx_conf_merge_msec_value(conf->upstream.connect_timeout,
                              prev->upstream.connect_timeout, 60000);

    ngx_conf_merge_msec_value(conf->upstream.send_timeout,
                              prev->upstream.send_timeout, 60000);

    ngx_conf_merge_msec_value(conf->upstream.read_timeout,
                              prev->upstream.read_timeout, 60000);

    ngx_conf_merge_value(conf->upstream.buffering,
                         prev->upstream.buffering, 1);

    ngx_conf_merge_size_value(conf->upstream.buffer_size,
                              prev->upstream.buffer_size,
                              (size_t) ngx_pagesize);

    ngx_conf_merge_bufs_value(conf->upstream.bufs, prev->upstream.bufs,
                              8, ngx_pagesize);

    if (conf->upstream.bufs.num < 2) {
        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                           "there must be at least 2 \"mongo_buffers\"");
        return NGX_CONF_ERROR;
    }

    size = conf->upstream.buffer_size;
    if (size < conf->upstream.bufs.size) {
        size = conf->upstream.bufs.size;
    }

    ngx_conf_merge_size_value(conf->upstream.busy_buffers_size_conf,
                              prev->upstream.busy_buffers_size_conf,
                              NGX_CONF_UNSET_SIZE);

    if (conf->upstream.busy_buffers_size_conf == NGX_CONF_UNSET_SIZE) {
        conf->upstream.busy_buffers_size = 2 * size;
    } else {
        conf->upstream.busy_buffers_size =
                                         conf->upstream.busy_buffers_size_conf;
    }

    if (conf->upstream.busy_buffers_size < size) {
        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
             "\"mongo_busy_buffers_size\" must be equal or bigger than "
             "maximum of the value of \"mongo_buffer_size\" and "
             "one of the \"mongo_buffers\"");

        return NGX_CONF_ERROR;
    }

    if (conf->upstream.busy_buffers_size
        > (conf->upstream.bufs.num - 1) * conf->upstream.bufs.size)
    {
        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
             "\"mongo_busy_buffers_size\" must be less than "
             "the size of all \"mongo_buffers\" minus one buffer");

        return NGX_CONF_ERROR;
    }

    ngx_conf_merge_bitmask_value(conf->upstream.next_upstream,
                                 prev->upstream.next_upstream,
                                 (NGX_CONF_BITMASK_SET
                                  |NGX_HTTP_UPSTREAM_FT_ERROR
                                  |NGX_HTTP_UPSTREAM_FT_TIMEOUT));

    if (conf->upstream.next_upstream & NGX_HTTP_UPSTREAM_FT_OFF) {
        conf->upstream.next_upstream = NGX_CONF_BITMASK_SET
                                       |NGX_HTTP_UPSTREAM_FT_OFF;
    }

    if (conf->upstream.upstream == NULL) {
        conf->upstream.upstream = prev->upstream.upstream;
    }

    if (conf->upstream.local == NULL) {
        conf->upstream.local = prev->upstream.local;
    }

    if (ngx_conf_str_empty(&conf->auth_user)) {
        conf->auth_user = prev->auth_user;
        conf->auth_pass = prev->auth_pass;
        conf->auth_digest = prev->auth_digest;
    }

    if (conf->opcode == NULL) {
        conf->opcode = prev->opcode;
        conf->database = prev->database;
        conf->namespace = prev->namespace;
        conf->query = prev->query;
        conf->limit = prev->limit;
        conf->skip = prev->skip;
        conf->bson = prev->bson;
    }

    return NGX_CONF_OK;
}


static char *
ngx_conf_str_set(ngx_conf_t *cf, ngx_conf_str_t *cfs, ngx_str_t *s,
    const char *name, ngx_str_t *cmd, ngx_int_t not_empty)
{
    ngx_http_compile_complex_value_t  ccv;

    if (s->len == 0 && not_empty) {
        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                           "config string \"%s\" is empty in \"%V\" directive",
                           name, cmd);
        return NGX_CONF_ERROR;
    }

    if (s->len > 0 && s->data[0] == '=') {
        cfs->sv.data = s->data + 1;
        cfs->sv.len = s->len - 1;
        cfs->cv = NULL;

    } else if (ngx_http_script_variables_count(s)) {
        cfs->cv = ngx_palloc(cf->pool, sizeof(ngx_http_complex_value_t));
        if (cfs->cv == NULL) {
            return NGX_CONF_ERROR;
        }

        ngx_memzero(&ccv, sizeof(ngx_http_compile_complex_value_t));

        ccv.cf = cf;
        ccv.value = s;
        ccv.complex_value = cfs->cv;

        if (ngx_http_compile_complex_value(&ccv) != NGX_OK) {
            return NGX_CONF_ERROR;
        }

    } else {
        cfs->sv = *s;
        cfs->cv = NULL;
    }

    cfs->name.data = (u_char *) name;
    cfs->name.len = ngx_strlen(name);

    cfs->cmd = cmd;

    return NGX_CONF_OK;
}


static ngx_str_t *
ngx_conf_str_get(ngx_http_request_t *r, ngx_conf_str_t *cfs,
    ngx_int_t not_empty)
{
    ngx_str_t  *s;

    if (cfs->cv == NULL) {
        if (cfs->sv.len == 0 && not_empty) {
            ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                          "%V: config string \"%V\" is empty",
                          cfs->cmd, &cfs->name);
            return NULL;
        }

        return &cfs->sv;
    }

    s = ngx_palloc(r->pool, sizeof(ngx_str_t));
    if (s == NULL) {
        return NULL;
    }

    if (ngx_http_complex_value(r, cfs->cv, s) != NGX_OK) {
        return NULL;
    }

    if (s->len == 0 && not_empty) {
        ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                      "%V: config string \"%V\" evaluated to an empty string"
                      " (source: \"%V\")",
                      cfs->cmd, &cfs->name, &cfs->cv->value);
        return NULL;
    }

    return s;
}


static char *
ngx_http_mongo_pass(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_http_mongo_loc_conf_t  *mlcf = conf;
    ngx_http_core_loc_conf_t   *clcf;
    ngx_str_t                  *value;
    ngx_url_t                   u;

    if (mlcf->upstream.upstream) {
        return "is duplicate";
    }

    clcf = ngx_http_conf_get_module_loc_conf(cf, ngx_http_core_module);
    clcf->handler = ngx_http_mongo_handler;

    value = cf->args->elts;

    ngx_memzero(&u, sizeof(ngx_url_t));

    u.url = value[1];
    u.no_resolve = 1;

    mlcf->upstream.upstream = ngx_http_upstream_add(cf, &u, 0);
    if (mlcf->upstream.upstream == NULL) {
        return NGX_CONF_ERROR;
    }

    return NGX_CONF_OK;
}


static char *
ngx_http_mongo_auth(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_http_mongo_loc_conf_t  *mlcf = conf;
    ngx_str_t                  *value = cf->args->elts;
    ngx_md5_t                   md5;
    u_char                      buf[16];

    if (!ngx_conf_str_empty(&mlcf->auth_user)) {
        return "is duplicate";
    }

    if (ngx_conf_str_set(cf, &mlcf->auth_user, &value[1], "username",
                         &cmd->name, 1))
    {
        return NGX_CONF_ERROR;
    }

    if (ngx_conf_str_set(cf, &mlcf->auth_pass, &value[2], "password",
                         &cmd->name, 1))
    {
        return NGX_CONF_ERROR;
    }

    if (mlcf->auth_user.sv.len > 0 && mlcf->auth_pass.sv.len > 0) {
        ngx_md5_init(&md5);
        ngx_md5_update(&md5, mlcf->auth_user.sv.data, mlcf->auth_user.sv.len);
        ngx_md5_update(&md5, ":mongo:", sizeof(":mongo:") - 1);
        ngx_md5_update(&md5, mlcf->auth_pass.sv.data, mlcf->auth_pass.sv.len);
        ngx_md5_final(buf, &md5);

        mlcf->auth_digest.data = ngx_pnalloc(cf->pool, 32);
        mlcf->auth_digest.len = 32;

        ngx_hex_dump(mlcf->auth_digest.data, buf, 16);
    }

    ngx_http_mongo_auth_used = 1;

    return NGX_CONF_OK;
}


static char *
ngx_http_mongo_query(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_http_mongo_loc_conf_t  *mlcf = conf;
    ngx_str_t                  *value = cf->args->elts;
    ngx_http_mongo_opcode_t    *e;
    ngx_int_t                   number;
    ngx_uint_t                  i;
    u_char                     *dot;

    if (cf->args->nelts < 4) {
        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                           "mongo: invalid number of arguments"
                           " in \"%V\" directive", &cmd->name);
        return NGX_CONF_ERROR;
    }

    if (mlcf->opcode != NULL) {
        return "is duplicate";
    }

    e = ngx_http_mongo_opcodes;
    for (i = 0; e[i].name.len; i++) {
        if ((e[i].name.len == value[1].len)
            && (ngx_strcmp(e[i].name.data, value[1].data) == 0))
        {
            break;
        }
    }

    if (e[i].name.len == 0) {
        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                           "mongo: invalid opcode \"%V\""
                           " in \"%V\" directive", &value[1], &cmd->name);
        return NGX_CONF_ERROR;
    }

    mlcf->opcode = &e[i];

    if (ngx_conf_str_set(cf, &mlcf->namespace, &value[2], "namespace",
                         &cmd->name, 1))
    {
        return NGX_CONF_ERROR;
    }

    if (mlcf->namespace.sv.len > 0) {
        dot = ngx_strlchr(value[2].data, ngx_str_last(&value[2]), '.');

        if (dot == ngx_str_last(&value[2])
            || (e[i].cmd && dot != NULL)
            || (!e[i].cmd && dot == NULL))
        {
            ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                               "mongo: invalid namespace \"%V\""
                               " in \"%V\" directive",
                               &value[2], &cmd->name);
            return NGX_CONF_ERROR;
        }

        if (e[i].cmd) {
            mlcf->database = mlcf->namespace.sv;

        } else {
            mlcf->database.data = value[2].data;
            mlcf->database.len = dot - value[2].data;
        }
    }

    if (ngx_strcmp(value[3].data, "$request_body") == 0) {
        mlcf->upstream.pass_request_body = 1;

    } else if (ngx_conf_str_set(cf, &mlcf->query, &value[3], "query",
                                &cmd->name, 0))
    {
        return NGX_CONF_ERROR;
    }

    if (e[i].cmd) {
        mlcf->limit = -1;
    }

    if (cf->args->nelts > 4) {
        if (e[i].cmd || e[i].code != NGX_HTTP_MONGO_OP_QUERY) {
            ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                               "mongo: invalid number of arguments"
                               " in \"%V\" directive", &cmd->name);
            return NGX_CONF_ERROR;
        }

        mlcf->limit = -0x7fffffff - 1;

        for (i = 4; i < cf->args->nelts; i++) {
            if (ngx_strncmp(value[i].data, "limit=", 6) == 0) {
                number = ngx_atoi(value[i].data + 6, value[i].len - 6);
                if (number == NGX_ERROR || number > 0x7fffffff) {
                    ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                                       "mongo: invalid \"limit\" value \"%*s\""
                                       " in \"%V\" directive",
                                       value[i].len - 6, value[i].data + 6,
                                       &cmd->name);
                    return NGX_CONF_ERROR;
                }

                mlcf->limit = -number;

                continue;
            }

            if (ngx_strncmp(value[i].data, "skip=", 5) == 0) {
                number = ngx_atoi(value[i].data + 5, value[i].len - 5);
                if (number == NGX_ERROR || number > 0x7fffffff) {
                    ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                                       "mongo: invalid \"skip\" value \"%*s\""
                                       " in \"%V\" directive",
                                       value[i].len - 5, value[i].data + 5,
                                       &cmd->name);
                    return NGX_CONF_ERROR;
                }

                mlcf->skip = number;

                continue;
            }

            ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                               "mongo: invalid parameter \"%V\" in \"%V\""
                               " directive", &value[i], &cmd->name);
            return NGX_CONF_ERROR;
        }
    }

    if (mlcf->upstream.pass_request_body || mlcf->query.cv) {
        return NGX_CONF_OK;
    }

    mlcf->bson = ngx_http_mongo_json_to_bson(&mlcf->query.sv, cf->pool);
    if (mlcf->bson == NULL) {
        ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                           "mongo: invalid JSON \"%V\"", &mlcf->query.sv);
        return NGX_CONF_ERROR;
    }

    return NGX_CONF_OK;
}
