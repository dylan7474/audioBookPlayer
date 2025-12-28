.PHONY: build clean

build:
	mkdir -p dist
	cp index.html dist/index.html

clean:
	rm -rf dist
