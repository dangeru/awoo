#define obstack_chunk_alloc malloc
#define obstack_chunk_free free
#include <sys/types.h>
#include <curl/curl.h>
#include <inttypes.h>
#include <stdbool.h>
#include <obstack.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
int main() {
	FILE* fd = fopen("posts", "r");
	struct obstack stack;
	obstack_init(&stack);
	unsigned long* item = obstack_alloc(&stack, 0);
	while (true) {
		char* line = NULL;
		size_t length = 0;
		int ret = getline(&line, &length, fd);
		if (ret == -1) {
			free(line);
			break;
		}
		unsigned long post_id = strtoul(line, NULL, 10);
		printf("Read %lu\n", post_id);
		free(line);
		obstack_grow(&stack, &post_id, sizeof(unsigned long));
	}
	size_t max_size = obstack_object_size(&stack);
	int max_i = max_size / sizeof(unsigned long);
	item = obstack_finish(&stack);
	if (fork()) if(fork()) fork(); // split into 4 processes
	char* buf = alloca(100);
	CURL* c = curl_easy_init();
	for (size_t i = 0; i < max_i; i++) {
		curl_easy_reset(c);
 		snprintf(buf, 100, "http://localhost:8080/api/v2/thread/%d/metadata", item[i]);
		curl_easy_setopt(c, CURLOPT_URL, buf);
		curl_easy_perform(c);
	}
	obstack_free(&stack, item);
}
