/*
 * Copyright (c) 2011-2012, Simpl <foss@simpl.it>
 * Copyright (c) 2011-2012, FRiCKLE <info@frickle.com>
 * Copyright (c) 2011-2012, Piotr Sikora <piotr.sikora@frickle.com>
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


#define NGX_HTTP_MONGO_BSON_DOUBLE         0x01
#define NGX_HTTP_MONGO_BSON_STRING         0x02
#define NGX_HTTP_MONGO_BSON_BSON           0x03
#define NGX_HTTP_MONGO_BSON_ARRAY          0x04
#define NGX_HTTP_MONGO_BSON_BINARY         0x05
/*      deprecated                         0x06 */
#define NGX_HTTP_MONGO_BSON_OBJECT_ID      0x07
#define NGX_HTTP_MONGO_BSON_BOOLEAN        0x08
#define NGX_HTTP_MONGO_BSON_DATETIME       0x09
#define NGX_HTTP_MONGO_BSON_NULL           0x0A
/*      NGX_HTTP_MONGO_BSON_REGEXP         0x0B */
/*      deprecated                         0x0C */
#define NGX_HTTP_MONGO_BSON_JAVASCRIPT     0x0D
#define NGX_HTTP_MONGO_BSON_SYMBOL         0x0E
/*      NGX_HTTP_MONGO_BSON_JS_W_SCOPE     0x0F */
#define NGX_HTTP_MONGO_BSON_INT32          0x10
#define NGX_HTTP_MONGO_BSON_TIMESTAMP      0x11
#define NGX_HTTP_MONGO_BSON_INT64          0x12
/*      NGX_HTTP_MONGO_BSON_MIN_KEY        0xFF */
/*      NGX_HTTP_MONGO_BSON_MAX_KEY        0x7F */


#define NGX_HTTP_MONGO_BSON_TO_JSON_INIT   0
#define NGX_HTTP_MONGO_BSON_TO_JSON_TYPE   1
#define NGX_HTTP_MONGO_BSON_TO_JSON_NAME   2
#define NGX_HTTP_MONGO_BSON_TO_JSON_VALUE  3
#define NGX_HTTP_MONGO_BSON_TO_JSON_LAST   4
#define NGX_HTTP_MONGO_BSON_TO_JSON_DONE   5


typedef struct ngx_http_mongo_bson_s  ngx_http_mongo_bson_t;


typedef struct {
    ngx_flag_t              enable;
} ngx_http_mongo_json_loc_conf_t;


typedef struct {
    ngx_chain_t            *free;
    ngx_chain_t            *busy;

    off_t                   length;

    ngx_http_mongo_bson_t  *bson;

    ngx_buf_t               saved;
    u_char                  saved_data[8];

    int8_t                  state;
    int8_t                  type;

    int32_t                 copy;
    unsigned                skip:1;
} ngx_http_mongo_json_ctx_t;


struct ngx_http_mongo_bson_s {
    ngx_http_mongo_bson_t  *parent;

    int32_t                 length;
    int32_t                 consumed;

    unsigned                array:1;
    unsigned                init:1;
};


static ngx_int_t ngx_http_mongo_json_header_filter(ngx_http_request_t *r);
static ngx_int_t ngx_http_mongo_json_body_filter(ngx_http_request_t *r,
    ngx_chain_t *in);

static ngx_int_t ngx_http_mongo_bson_read(void *result, size_t len,
    ngx_buf_t *in, ngx_buf_t *saved);

static ngx_chain_t *ngx_http_mongo_bson_to_json(ngx_http_request_t *r,
    ngx_chain_t *in);

static ngx_buf_t *ngx_http_mongo_json_get_buf(ngx_http_request_t *r,
    size_t len, ngx_chain_t **head, ngx_chain_t **last);

static char *ngx_http_mongo_json(ngx_conf_t *cf, ngx_command_t *cmd,
    void *conf);

static ngx_int_t ngx_http_mongo_json_filter_reset(ngx_conf_t *cf);
static ngx_int_t ngx_http_mongo_json_filter_init(ngx_conf_t *cf);

static void *ngx_http_mongo_json_filter_create_conf(ngx_conf_t *cf);
static char *ngx_http_mongo_json_filter_merge_conf(ngx_conf_t *cf,
    void *parent, void *child);


static ngx_command_t ngx_http_mongo_json_filter_commands[] = {

    { ngx_string("mongo_json"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_HTTP_LIF_CONF
                        |NGX_CONF_FLAG,
      ngx_http_mongo_json,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_mongo_json_loc_conf_t, enable),
      NULL },

      ngx_null_command
};


static ngx_http_module_t ngx_http_mongo_json_filter_module_ctx = {
    ngx_http_mongo_json_filter_reset,        /* preconfiguration */
    ngx_http_mongo_json_filter_init,         /* postconfiguration */

    NULL,                                    /* create main configuration */
    NULL,                                    /* init main configuration */

    NULL,                                    /* create server configuration */
    NULL,                                    /* merge server configuration */

    ngx_http_mongo_json_filter_create_conf,  /* create location configuration */
    ngx_http_mongo_json_filter_merge_conf    /* merge location configuration */
};


ngx_module_t ngx_http_mongo_json_filter_module = {
    NGX_MODULE_V1,
    &ngx_http_mongo_json_filter_module_ctx,  /* module context */
    ngx_http_mongo_json_filter_commands,     /* module directives */
    NGX_HTTP_MODULE,                         /* module type */
    NULL,                                    /* init master */
    NULL,                                    /* init module */
    NULL,                                    /* init process */
    NULL,                                    /* init thread */
    NULL,                                    /* exit thread */
    NULL,                                    /* exit process */
    NULL,                                    /* exit master */
    NGX_MODULE_V1_PADDING
};


static ngx_http_output_header_filter_pt  ngx_http_next_header_filter;
static ngx_http_output_body_filter_pt    ngx_http_next_body_filter;

static ngx_flag_t                        ngx_http_mongo_json_filter_active = 0;


static ngx_int_t
ngx_http_mongo_json_header_filter(ngx_http_request_t *r)
{
    ngx_http_mongo_json_loc_conf_t  *mjlcf;
    ngx_http_mongo_json_ctx_t       *ctx;
    off_t                            len;

    mjlcf = ngx_http_get_module_loc_conf(r, ngx_http_mongo_json_filter_module);

    if (!mjlcf->enable
        || r->headers_out.content_type.len != sizeof("application/x-bson") - 1
        || ngx_strncmp(r->headers_out.content_type.data, "application/x-bson",
                       r->headers_out.content_type.len) != 0)
    {
        return ngx_http_next_header_filter(r);
    }

    r->headers_out.content_type_len = sizeof("application/json") - 1;
    ngx_str_set(&r->headers_out.content_type, "application/json");

    len = r->headers_out.content_length_n;
    ngx_http_clear_content_length(r);

    if (r->header_only) {
        return ngx_http_next_header_filter(r);
    }

    ctx = ngx_pcalloc(r->pool, sizeof(ngx_http_mongo_json_ctx_t));
    if (ctx == NULL) {
        return NGX_ERROR;
    }

    ctx->saved.start = ctx->saved_data;
    ctx->saved.pos = ctx->saved_data;
    ctx->saved.last = ctx->saved_data;
    ctx->saved.end = ctx->saved_data + 8;
    ctx->saved.temporary = 1;

    ctx->length = len;

    ngx_http_set_ctx(r, ctx, ngx_http_mongo_json_filter_module);

    r->filter_need_in_memory = 1;

    return ngx_http_next_header_filter(r);
}


