"""Stand-in for a function whose logic belongs to the platform application. It logs what it receives."""

import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    logger.info(json.dumps({"records": len(event.get("Records", [])), "keys": sorted(event)}))
    return {"batchItemFailures": []}
