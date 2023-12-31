all: docker-build

# docker name to create
IMAGE_NAME:=pandoc-pretty-pdf
VERSION:=0.9
PATCH:=1

NAMESPACE:=towi
LOCAL:=$(NAMESPACE)/$(IMAGE_NAME)
LOCAL_LATEST:=$(LOCAL):latest
LOCAL_TAG:=$(LOCAL):$(VERSION)
REGISTRY:=ghcr.io
LATEST:=$(REGISTRY)/$(NAMESPACE)/$(IMAGE_NAME):latest
TAG:=$(REGISTRY)/$(NAMESPACE)/$(IMAGE_NAME):$(VERSION)


docker-login: .$(REGISTRY)-secret.txt
	cat .$(REGISTRY)-secret.txt | \
		docker login $(REGISTRY) -u USERNAME --password-stdin

# just build it for local use
docker-build: Dockerfile app/plantuml
	docker build --build-arg PANDOC_PRETTY_PDF=$(TAG) -t $(LOCAL_LATEST) .

# local tagging
docker-tag:
	docker tag $(LOCAL_LATEST) $(LOCAL_TAG)
	docker tag $(LOCAL_LATEST) $(LOCAL_TAG).$(PATCH)

# remote tagging and uploading
docker-push: docker-tag
	docker tag $(LOCAL_LATEST) $(LATEST)
	docker tag $(LOCAL_LATEST) $(TAG)
	docker tag $(LOCAL_LATEST) $(TAG).$(PATCH)
	docker push $(LATEST)
	docker push $(TAG)
	docker push $(TAG).$(PATCH)

# play around inside
docker-sh:
	docker run \
			--rm -it \
		$(LOCAL_LATEST) sh

docker-user-sh:
	docker run \
			--rm -it \
			--volume $(shell pwd):/data \
		$(LOCAL_LATEST) sh

# check if it works
docker-check:
	@echo "====================== Testing Plantuml ============================"
	docker run --rm $(LOCAL_LATEST) plantuml -h
	@echo "====================== Testing Pandoc ============================"
	docker run --rm $(LOCAL_LATEST) pandoc -h
	@echo "====================== Testing Plantuml Filter for Pandoc ============================"
	@echo "   (not a good test yet. please improve it)"
	-echo '{"meta":{},"blocks":[]}' | docker run --rm -i $(LOCAL_LATEST) python3 -m pandoc_plantuml_filter && echo "\nOK."
	@echo "====================== Testing Eisvogel Template ============================"
	$(MAKE) -B eisvogel_test

eisvogel_test: eisvogel_test.pdf

%.pdf: %.md
	docker run \
			--rm \
			--volume $(shell pwd):/data \
			--user $(shell id -u):$(shell id -g) \
		$(LOCAL_LATEST) \
			pandoc-pretty-pdf \
		-o $@ \
		$<
		@echo "___ result file: ___"
		ls -l $@

# check with image from hub
hub-check: eisvogel_test-hub.pdf
eisvogel_test-hub.pdf: eisvogel_test.md
	docker run \
			--rm \
			--volume $(shell pwd):/data \
			--user $(shell id -u):$(shell id -g) \
		$(LATEST) \
			pandoc-pretty-pdf \
		-o $@ \
		$<
		@echo "___ result file: ___"
		ls -l $@

#####

clean:
	$(RM) eisvogel_test.pdf eisvogel_test-hub.pdf