static ngx_int_t
ngx_http_mongo_json_body_filter(ngx_http_request_t *r, ngx_chain_t *in)
{
    ngx_http_mongo_json_ctx_t  *ctx;
    ngx_chain_t                *out;
    ngx_int_t                   rc;

    if (in == NULL) {
        return ngx_http_next_body_filter(r, in);
    }

    ctx = ngx_http_get_module_ctx(r, ngx_http_mongo_json_filter_module);

    if (ctx == NULL) {
        return ngx_http_next_body_filter(r, in);
    }

    if (in->buf->last_buf) {
        if (ctx->state != NGX_HTTP_MONGO_BSON_TO_JSON_DONE) {
            ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                          "mongo_json: received last_buf while"
                          " still processing BSON");
            return NGX_ERROR;
        }

        return ngx_http_next_body_filter(r, in);
    }

    out = ngx_http_mongo_bson_to_json(r, in);

    if (out == NGX_CHAIN_ERROR) {
        return NGX_ERROR;

    } else if (out == NULL) {
        return ngx_http_next_body_filter(r, NULL);
    }

    rc = ngx_http_next_body_filter(r, out);

    ngx_chain_update_chains(r->pool, &ctx->free, &ctx->busy, &out,
                            (ngx_buf_tag_t) &ngx_http_mongo_json_filter_module);

    return rc;
}


static ngx_int_t
ngx_http_mongo_bson_read(void *result, size_t len, ngx_buf_t *in,
    ngx_buf_t *saved)
{
    ngx_buf_t  *b;
    size_t      size;

    if (!ngx_buf_size(saved) && ngx_buf_size(in) >= (off_t) len) {
        b = in;

    } else {
        size = (size_t) ngx_min(ngx_buf_size(in),
                                (off_t) len - ngx_buf_size(saved));
        if (size == 0) {
            return NGX_AGAIN;
        }

        saved->last = ngx_copy(saved->last, in->pos, size);
        in->pos += size;

        if (ngx_buf_size(saved) < (off_t) len) {
            return NGX_AGAIN;
        }

        b = saved;
    }

    ngx_memcpy(result, b->pos, len);

    if (b == in) {
        b->pos += len;

    } else {
        b->last = b->start;
    }

    return NGX_OK;
}


#define NGX_HTTP_MONGO_BSON_READ(result, consume)                              \
    if (ngx_http_mongo_bson_read(&result, sizeof(result), b, &ctx->saved)      \
        == NGX_AGAIN)                                                          \
    {                                                                          \
        continue;                                                              \
    }                                                                          \
                                                                               \
    if (consume) {                                                             \
        bson->consumed += sizeof(result);                                      \
    }


#define NGX_HTTP_MONGO_JSON_ENSURE(size)                                       \
    if (out == NULL || (out->end - out->last) < (off_t) (size)) {              \
        out = ngx_http_mongo_json_get_buf(r, size, &head, &last);              \
        if (out == NULL) {                                                     \
            return NGX_CHAIN_ERROR;                                            \
        }                                                                      \
    }


#define NGX_HTTP_MONGO_BSON_COPY(copy_fun, multi)                              \
    size = ngx_min((size_t) ngx_buf_size(b), (size_t) ctx->copy);              \
                                                                               \
    if (size == 0) {                                                           \
        continue;                                                              \
    }                                                                          \
                                                                               \
    NGX_HTTP_MONGO_JSON_ENSURE(multi * size);                                  \
    out->last = copy_fun(out->last, b->pos, size);                             \
                                                                               \
    ctx->copy -= size;                                                         \
                                                                               \
    bson->consumed += size;                                                    \
    b->pos += size;                                                            \
                                                                               \
    if (ctx->copy > 0) {                                                       \
        continue;                                                              \
    }


static ngx_chain_t *
ngx_http_mongo_bson_to_json(ngx_http_request_t *r, ngx_chain_t *in)
{
    ngx_http_mongo_json_ctx_t  *ctx;
    ngx_http_mongo_bson_t      *bson;
    ngx_chain_t                *cl, *head, *last;
    ngx_buf_t                  *b, *out;
    u_char                     *p;
    size_t                      size;
    double                      vald;
    int8_t                      val8;
    int32_t                     val32;
    int64_t                     val64;

    ctx = ngx_http_get_module_ctx(r, ngx_http_mongo_json_filter_module);

    bson = ctx->bson;

    head = NULL;
    last = NULL;
    out = NULL;

    for (cl = in; cl; cl = cl->next) {

        b = cl->buf;

        if (!ngx_buf_in_memory(b)) {
            ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                          "mongo_json: buffer must be kept in memory");
            return NGX_CHAIN_ERROR;
        }

next:

        switch (ctx->state) {

        case NGX_HTTP_MONGO_BSON_TO_JSON_INIT:
            NGX_HTTP_MONGO_JSON_ENSURE(1);
            *out->last++ = '[';

            ctx->type  = NGX_HTTP_MONGO_BSON_BSON;
            ctx->state = NGX_HTTP_MONGO_BSON_TO_JSON_VALUE;
            goto next;

        case NGX_HTTP_MONGO_BSON_TO_JSON_TYPE:
            NGX_HTTP_MONGO_BSON_READ(ctx->type, 1);

            if (ctx->type == 0x00) {
                ctx->state = NGX_HTTP_MONGO_BSON_TO_JSON_LAST;
                goto next;
            }

            if (!bson->init) {
                NGX_HTTP_MONGO_JSON_ENSURE(1);
                *out->last++ = ',';

            } else {
                bson->init = 0;
            }

            if (!bson->array) {
                NGX_HTTP_MONGO_JSON_ENSURE(1);
                *out->last++ = '"';
            }

            ctx->state = NGX_HTTP_MONGO_BSON_TO_JSON_NAME;
            /* fall through */

        case NGX_HTTP_MONGO_BSON_TO_JSON_NAME:
            for (p = b->pos; p < b->last; p++) {
                if (*p == '\0') {
                    break;
                }
            }

            size = p - b->pos;

            if (size && !bson->array) {
                NGX_HTTP_MONGO_JSON_ENSURE(size);
                out->last = ngx_copy(out->last, b->pos, size);
            }

            if (p == b->last) {
                bson->consumed += size;
                b->pos += size;
                continue;
            }

            size++; /* trailing '\0' */

            if (!bson->array) {
                NGX_HTTP_MONGO_JSON_ENSURE(2);
                *out->last++ = '"';
                *out->last++ = ':';
            }

            bson->consumed += size;
            b->pos += size;

            ctx->state = NGX_HTTP_MONGO_BSON_TO_JSON_VALUE;
            /* fall through */

        case NGX_HTTP_MONGO_BSON_TO_JSON_VALUE:
            switch(ctx->type) {

            case NGX_HTTP_MONGO_BSON_NULL:
                NGX_HTTP_MONGO_JSON_ENSURE(sizeof("null") - 1);
                out->last = ngx_copy(out->last, "null", sizeof("null") - 1);
                break;

            case NGX_HTTP_MONGO_BSON_BOOLEAN:
                NGX_HTTP_MONGO_BSON_READ(val8, 1);

                if (val8 == 0x00) {
                    NGX_HTTP_MONGO_JSON_ENSURE(sizeof("false") - 1);
                    out->last = ngx_copy(out->last, "false",
                                         sizeof("false") - 1);

                } else if (val8 == 0x01) {
                    NGX_HTTP_MONGO_JSON_ENSURE(sizeof("true") - 1);
                    out->last = ngx_copy(out->last, "true", sizeof("true") - 1);

                } else {
                    ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                                  "mongo_json: invalid boolean value: \"%d\"",
                                  val8);
                    return NGX_CHAIN_ERROR;
                }

                break;

            case NGX_HTTP_MONGO_BSON_INT32:
                NGX_HTTP_MONGO_BSON_READ(val32, 1);

                NGX_HTTP_MONGO_JSON_ENSURE(NGX_INT32_LEN);
                out->last = ngx_sprintf(out->last, "%D", val32);
                break;

            case NGX_HTTP_MONGO_BSON_DATETIME:
            case NGX_HTTP_MONGO_BSON_TIMESTAMP:
            case NGX_HTTP_MONGO_BSON_INT64:
                NGX_HTTP_MONGO_BSON_READ(val64, 1);

                NGX_HTTP_MONGO_JSON_ENSURE(NGX_INT64_LEN);
                out->last = ngx_sprintf(out->last, "%L", val64);
                break;

            case NGX_HTTP_MONGO_BSON_DOUBLE:
                NGX_HTTP_MONGO_BSON_READ(vald, 1);

                NGX_HTTP_MONGO_JSON_ENSURE(34); /* ngx_sprintf max is %18.15f */
                out->last = ngx_sprintf(out->last, "%.15f", vald);
                for (p = out->last - 1; p > out->last - 15; p--) {
                     if (*p != '0') {
                         break;
                     }
                }
                out->last = p + 1;
                break;

            case NGX_HTTP_MONGO_BSON_STRING:
            case NGX_HTTP_MONGO_BSON_JAVASCRIPT:
            case NGX_HTTP_MONGO_BSON_SYMBOL:
                if (ctx->copy == 0) {
                    NGX_HTTP_MONGO_BSON_READ(ctx->copy, 1);

                    NGX_HTTP_MONGO_JSON_ENSURE(1);
                    *out->last++ = '"';
                }

                NGX_HTTP_MONGO_BSON_COPY(ngx_copy, 1);

                *(out->last - 1) = '"'; /* rewrite trailing '\0' */
                break;

            case NGX_HTTP_MONGO_BSON_OBJECT_ID:
                if (ctx->copy == 0) {
                    ctx->copy = 12;

                    NGX_HTTP_MONGO_JSON_ENSURE(1);
                    *out->last++ = '"';
                }

                NGX_HTTP_MONGO_BSON_COPY(ngx_hex_dump, 2);

                NGX_HTTP_MONGO_JSON_ENSURE(1);
                *out->last++ = '"';
                break;

            case NGX_HTTP_MONGO_BSON_BINARY:
                if (ctx->copy == 0) {
                    NGX_HTTP_MONGO_BSON_READ(ctx->copy, 1);
                    ctx->skip = 1;

                    NGX_HTTP_MONGO_JSON_ENSURE(1);
                    *out->last++ = '"';
                }

                if (ctx->skip) {
                    if (!ngx_buf_size(b)) {
                        continue;
                    }

                    bson->consumed += sizeof(char);
                    b->pos++;

                    ctx->skip = 0;
                }

                NGX_HTTP_MONGO_BSON_COPY(ngx_hex_dump, 2);

                NGX_HTTP_MONGO_JSON_ENSURE(1);
                *out->last++ = '"';
                break;

            case NGX_HTTP_MONGO_BSON_BSON:
            case NGX_HTTP_MONGO_BSON_ARRAY:
                NGX_HTTP_MONGO_BSON_READ(val32, 0);

                bson = ngx_palloc(r->pool, sizeof(ngx_http_mongo_bson_t));
                if (bson == NULL) {
                    return NGX_CHAIN_ERROR;
                }

                bson->parent = ctx->bson;
                ctx->bson = bson;

                bson->length = val32;
                bson->consumed = sizeof(int32_t);
                bson->init = 1;

                if (ctx->type == NGX_HTTP_MONGO_BSON_BSON) {
                    bson->array = 0;
                    NGX_HTTP_MONGO_JSON_ENSURE(1);
                    *out->last++ = '{';

                } else {
                    bson->array = 1;
                    NGX_HTTP_MONGO_JSON_ENSURE(1);
                    *out->last++ = '[';
                }

                break;

            default:
                ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                              "mongo_json: unsupported BSON type: \"%Xd\"",
                              ctx->type);
                return NGX_CHAIN_ERROR;
            }

            ctx->state = NGX_HTTP_MONGO_BSON_TO_JSON_TYPE;
            goto next;

        case NGX_HTTP_MONGO_BSON_TO_JSON_LAST:
            if (bson->consumed != bson->length) {
                ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                              "mongo_json: BSON processing failed,"
                              " read too %s data, consumed:%d BSON length:%d",
                              bson->consumed > bson->length ? "much" : "little",
                              bson->consumed, bson->length);
                return NGX_CHAIN_ERROR;
            }

            NGX_HTTP_MONGO_JSON_ENSURE(1);
            *out->last++ = bson->array ? ']' : '}';

            if (bson->parent) {
                bson->parent->consumed += bson->consumed;
            } else {
                ctx->length -= bson->consumed;
            }

            bson = bson->parent;
            ctx->bson = bson;

            if (ctx->length) {
                if (bson == NULL) {
                   NGX_HTTP_MONGO_JSON_ENSURE(1);
                   *out->last++ = ',';

                   ctx->type  = NGX_HTTP_MONGO_BSON_BSON;
                   ctx->state = NGX_HTTP_MONGO_BSON_TO_JSON_VALUE;

                } else {
                   ctx->state = NGX_HTTP_MONGO_BSON_TO_JSON_TYPE;
                }

                goto next;
            }

            if (bson || b->pos != b->last) {
                ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                              "mongo_json: BSON processing failed");
                return NGX_CHAIN_ERROR;
            }

            NGX_HTTP_MONGO_JSON_ENSURE(1);
            *out->last++ = ']';

            ctx->state = NGX_HTTP_MONGO_BSON_TO_JSON_DONE;
            break;

        default: /* NGX_HTTP_MONGO_BSON_TO_JSON_DONE */
            ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                          "mongo_json: invalid state");
            return NGX_CHAIN_ERROR;
        }
    }

    return head;
}


