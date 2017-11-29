# Parameters
FUNCTION_NAME ?= cfnKmsDecrypt
S3_BUCKET ?= 334274607422-cfn-lambda
AWS_DEFAULT_REGION ?= us-east-1
ENV ?= nil

include Makefile.settings
-include .env/$(ENV)

.PHONY: clean build publish

build: clean
	@ ${INFO} "Building $(FUNCTION_NAME).zip..."
	@ rm -rf src/vendor
	@ cd src && pip install -t vendor/ -r requirements.txt --upgrade
	@ mkdir -p build
	@ cd src && zip -9 -r ../build/$(FUNCTION_NAME).zip * -x *.pyc
	@ ${INFO} "Built build/$(FUNCTION_NAME).zip"

publish: build
	@ ${INFO} "Publishing $(FUNCTION_NAME).zip to s3://$(S3_BUCKET)..."
	@ aws s3 cp --quiet build/$(FUNCTION_NAME).zip s3://$(S3_BUCKET)
	@ ${INFO} "Published to S3 URL: https://s3-$(AWS_DEFAULT_REGION).amazonaws.com/$(S3_BUCKET)/$(FUNCTION_NAME).zip"
	@ ${INFO} "S3 Object Version: $(S3_OBJECT_VERSION)"

clean:
	@ rm -rf src/*.pyc src/vendor build
	@ ${INFO} "Removed all distributions"
