# CloudFormation KMS Decryption Function

This repository defines the Lamdba function `cfnKmsDecrypt`.

This function supports decryption of KMS encrypted secrets that need to be passed to CloudFormation resources securely.

## Build Instructions

Any dependencies need to defined in `src/requirements.txt`.  Note that you do not need to include `boto3`, as this is provided by AWS for Python Lambda functions.

To build the function and its dependencies:

`make build`

This will create the necessary dependencies in the `src` folder and create a ZIP package in the `target` folder.  This file is suitable for upload to the AWS Lambda service to create a Lambda function.

```
$ make build
=> Building cfnKmsDecrypt.zip...
Collecting cfn_lambda_handler (from -r requirements.txt (line 1))
Installing collected packages: cfn-lambda-handler
Successfully installed cfn-lambda-handler-1.0.2
updating: cfn_lambda_handler-1.0.2.dist-info/ (stored 0%)
updating: cfn_lambda_handler.py (deflated 67%)
updating: cfn_lambda_handler.pyc (deflated 62%)
updating: requirements.txt (stored 0%)
updating: setup.cfg (stored 0%)
updating: stack_resources.py (deflated 63%)
=> Built target/cfnKmsDecrypt.zip
```

### Function Naming

The default name for this function is `cfnKmsDecrypt` and the corresponding ZIP package that is generated is called `cfnKmsDecrypt.zip`.

If you want to change the function name, set the `FUNCTION_NAME` environment variable to the custom function name.

## Publishing the Function

When you publish the function, you are simply copying the built ZIP package to an S3 bucket.  Before you can do this, you must ensure your environment is configured correctly with appropriate AWS credentials.

To deploy the built ZIP package:

`make publish`

This will upload the built ZIP package to an appropriate S3 bucket as defined via the `S3_BUCKET` Makefile/Environment variable.

### Publish Example

```
$ export AWS_PROFILE=caintake-admin
$ make publish
=> Publishing cfnKmsDecrypt.zip to s3://429614120872-cfn-lambda...
=> Published to S3 URL: https://s3-us-west-2.amazonaws.com/429614120872-cfn-lambda/cfnKmsDecrypt.zip
=> S3 Object Version: 86jHvErMu.CpTjqBvSlJabgr22pYGa9S
```

## CloudFormation Usage

This function is designed to be called from a CloudFormation template as a custom resource.

The custom resource Lambda function must first be created with the following requirements:

- The Lambda handler must be configured as `cfn_kms_decrypt.handler`
- The Lambda runtime must be `python2.7`
- The Lambda function must be published to an S3 bucket, with a known S3 object key and object version
- The KMS key used for encryption must be exist before the CloudFormation stack is used (i.e. it cannot be created as part of the same stack)
- The Lambda function must have KMS decrypt privileges for the KMS key used to encrypt the credentials
- The Lambda function must have privileges to manage its own log group for logging

The following CloudFormation snippet demonstrates creating an AWS Lambda function with an example IAM role.