static ngx_buf_t *
ngx_http_mongo_json_get_buf(ngx_http_request_t *r, size_t len,
    ngx_chain_t **head, ngx_chain_t **last)
{
    ngx_http_mongo_json_ctx_t  *ctx;
    ngx_chain_t                *cl, **ll;
    ngx_buf_t                  *b;
    size_t                      size;

    ctx = ngx_http_get_module_ctx(r, ngx_http_mongo_json_filter_module);

    size = ngx_min(ngx_max(len, 4 * ngx_pagesize),
                   (size_t) (32 + 2 * ctx->length));

    for (ll = &ctx->free, cl = ctx->free; cl; ll = &cl->next, cl = cl->next) {
        if (cl->buf->end - cl->buf->start >= (off_t) size) {
            *ll = cl->next;
            cl->next = NULL;
            goto found;
        }
    }

    cl = ngx_chain_get_free_buf(r->pool, &ctx->free);
    if (cl == NULL) {
        return NULL;
    }

    if (cl->buf->start == NULL) {
        b = cl->buf;

        b->start = ngx_palloc(r->pool, size);
        if (b->start == NULL) {
            return NULL;
        }

        b->pos = b->start;
        b->last = b->start;
        b->end = b->last + size;

        b->tag = (ngx_buf_tag_t) &ngx_http_mongo_json_filter_module;

        b->temporary = 1;
    }

found:

    if (*last) {
        (*last)->next = cl;

    } else {
        *head = cl;
    }

    *last = cl;

    return cl->buf;
}


