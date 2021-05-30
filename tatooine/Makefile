SHELL=/usr/bin/zsh

all:  check-sudo clean-conda-cache


.PHONY: all


check-sudo:
	@if (( EUID!=0 )) then; echo 'Run this with sudo!' && exit 1; fi

.ONESHELL:
clean-conda-cache: etc/systemd/system/clean-conda-cache.service etc/systemd/system/clean-conda-cache.timer
	@for file in $?
	do
		ln -s $$PWD/$$file /$${file%/*};
	done

clean-clean-conda-cache:
	rm /etc/systemd/system/clean-conda-cache.service


clean: clean-clean-conda-cache
