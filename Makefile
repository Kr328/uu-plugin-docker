.PHONY: clean

all: with

install: with
	install -D -m 0644 -o root -g root scoped-uuplugin.service /usr/lib/systemd/system/scoped-uuplugin.service
	install -D -m 0700 -o root -g root daemon.sh /usr/lib/scoped-uuplugin/daemon.sh
	install -D -m 4755 -o root -g root with /usr/bin/with-uuplugin

uninstall:
	rm -rf /usr/lib/systemd/system/scoped-uuplugin.service
	rm -rf /usr/lib/scoped-uuplugin
	rm -rf /usr/bin/with-uuplugin

clean:
	rm -rf ./with

with: with.c
	clang with.c -o ./with
