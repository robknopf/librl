#ifndef FETCH_URL_STUB_H
#define FETCH_URL_STUB_H

#include <stddef.h>

void fetch_url_stub_reset(void);
void fetch_url_stub_set_response(int code, const char *data, size_t size);
void fetch_url_stub_enqueue_response(int code, const char *data, size_t size);
int fetch_url_stub_get_call_count(void);
const char *fetch_url_stub_get_last_host(void);
const char *fetch_url_stub_get_last_path(void);

#endif // FETCH_URL_STUB_H
