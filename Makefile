.PHONY : all test dependencies clean veryclean js css font

NODE_MODULES := node_modules/

all: js css test
js: dist/sequence-diagram-min.js dist/sequence-diagram-raphael-min.js dist/sequence-diagram-snap-min.js
css: dist/sequence-diagram-min.css font
font: dist/danielbd.woff2 dist/danielbd.woff

node_modules: package.json
	#
	# NPM update needed.
	#
	npm ci
	touch $@

dependencies: node_modules

clean:
	-rm build/*
	-git checkout -- dist

veryclean: clean
	-rm -rf node_modules

test: dependencies dist/sequence-diagram-min.js


	# Test the un-minifed file (with lodash)
	npx qunit \
		-c dist/sequence-diagram.js \
		-t test/*-tests.js \
		-d test/*-mock.js $(NODE_MODULES)/lodash/lodash.min.js

	# Test the minifed file (with lodash)
	npx qunit \
		-c dist/sequence-diagram-min.js \
		-t test/*-tests.js \
		-d test/*-mock.js $(NODE_MODULES)/lodash/lodash.min.js

build/grammar.js: src/grammar.jison
	mkdir -p build
	npx jison $< -o $@.tmp

	# After building the grammar, run it through the uglifyjs to fix some non-strict issues.
	# Until https://github.com/zaach/jison/issues/285 is fixed, we must do this to create valid non-minified code.
	npx uglifyjs \
		$@.tmp -o $@ \
		--comments all --compress --beautify

	rm $@.tmp

# Compile the grammar
build/diagram-grammar.js: src/diagram.js build/grammar.js
	npx preprocess $< . > $@

# Combine all javascript files together (Raphael and Snap.svg)
dist/sequence-diagram.js: src/main.js build/diagram-grammar.js src/jquery-plugin.js src/sequence-diagram.js src/theme.js src/theme-snap.js src/theme-raphael.js fonts/daniel/daniel_700.font.js
	mkdir -p dist
	npx preprocess $< . -SNAP=true -RAPHAEL=true  > $@

# Combine just Raphael theme
dist/sequence-diagram-raphael.js: src/main.js build/diagram-grammar.js src/jquery-plugin.js src/sequence-diagram.js src/theme.js src/theme-raphael.js fonts/daniel/daniel_700.font.js
	npx preprocess $< . -RAPHAEL=true > $@

# Combine just Snap.svg theme
dist/sequence-diagram-snap.js: src/main.js build/diagram-grammar.js src/jquery-plugin.js src/sequence-diagram.js src/theme.js src/theme-snap.js
	npx preprocess $< . -SNAP=true > $@

dist/sequence-diagram.css: src/sequence-diagram.css
	cp $< $@

# Minify the CSS
dist/sequence-diagram-min.css: dist/sequence-diagram.css
	npx minify --output $@ $<

# Move some fonts TODO optomise the fonts
dist/%.woff: fonts/daniel/%.woff
	cp $< $@

dist/%.woff2: fonts/daniel/%.woff2
	cp $< $@

# Minify the final javascript
dist/%-min.js dist/%-min.js.map: dist/%.js

	#
	# Please ignore the warnings below (these are in combined js code)
	#
	npx uglifyjs \
		$< -o $@ \
		--compress --comments --lint \
		--source-map $@.map \
		--source-map-url `basename $<`
