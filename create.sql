DROP DATABASE test;
CREATE DATABASE test;
GRANT ALL ON test.* TO awoo@'%' IDENTIFIED BY 'awoo';
USE test;
CREATE TABLE posts (
	board TEXT NOT NULL,
	post_id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
	parent INTEGER DEFAULT NULL,
	content TEXT NOT NULL,
	ip TEXT DEFAULT NULL,
	is_locked BOOL DEFAULT FALSE,
	date_posted TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	title TEXT NOT NULL DEFAULT ''
);

INSERT INTO posts (board, post_id, parent, content) VALUES
	('test', 0, 0, 'This is an op'),
	('test', 1, 0, 'This is a reply to post number zero'),
	('test', 2, 2, 'This is another op'),
	('test', 3, 3, 'This is a third OP with four replies'),
	('test', 4, 3, 'This is reply number 1 to the third OP'),
	('test', 5, 3, 'This is reply number 2 to the third OP'),
	('test', 6, 3, 'This is reply number 3 to the third OP'),
	('test', 7, 3, 'This is reply number 4 to the third OP');

UPDATE posts SET title = 'Title for ' || content WHERE post_id = parent;

