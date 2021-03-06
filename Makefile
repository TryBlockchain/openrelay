PACKAGE  = github.com/notegio/openrelay
GOPATH   = $(CURDIR)/.gopath
BASE     = $(GOPATH)/src/$(PACKAGE)
GOSTATIC = go build -a -installsuffix cgo -ldflags '-extldflags "-static"'


all: bin nodesetup truffleCompile

$(BASE):
	@mkdir -p $(dir $@)
	@ln -sf $(CURDIR) $@

clean:
	rm -rf bin/ .gopath/

nodesetup:
	cd $(BASE)/js ; npm install

bin/delayrelay: $(BASE) cmd/delayrelay/main.go
	cd $(BASE) &&  CGO_ENABLED=0 $(GOSTATIC) -o bin/delayrelay cmd/delayrelay/main.go

bin/fundcheckrelay: $(BASE) cmd/fundcheckrelay/main.go
	cd $(BASE) && $(GOSTATIC) -o bin/fundcheckrelay cmd/fundcheckrelay/main.go

bin/getbalance: $(BASE) cmd/getbalance/main.go
	cd $(BASE) && $(GOSTATIC) -o bin/getbalance cmd/getbalance/main.go

bin/ingest: $(BASE) cmd/ingest/main.go
	cd $(BASE) && $(GOSTATIC) -o bin/ingest cmd/ingest/main.go

bin/initialize: $(BASE) cmd/initialize/main.go
	cd $(BASE) && CGO_ENABLED=0 $(GOSTATIC) -o bin/initialize cmd/initialize/main.go

bin/simplerelay: $(BASE) cmd/simplerelay/main.go
	cd $(BASE) && CGO_ENABLED=0 $(GOSTATIC) -o bin/simplerelay cmd/simplerelay/main.go

bin/validateorder: $(BASE) cmd/validateorder/main.go
	cd $(BASE) && $(GOSTATIC) -o bin/validateorder cmd/validateorder/main.go

bin/fillupdate: $(BASE) cmd/fillupdate/main.go
	cd $(BASE) && $(GOSTATIC) -o bin/fillupdate cmd/fillupdate/main.go

bin: bin/delayrelay bin/fundcheckrelay bin/getbalance bin/ingest bin/initialize bin/simplerelay bin/validateorder bin/fillupdate

truffleCompile:
	cd $(BASE)/js ; node_modules/.bin/truffle compile

testredis:
	mkdir -p $(BASE)/tmp
	docker run -d -p 6379:6379 redis  > $(BASE)/tmp/redis.containerid

testdynamo:
	mkdir -p $(BASE)/tmp
	docker run -d -p 8000:8000 cnadiminti/dynamodb-local > $(BASE)/tmp/dynamo.containerid

py/.env:
	virtualenv -p python3.6 $(BASE)/py/.env
	$(BASE)/py/.env/bin/pip install -r $(BASE)/py/requirements/api.txt
	$(BASE)/py/.env/bin/pip install -r $(BASE)/py/requirements/indexer.txt
	$(BASE)/py/.env/bin/pip install nose

gotest: testredis
	cd $(BASE)/funds && go test
	cd $(BASE)/channels &&  REDIS_URL=localhost:6379 go test
	cd $(BASE)/accounts &&  REDIS_URL=localhost:6379 go test
	cd $(BASE)/affiliates &&  REDIS_URL=localhost:6379 go test
	cd $(BASE)/types && go test
	cd $(BASE)/ingest && go test
	docker stop `cat $(BASE)/tmp/redis.containerid`
	docker rm `cat $(BASE)/tmp/redis.containerid`

pytest: testdynamo
	cd $(BASE)/py && DYNAMODB_HOST="http://localhost:8000" $(BASE)/py/.env/bin/nosetests
	docker stop `cat $(BASE)/tmp/dynamo.containerid`
	docker rm `cat $(BASE)/tmp/dynamo.containerid`

jstest: testredis
	cd $(BASE)/js && REDIS_URL=localhost:6379 node_modules/.bin/mocha

test: jstest gotest pytest
