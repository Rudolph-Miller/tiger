all: build test

build: lex
	clang -o bin/tiger main.c util.c errormsg.c lex.yy.c

lex:
	lex tiger.lex

test:
	bin/tiger test.tig
