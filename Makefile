install:
	useradd awoo ||:
	usermod -a -G awoo awoo
	mkdir -p /opt/awoo/
	cp -rv src /opt/awoo/src
	chown -R awoo:awoo /opt/awoo
	cp awoo.service /etc/systemd/system/
	systemctl daemon-reload
	mysql -u root < create.sql
test:
	ruby src/test/generic_test.rb
.PHONY: install test
