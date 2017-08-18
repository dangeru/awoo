# awoo
Awoo is a textboard engine based on the Sinatra micro-framework

You'll need the `sinatra`, `mysql2` and `sanitize` gems, as well as a mysql server set up using the `create.sql` file.

Running `sudo make install` will make a user named `awoo`, copy `src` to `/opt/awoo`, set up your database and put a service file in /etc/systemd/system so you can run `sudo systemctl start awoo` to start the server on port 8033

## Todo List

- Moderation for bans
	- prefetcher
- Moderation for moving posts between boards
	- prefetcher
- Make `/ip/:addr` prettier
	- add ban duration
- Rules for each board
	- prefetcher already wrote the routes and views
	- Mystery is working on the text
- Multiple levels of moderation - janitors shouldn't be able to ban people
- images on burg
