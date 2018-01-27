all:
	gcc -lcurl -o test test.c
clean:
	rm test
regenerate_posts:
	mysql -u awoo --password=awoo awoo -e "SELECT post_id FROM posts" -B | grep -v post_id > posts
.PHONY: all clean regenerate_posts
