.PHONY: monad-builder clone-monad-bft

MONAD_BUILDER_REF ?= v0.14.1
MONAD_BFT_REF ?= master

all: monad-builder clone-monad-bft

monad-builder:
	curl -fsSL https://raw.githubusercontent.com/category-labs/monad-bft/$(MONAD_BUILDER_REF)/docker/builder/Dockerfile \
		| docker build -t monad-builder:latest -

# Recommendation:
# fetch only the editable code to maintain small docker context
# and avoid fetching all submodule dependencies
# This allows fast context upload to the docker host
clone-monad-bft:
	git clone --depth 1 --branch $(MONAD_BFT_REF) https://github.com/category-labs/monad-bft.git
	git -C monad-bft submodule update --init --depth 1 monad-execution
