import boto3
import os
import json
# Initialize dynamodb boto3 object
dynamodb = boto3.resource('dynamodb')
# Set dynamodb table name variable from env
table = dynamodb.Table("visitor-counter")


def lambda_handler(event, context):
    response = table.get_item(Key={
            'id': '1'
        })
    views = response['Item']['views']
    print()
    views = views + 1
    print(views)
    response = table.put_item(Item={
        'id': '1',
        'views': views
        })
    return views

