from __future__ import annotations

import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
from jsonschema import validate, ValidationError
import uuid

FRONTEND_HOST = os.environ["FRONTEND_HOST"]
FRONTEND_PORT = os.environ.get("FRONTEND_PORT",4000)
BACKEND_HOST = os.environ["BACKEND_HOST"]
BACKEND_PORT = os.environ.get("BACKEND_PORT",4000)

POLL_INTERVAL = float(os.environ.get("POLL_INTERVAL", "1"))
TRANSFER_DELAY = float(os.environ.get("TRANSFER_DELAY", "0.5"))

# Client certificate and key
CLIENT_CERT = os.environ.get("CLIENT_CERT", "testerdata/user.crt")
CLIENT_KEY = os.environ.get("CLIENT_KEY", "testerdata/user.key")

# Optional CA certificate used to validate the server
CA_CERT = os.environ.get("CA_CERT")

FRONTEND_URL = (
    f"https://{FRONTEND_HOST}:{FRONTEND_PORT}/api/frontend/v1alpha1/documents"
)
BACKEND_URL = (
    f"https://{BACKEND_HOST}:{BACKEND_PORT}/api/backend/v1alpha1/documents"
)
FRONTEND_STATUS_URL = f"https://{FRONTEND_HOST}:{FRONTEND_PORT}/api/frontend/v1alpha1/status"
BACKEND_STATUS_URL = f"https://{BACKEND_HOST}:{BACKEND_PORT}/api/backend/v1alpha1/status"

# Create TLS context
SSL_CONTEXT = ssl._create_unverified_context()

# Load client certificate and key for mutual TLS
SSL_CONTEXT.load_cert_chain(certfile=CLIENT_CERT, keyfile=CLIENT_KEY)


ERROR_SCHEMA = {
    "type": "object",
    "required": ["code", "message"],
    "properties": {
        "code": {
            "type": "string",
            "description": "Error code"
        },
        "message": {
            "type": "string",
            "description": "Error message"
        }
    },
    "additionalProperties": True
}

COMPONENT_STATUS_SCHEMA = {
    "type": "object",
    "properties": {
        "status": {
            "type": "string",
            "description": "Any status details"
        },
        "errors": {
            "type": "array",
            "items": ERROR_SCHEMA
        }
    },
    "additionalProperties": True
}

DOCUMENT_SCHEMA = {
    "type": "object",
    "required": ["id", "content"],
    "properties": {
        "id": {
            "type": "string",
            "format": "uuid",
            "description": "Filename/UniqueID for document"
        },
        "content": {
            "type": "string",
            "description": "Content of the document"
        },
        "signature": {
            "type": "string",
            "description": "Confirmation queue add-on signature if confirmed"
        },
        "metadata": {
            "type": "string",
            "description": "Document metadata viewed by Auditors"
        }
    },
    "additionalProperties": True
}

DOCUMENTS_SCHEMA = {
    "type": "object",
    "required": ["documents", "count"],
    "properties": {
        "documents": {
            "type": "array",
            "items": DOCUMENT_SCHEMA
        },
        "count": {
            "type": "integer"
        }
    }
}

def validate_documents(payload: dict) -> bool:
    try:
        validate(instance=payload, schema=DOCUMENTS_SCHEMA)

        # extra strict check: UUID format (jsonschema format is NOT strict by default)
        for doc in payload.get("documents", []):
            uuid.UUID(doc["id"])

        return True

    except (ValidationError, ValueError) as e:
        print("[SCHEMA ERROR]", e)
        return False

def validate_component_status(payload: dict) -> bool:
    try:
        validate(instance=payload, schema=COMPONENT_STATUS_SCHEMA)
        return True

    except ValidationError as e:
        print("[STATUS SCHEMA ERROR]", e)
        return False




def _status(url: str) -> None:
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, context=SSL_CONTEXT) as resp:
            data = json.loads(resp.read())

            if validate_component_status(data):
                print("[STATUS OK]", data.get("status"))
                return data
            else:
                print("[STATUS INVALID]")
                return None

    except Exception as e:
        print("[STATUS ERROR]", url, e)
        return None

def _get(url: str) -> list[dict[str, object]] | None:
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, context=SSL_CONTEXT) as resp:
            body = resp.read()
            if not body:
                return None

            data = json.loads(body)
            print(data)
            if validate_documents(data):
                return data["documents"]
            else:
                print("Invalid document payload", file=sys.stderr)
                return None

    except Exception as e:
        print("GET error:", e, file=sys.stderr)
        return None



def _post(url: str, docs: list[dict[str, object]]) -> None:
    data = json.dumps(docs).encode()

    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req, context=SSL_CONTEXT) as resp:
            resp.read()

    except urllib.error.HTTPError as e:
        print(f"POST {url} failed: {e.code}", file=sys.stderr)

    except urllib.error.URLError as e:
        print(f"POST {url} unreachable: {e.reason}", file=sys.stderr)
        if hasattr(e, "reason"):
            print(f"Reason: {e.reason}", file=sys.stderr)
        raise

def main() -> None:

    print("-----------------------------------------------------------")
    print("Checking system status...")
    _status(FRONTEND_STATUS_URL)
    _status(BACKEND_STATUS_URL)
    print("-----------------------------------------------------------")
    print(f"Bridge polling: frontend={FRONTEND_URL}")
    print(f"                 backend={BACKEND_URL}")
    print("-----------------------------------------------------------")

    while True:
        docs = _get(FRONTEND_URL)
        if docs:
            print(f"-> docs from frontend, forwarding to backend")
            print(json.dumps(docs, indent=2)) 
            _post(BACKEND_URL, docs)

        time.sleep(TRANSFER_DELAY)

        docs = _get(BACKEND_URL)
        if docs:
            print(f"<- docs from backend, forwarding to frontend")
            _post(FRONTEND_URL, docs)

        time.sleep(POLL_INTERVAL)
        print("-----------------------------------------------------------")


if __name__ == "__main__":
    main()
