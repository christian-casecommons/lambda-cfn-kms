#!/usr/bin/env python
import logging
import boto3
import base64
import sys, os
parent_dir = os.path.abspath(os.path.dirname(__file__))
vendor_dir = os.path.join(parent_dir, 'vendor')
sys.path.append(vendor_dir)
from cfn_lambda_handler import Handler

# set handler as the entry point for Lambda
handler = Handler()

# Configure logging
log = logging.getLogger()
log.setLevel(logging.INFO)

# KMS client
kms = boto3.client('kms')
  
# Event handlers
@handler.create
@handler.update
def handle(event, context):
  log.info('Received event %s' % str(event))

  # Get event properties
  resource_properties = event.get('ResourceProperties')
  ciphertext = resource_properties.get('Ciphertext')
  if not ciphertext:
    raise Exception("Invalid configuration.  You must specify the Ciphertext property.")

  # Decrypt ciphertext
  plaintext = kms.decrypt(CiphertextBlob=base64.b64decode(ciphertext)).get('Plaintext')
  return { "PhysicalResourceId": event.get('LogicalResourceId'), "Data": { "Plaintext": plaintext } }

@handler.delete
def handle_delete(event, context):
  log.info('Received event %s' % str(event))
  return { "PhysicalResourceId": event.get('PhysicalResourceId') }