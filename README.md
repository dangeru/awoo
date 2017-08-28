# awoo
Awoo is a textboard engine based on the Sinatra micro-framework

You'll need the `sinatra`, `mysql2` and `sanitize` gems, as well as a mysql server set up using the `create.sql` file.

Running `sudo make install` will make a user named `awoo`, copy `src` to `/opt/awoo`, set up your database and put a service file in /etc/systemd/system so you can run `sudo systemctl start awoo` to start the server on port 8080

## Tests

To run tests, you'll need the server already running, you can adjust the host and port in `src/test/generic_test.rb` but it defaults to `127.0.0.1:8080`. It will use the /test board and expects three janitors, `test`, who moderates /test and is not a supermaidmin, `test2`, who moderates /test and IS a supermaidmin, and `test3`, who does not moderate test

## Todo List

- Make `/ip/:addr` prettier
	- maybe let people select more than one board at a time to ban the IP from?
- Rules for each board
	- put in the text that Mystery wrote
	- not assigned (we could just assign it to Mystery after the site launches)
