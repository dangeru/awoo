# awoo
Awoo is a textboard engine based on the Sinatra micro-framework

You'll need the `sinatra`, `mysql2` and `sanitize` gems, as well as a mysql server set up using the `create.sql` file.

Running `sudo make install` will make a user named `awoo`, copy `src` to `/opt/awoo`, set up your database and put a service file in /etc/systemd/system so you can run `sudo systemctl start awoo` to start the server on port 8033

## Todo List

- Moderation for bans
	- prefetcher
- Make `/move/:post` prettier
	- prefetcher
	- right now both the frontend and backend let janitors move threads to/from ANY board whether they moderate it or not
- Make `/ip/:addr` prettier
	- prefetcher
	- partially done, now links directly to reply in OP, and IP notes work
	- maybe let people select more than one board at a time to ban the IP from?
	- add ban duration
- Stickied posts
	- prefetcher
	- Add an icon for them in `board.erb`
	- Add buttons for moderators to sticky/unsticky posts
- Rules for each board
	- prefetcher already wrote the routes and views
	- Mystery is working on the text
- images on burg
	- not assigned
