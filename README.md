# awoo
Awoo is a textboard engine based on the Sinatra micro-framework

You'll need the `sinatra`, `mysql2` and `sanitize` gems, as well as a mysql server set up using the `create.sql` file.

Running `sudo make install` will make a user named `awoo`, copy `src` to `/opt/awoo`, set up your database and put a service file in /etc/systemd/system so you can run `sudo systemctl start awoo` to start the server on port 8033

## Todo List

- Moderation for bans
	- prefetcher
- Make `/move/:post` prettier
	- prefetcher
	- should janitors move posts only in between the boards they moderate?
	- currently the frontend only lets them move posts to boards they moderate, but the backend lets them move it to any board
		- there's already an `is_moderator` function that takes a board, would have to select the board from the passed post id and check that too
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