static char *
ngx_http_mongo_json(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_http_mongo_json_filter_active = 1;

    return ngx_conf_set_flag_slot(cf, cmd, conf);
}


static ngx_int_t
ngx_http_mongo_json_filter_reset(ngx_conf_t *cf)
{
    ngx_http_mongo_json_filter_active = 0;

    return NGX_OK;
}


static ngx_int_t
ngx_http_mongo_json_filter_init(ngx_conf_t *cf)
{
    if (ngx_http_mongo_json_filter_active) {
        ngx_http_next_header_filter = ngx_http_top_header_filter;
        ngx_http_top_header_filter = ngx_http_mongo_json_header_filter;

        ngx_http_next_body_filter = ngx_http_top_body_filter;
        ngx_http_top_body_filter = ngx_http_mongo_json_body_filter;
    }

    return NGX_OK;
}


static void *
ngx_http_mongo_json_filter_create_conf(ngx_conf_t *cf)
{
    ngx_http_mongo_json_loc_conf_t  *conf;

    conf = ngx_pcalloc(cf->pool, sizeof(ngx_http_mongo_json_loc_conf_t));
    if (conf == NULL) {
        return NULL;
    }

    conf->enable = NGX_CONF_UNSET;

    return conf;
}


static char *
ngx_http_mongo_json_filter_merge_conf(ngx_conf_t *cf, void *parent, void *child)
{
    ngx_http_mongo_json_loc_conf_t  *prev = parent;
    ngx_http_mongo_json_loc_conf_t  *conf = child;

    ngx_conf_merge_value(conf->enable, prev->enable, 0);

    return NGX_CONF_OK;
}
