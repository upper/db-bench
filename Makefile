SHELL := /bin/bash

all: clean bench

clean:
	rm -rf results

bench:
	mkdir -p results && \
	for ADAPTER in postgresql mysql sqlite ql mongo; do \
		time ($(MAKE) bench -C $$ADAPTER | tee results/$$ADAPTER.txt); \
	done
