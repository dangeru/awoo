# awoo
Awoo is a textboard engine based on the Sinatra micro-framework

You'll need the `sinatra`, `mysql2`, `sanitize` and `rerun` gems, as well as a mysql server set up using the `create.sql` file.

Running `sudo make install` will make a user named `awoo`, copy `src` to `/opt/awoo`, set up your database and put a service file in /etc/systemd/system so you can run `sudo systemctl start awoo` to start the server on port 8080

## Tests

To run tests, you'll need the server already running, you can adjust the host and port in `src/test/generic_test.rb` but it defaults to `127.0.0.1:8080`. It will use the /test board and expects three janitors, `test`, who moderates /test and is not a supermaidmin, `test2`, who moderates /test and IS a supermaidmin, and `test3`, who does not moderate test

If you want to test against a production environment but are worried about security, you can change their passwords, the values used when logging in are pulled from config.json

The tests depend on the `http-cookie` gem

![awoo in use](/meta/awoo.PNG)

## Todo List

- On `/ip/:addr`, maybe let people select more than one board at a time to ban the IP from?
