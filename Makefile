TARGETS := $(shell cat $(realpath $(lastword $(MAKEFILE_LIST))) | grep "^[a-z]*:" | awk '{ print $$1; }' | sed 's/://g' | grep -vE 'all|help' | paste -sd "|" -)
NAME := $(subst docker-,,$(shell basename $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))))
IMAGE := codeworksio/$(NAME)

all: help

help:
	echo
	echo "Usage:"
	echo
	echo "    make $(TARGETS)"
	echo

build:
	docker build \
		--build-arg IMAGE=$(IMAGE) \
		--build-arg BUILD_DATE=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ") \
		--build-arg VERSION=$(shell cat VERSION) \
		--build-arg VCS_REF=$(shell git rev-parse --short HEAD) \
		--build-arg VCS_URL=$(shell git config --get remote.origin.url) \
		--tag $(IMAGE):$(shell cat VERSION) \
		--rm .
	docker tag $(IMAGE):$(shell cat VERSION) $(IMAGE):latest
	docker rmi --force $$(docker images | grep "<none>" | awk '{ print $$3 }') 2> /dev/null ||:

start:
	docker run --detach --interactive --tty \
		--name $(NAME) \
		--hostname $(NAME) \
		--env "INIT_DEBUG=true" \
		$(IMAGE)

stop:
	docker stop $(NAME) > /dev/null 2>&1 ||:
	docker rm $(NAME) > /dev/null 2>&1 ||:

log:
	docker logs --follow $(NAME)

test:
	docker run --detach --interactive --tty --name speedtest codeworksio/speedtest
	sleep 60
	docker logs speedtest | grep 'speedtest|INFO|ping'

bash:
	docker exec --interactive --tty \
		--user root \
		$(NAME) \
		/bin/bash --login ||:

clean:
	docker rmi $(IMAGE):$(shell cat VERSION) > /dev/null 2>&1 ||:
	docker rmi $(IMAGE):latest > /dev/null 2>&1 ||:

push:
	docker push $(IMAGE):$(shell cat VERSION)
	docker push $(IMAGE):latest
	sleep 10
	curl --request POST "https://hooks.microbadger.com/images/$(IMAGE)/rvoIiisHD3LYzsFGoCfydkrRFC0="

.SILENT:
