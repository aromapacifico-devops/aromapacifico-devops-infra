"""Stores each reading once and reports the messages of a batch that failed.

Range evaluation and alerts belong to the platform application. This handler proves the path
from the node to the readings table.
"""

import json
import logging
import os
from datetime import datetime, timedelta
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE = boto3.resource("dynamodb").Table(os.environ["READINGS_TABLE"])
TTL_DAYS = int(os.environ["READINGS_TTL_DAYS"])
REQUIRED = ("schema", "node_id", "seq", "measured_at", "stream", "values", "received_at", "topic_node_id")
STREAMS = ("crop", "drying")


def parse_time(value):
    return datetime.strptime(value.replace("Z", "+00:00"), "%Y-%m-%dT%H:%M:%S.%f%z" if "." in value else "%Y-%m-%dT%H:%M:%S%z")


def validate(reading):
    missing = [field for field in REQUIRED if field not in reading]
    if missing:
        raise ValueError(f"missing fields {missing}")
    if reading["stream"] not in STREAMS:
        raise ValueError(f"unknown stream {reading['stream']}")
    if reading["node_id"] != reading["topic_node_id"]:
        raise ValueError("node_id differs from the node of the topic")
    if not isinstance(reading["seq"], int) or not isinstance(reading["values"], dict):
        raise ValueError("seq must be an integer and values an object")
    if parse_time(reading["measured_at"]) - parse_time(reading["received_at"]) > timedelta(minutes=5):
        raise ValueError("measured_at is more than 5 minutes ahead of received_at")


def store(reading):
    measured_at = parse_time(reading["measured_at"])
    item = json.loads(json.dumps(reading), parse_float=Decimal)
    item["sk"] = f"{reading['measured_at']}#{reading['seq']}"
    item["expires_at"] = int((measured_at + timedelta(days=TTL_DAYS)).timestamp())
    try:
        TABLE.put_item(Item=item, ConditionExpression="attribute_not_exists(sk)")
        return "stored"
    except ClientError as error:
        if error.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return "duplicate"
        raise


def handler(event, context):
    failures = []
    for record in event["Records"]:
        try:
            reading = json.loads(record["body"])
            validate(reading)
            result = store(reading)
            logger.info(json.dumps({"node_id": reading["node_id"], "sk": f"{reading['measured_at']}#{reading['seq']}", "result": result}))
        except Exception as error:
            logger.error(json.dumps({"message_id": record["messageId"], "error": str(error)}))
            failures.append({"itemIdentifier": record["messageId"]})
    return {"batchItemFailures": failures}
