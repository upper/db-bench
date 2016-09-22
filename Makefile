all: clean bench

clean:
	rm -rf results

bench:
	mkdir -p results && \
	for ADAPTER in postgresql mysql sqlite ql mongo; do \
		$(MAKE) bench -C $$ADAPTER > results/$$ADAPTER.txt; \
	done