```
Resources:
  ...
  ...
  KMSDecrypter:
    Type: "AWS::Lambda::Function"
    Properties:
      Description:
        Fn::Sub: "${AWS::StackName} KMS Decrypter"
      Handler: "cfn_kms_decrypt.handler"
      MemorySize: 128
      Runtime: "python2.7"
      Timeout: 300
      Role:
        Fn::Sub: ${KMSDecrypterRole.Arn}
      FunctionName:
        Fn::Sub: "${AWS::StackName}-cfnKmsDecrypt"
      Code:
        S3Bucket:
          Fn::Sub: "${AWS::AccountId}-cfn-lambda"
        S3Key: "cfnKmsDecrypt.zip"
        S3ObjectVersion: "86jHvErMu.CpTjqBvSlJabgr22pYGa9S"
  KMSDecrypterRole:
    Type: "AWS::IAM::Role"
    Properties:
      Path: "/"
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
        - Effect: "Allow"
          Principal: {"Service": "lambda.amazonaws.com"}
          Action: [ "sts:AssumeRole" ]
      Policies:
      - PolicyName: "KMSDecrypterPolicy"
        PolicyDocument:
          Version: "2012-10-17"
          Statement:
          - Sid: "Decrypt"
            Effect: "Allow"
            Action:
            - "kms:Decrypt"
            - "kms:DescribeKey"
            Resource:
              Fn::Sub: "arn:aws:kms:${AWS::Region}:${AWS::AccountId}:key/<key-id>"
          - Sid: "ManageLambdaLogs"
            Effect: "Allow"
            Action:
            - "logs:CreateLogGroup"
            - "logs:CreateLogStream"
            - "logs:PutLogEvents"
            - "logs:PutRetentionPolicy"
            - "logs:PutSubscriptionFilter"
            - "logs:DescribeLogStreams"
            - "logs:DeleteLogGroup"
            - "logs:DeleteRetentionPolicy"
            - "logs:DeleteSubscriptionFilter"
            Resource:
              Fn::Sub: "arn:aws:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${AWS::StackName}-cfnKmsDecrypt:*:*"
```

With the Lambda function in place, the following custom resource calls the Lambda function when the resource is created, updated or deleted:

```
Resources:
  ...
  ...
  DbPasswordDecrypt:
    Type: "Custom::KMSDecrypt"
    Properties:
      ServiceToken:
        Fn::Sub: ${KMSDecrypter.Arn}
      Ciphertext: "<ciphertext>"
  ...
  ...
```

The `Ciphertext` value is required and must include valid KMS ciphertext output in a Base64 encoded format.

### Generating Ciphertext

You can generate the ciphertext to pass to your CloudFormation stacks by using the AWS CLI, specifying the appropriate KMS Key Id and plaintext you want to encrypt.  The returned `CiphertextBlob` value is the Base64 encoded ciphertext that is expected for the KMS decrypt custom resource.

> NOTE: You must have permissions to be able to encrypt using the KMS Key Id specified

```
$ aws kms encrypt --key-id 3ea941bf-ee54-4941-8f77-f1dd417667cd --plaintext 'Hello World!'
{
    "KeyId": "arn:aws:kms:us-west-2:429614120872:key/3ea941bf-ee54-4941-8f77-f1dd417667cd",
    "CiphertextBlob": "AQECAHgohc0dbuzR1L3lEdEkDC96PMYUEV9nITogJU2vbocgQAAAAGowaAYJKoZIhvcNAQcGoFswWQIBADBUBgkqhkiG9w0BBwEwHgYJYIZIAWUDBAEuMBEEDB4uW3mVBu3L8ErR1AIBEIAnSkLisBBGibq5wjbMR/0Ew9QDAbP37gXU8jdOYYZFzNOO8IwbnvHS"
}
```

### Return Values

This function will return the following properties to CloudFormation:

| Property  | Description                                  |
|-----------|----------------------------------------------|
| Plaintext | Plaintext output of the decrypted Ciphertext |

For example, you can obtain the plaintext value of encrypted ciphertext as demonstrated below.  In this example, the DbPassword parameter is KMS encrypted ciphertext that is supplied as an input parameter to the stack.

```
Parameters:
  DbPassword:
    Type: String
    Description: KMS encrypted database password
Resources:
  DbPasswordDecrypt:
    Type: "Custom::KMSDecrypt"
    Properties:
      ServiceToken: "arn:aws:lambda:us-west-2:429614120872:function:my-product-dev-cfnKmsDecrypt"
      Ciphertext: { "Ref": "DbPassword" }
  DbInstance:
    Type: "AWS::RDS::DBInstance"
    Properties:
      ...
      MasterUserPassword:
        Fn::Sub: ${DbPasswordDecrypt.Plaintext}
```

## Release Notes

### Version 1.0.0

 - **NEW FEATURE**: Added support for environment cbp-acceptance

## License

Copyright (C) 2017.  Case Commons, Inc.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

See www.gnu.org/licenses/agpl.html

