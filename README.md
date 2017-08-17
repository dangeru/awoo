# awoo
Awoo is a textboard engine based on the Sinatra micro-framework

You'll need the `sinatra`, `mysql2` and `sanitize` gems, as well as a mysql server set up using the `create.sql` file.

Running `sudo make install` will make a user named `awoo`, copy `src` to `/opt/awoo`, set up your database and put a service file in /etc/systemd/system so you can run `sudo systemctl start awoo` to start the server on port 8033

## Todo List

- Moderation for deleting posts
- Moderation for bans
- Moderation for moving posts between boards (EASY!)
- Moderation for seeing all posts by an IP (`/ip/:addr`)
- Automatic locking of posts that are beyond a certain age
	- Scheduled (cron-like) task?
- Rules for each board
