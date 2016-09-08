SHELL := bash

DB_NAME ?= ql-test.db

BENCHTIME ?= 5s

export DB_NAME

require-client:
	@if [ -z "$$(which ql)" ]; then \
		echo 'Missing "ql" command. Please install ql and try again.' && \
		exit 1; \
	fi

generate:
	go generate && \
	go get -d -t -v ./...

reset-db: require-client
	rm -f $(DB_NAME)

bench: reset-db generate
	go test -v -test.bench=. -test.benchtime=$(BENCHTIME) -benchmem
