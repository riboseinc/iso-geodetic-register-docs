#!make
SHELL := /bin/bash

RELATON_COLLECTION_ORG  := "ISO Geodetic Registry Registration Authority"
RELATON_COLLECTION_NAME := "ISO Geodetic Registry Documentation"

comma := ,
empty :=
space := $(empty) $(empty)

SRC  := $(wildcard sources/*/document.adoc)
INPUT_XML  := $(patsubst %.adoc,%.xml,$(SRC))
OUTPUT_XML  := $(patsubst sources/%,documents/%,$(patsubst %/document.adoc,%.xml,$(SRC)))
OUTPUT_HTML := $(patsubst %.xml,%.html,$(OUTPUT_XML))
FORMATS := xml html

COMPILE_CMD_LOCAL := bundle exec metanorma -R $${FILENAME//adoc/rxl} $$FILENAME
COMPILE_CMD_DOCKER := docker run -v "$$(pwd)":/metanorma/ ribose/metanorma "metanorma $${FILENAME//adoc/rxl}  $$FILENAME"

ifdef METANORMA_DOCKER
  COMPILE_CMD := echo "Compiling via docker..."; $(COMPILE_CMD_DOCKER)
else
  COMPILE_CMD := echo "Compiling locally..."; $(COMPILE_CMD_LOCAL)
endif

_OUT_FILES := $(foreach FORMAT,$(FORMATS),$(shell echo $(FORMAT) | tr '[:lower:]' '[:upper:]'))
OUT_FILES  := $(foreach F,$(_OUT_FILES),$($F))

all: documents.html

documents:
	mkdir -p $@

documents/%.xml: documents sources/%/document.xml
	mv sources/$*/document.xml documents/$*.xml; \
	mv sources/$*/document.doc documents/$*.doc; \
	mv sources/$*/document.html documents/$*.html; \
	mv sources/$*/document.rxl documents/$*.rxl; \
	mv sources/$*/document.alt.html documents/$*.alt.html;

%.xml %.html:	%.adoc | bundle
	FILENAME=$^; \
	${COMPILE_CMD}

documents.rxl: $(OUTPUT_XML)
	bundle exec relaton concatenate \
	  -t $(RELATON_COLLECTION_NAME) \
		-g $(RELATON_COLLECTION_ORG) \
		documents $@

documents.html: documents.rxl
	bundle exec relaton xml2html documents.rxl

%.adoc:

define FORMAT_TASKS
OUT_FILES-$(FORMAT) := $($(shell echo $(FORMAT) | tr '[:lower:]' '[:upper:]'))

open-$(FORMAT):
	open $$(OUT_FILES-$(FORMAT))

clean-$(FORMAT):
	rm -f $$(OUT_FILES-$(FORMAT))

$(FORMAT): clean-$(FORMAT) $$(OUT_FILES-$(FORMAT))

.PHONY: clean-$(FORMAT)

endef

$(foreach FORMAT,$(FORMATS),$(eval $(FORMAT_TASKS)))

open: open-html

clean:
	rm -rf documents published *_images sources/*.{rxl,xml,html,pdf}

bundle:
	if [ "x" == "${METANORMA_DOCKER}x" ]; then bundle; fi

.PHONY: bundle all open clean

#
# Watch-related jobs
#

.PHONY: watch serve watch-serve

NODE_BINS          := onchange live-serve run-p
NODE_BIN_DIR       := node_modules/.bin
NODE_PACKAGE_PATHS := $(foreach PACKAGE_NAME,$(NODE_BINS),$(NODE_BIN_DIR)/$(PACKAGE_NAME))

$(NODE_PACKAGE_PATHS): package.json
	npm i

watch: $(NODE_BIN_DIR)/onchange
	make all
	$< $(ALL_SRC) -- make all

define WATCH_TASKS
watch-$(FORMAT): $(NODE_BIN_DIR)/onchange
	make $(FORMAT)
	$$< $$(SRC_$(FORMAT)) -- make $(FORMAT)

.PHONY: watch-$(FORMAT)
endef

$(foreach FORMAT,$(FORMATS),$(eval $(WATCH_TASKS)))

serve: $(NODE_BIN_DIR)/live-server revealjs-css reveal.js images
	export PORT=$${PORT:-8123} ; \
	port=$${PORT} ; \
	for html in $(HTML); do \
		$< --entry-file=$$html --port=$${port} --ignore="*.html,*.xml,Makefile,Gemfile.*,package.*.json" --wait=1000 & \
		port=$$(( port++ )) ;\
	done

watch-serve: $(NODE_BIN_DIR)/run-p
	$< watch serve

#
# Deploy jobs
#
publish: published
published: documents.html
	mkdir -p published && \
	cp -a documents $@/ && \
	cp $< published/index.html

.PHONY: publish
