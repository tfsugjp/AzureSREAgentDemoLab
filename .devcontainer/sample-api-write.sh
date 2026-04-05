#!/usr/bin/env bash

set -euo pipefail

ACTION="${1:-}"
MODE="${2:-local}"

if [[ -z "$ACTION" ]]; then
  echo "Usage: bash .devcontainer/sample-api-write.sh <create-notification|mark-notification-read|create-order|advance-order-status|cancel-order|update-inventory> [local|compose]"
  exit 1
fi

case "$MODE" in
  local)
    BASE_HOST="localhost"
    ;;
  compose)
    BASE_HOST="host.docker.internal"
    ;;
  *)
    echo "Unknown mode: $MODE"
    echo "Supported values: local, compose"
    exit 1
    ;;
esac

request_json() {
  local method="$1"
  local url="$2"
  local body="${3:-}"

  if [[ -n "$body" ]]; then
    curl -fsS -X "$method" "$url" \
      -H "Content-Type: application/json" \
      -d "$body"
  else
    curl -fsS -X "$method" "$url"
  fi
}

build_order_payload() {
  python3 - <<'PY'
import json, time
now = int(time.time())
payload = {
    "userId": f"demo-user-{now}",
    "shippingAddress": "1 Dev Container Way, Seattle, WA",
    "notes": "Created from sample-api-write.sh",
    "items": [
        {
            "productId": "sample-product-1",
            "productName": "Sample Product",
            "quantity": 2,
            "unitPrice": 19.99,
        }
    ]
}
print(json.dumps(payload))
PY
}

create_order_request() {
  local payload
  payload="$(build_order_payload)"
  request_json POST "http://${BASE_HOST}:5002/api/orders" "$payload"
}

case "$ACTION" in
  create-notification)
    PAYLOAD="$(python3 - <<'PY'
import json, time, uuid
now = int(time.time())
payload = {
    "userId": f"demo-user-{now}",
    "title": "Dev Container Sample Notification",
    "message": "Created from sample-api-write.sh",
    "type": "Info",
    "isRead": False,
    "relatedEntityId": str(uuid.uuid4()),
}
print(json.dumps(payload))
PY
)"

    RESPONSE="$(request_json POST "http://${BASE_HOST}:5003/api/notifications" "$PAYLOAD")"
    printf '%s' "$RESPONSE" | jq -r '
      if .success == true then
        "[sample-write] Created notification id=" + (.data.id | tostring) + " for user=" + (.data.userId | tostring)
      else
        error("notification create failed")
      end
    '
    ;;
  mark-notification-read)
    NOTIFICATION_ID="$(curl -fsS "http://${BASE_HOST}:5003/api/notifications" | jq -r '(.data // []) | map(select(.isRead != true)) | if length > 0 then .[0].id else empty end')"

    if [[ -z "$NOTIFICATION_ID" ]]; then
      NOTIFICATION_ID="$(curl -fsS "http://${BASE_HOST}:5003/api/notifications" | jq -r '(.data // []) | if length > 0 then .[0].id else empty end')"
    fi

    if [[ -z "$NOTIFICATION_ID" ]]; then
      echo "[sample-write] No notification found to mark as read."
      exit 1
    fi

    RESPONSE="$(request_json PUT "http://${BASE_HOST}:5003/api/notifications/${NOTIFICATION_ID}/read")"
    printf '%s' "$RESPONSE" | jq -r '
      if .success == true then
        "[sample-write] Marked notification as read id=" + (.data.id | tostring)
      else
        error("notification mark-read failed")
      end
    '
    ;;
  create-order)
    RESPONSE="$(create_order_request)"
    printf '%s' "$RESPONSE" | jq -r '
      if .success == true then
        "[sample-write] Created order id=" + (.data.id | tostring) + " status=" + (.data.status | tostring) + " total=" + (.data.totalAmount | tostring)
      else
        error("order create failed")
      end
    '
    ;;
  advance-order-status)
    ORDER_JSON="$(curl -fsS "http://${BASE_HOST}:5002/api/orders" | jq -c '
      (.data // [])
      | map(
          . as $o
          | .nextStatus = (
              if .status == "Pending" then "Confirmed"
              elif .status == "Confirmed" then "Processing"
              elif .status == "Processing" then "Shipped"
              elif .status == "Shipped" then "Delivered"
              else null
              end
            )
        )
      | map(select(.nextStatus != null))
      | if length > 0 then .[0] else empty end
    ')"

    if [[ -z "$ORDER_JSON" ]]; then
      echo "[sample-write] No order found with an allowed next status transition."
      exit 1
    fi

    ORDER_ID="$(printf '%s' "$ORDER_JSON" | jq -r '.id')"
    NEXT_STATUS="$(printf '%s' "$ORDER_JSON" | jq -r '.nextStatus')"
    PAYLOAD="$(printf '{"status":"%s"}' "$NEXT_STATUS")"

    RESPONSE="$(request_json PUT "http://${BASE_HOST}:5002/api/orders/${ORDER_ID}/status" "$PAYLOAD")"
    printf '%s' "$RESPONSE" | jq -r '
      if .success == true then
        "[sample-write] Updated order id=" + (.data.id | tostring) + " status=" + (.data.status | tostring)
      else
        error("order status update failed")
      end
    '
    ;;
  cancel-order)
    ORDER_JSON="$(curl -fsS "http://${BASE_HOST}:5002/api/orders" | jq -c '
      (.data // [])
      | map(select(.status == "Pending" or .status == "Confirmed"))
      | if length > 0 then .[0] else empty end
    ')"

    if [[ -z "$ORDER_JSON" ]]; then
      ORDER_JSON="$(create_order_request | jq -c 'if .success == true then .data else empty end')"
    fi

    if [[ -z "$ORDER_JSON" ]]; then
      echo "[sample-write] No cancellable order could be prepared."
      exit 1
    fi

    ORDER_ID="$(printf '%s' "$ORDER_JSON" | jq -r '.id')"
    RESPONSE="$(request_json POST "http://${BASE_HOST}:5002/api/orders/${ORDER_ID}/cancel")"
    printf '%s' "$RESPONSE" | jq -r '
      if .success == true then
        "[sample-write] Cancelled order id=" + (.data.id | tostring) + " status=" + (.data.status | tostring)
      else
        error("order cancel failed")
      end
    '
    ;;
  update-inventory)
    PRODUCT_ID="$(curl -fsS "http://${BASE_HOST}:5001/api/products" | jq -r '(.data // []) | if length > 0 then .[0].id else empty end')"

    if [[ -z "$PRODUCT_ID" ]]; then
      echo "[sample-write] No product found for inventory update."
      exit 1
    fi

    INVENTORY_JSON="$(curl -fsS "http://${BASE_HOST}:5001/api/inventory/${PRODUCT_ID}" | jq -c 'if .success == true then .data else empty end')"

    if [[ -z "$INVENTORY_JSON" ]]; then
      echo "[sample-write] Inventory item for product ${PRODUCT_ID} was not found."
      exit 1
    fi

    PAYLOAD="$(printf '%s' "$INVENTORY_JSON" | jq -c '.quantity = (.quantity + 5) | .lastRestockedAt = (now | todateiso8601)')"
    RESPONSE="$(request_json PUT "http://${BASE_HOST}:5001/api/inventory/${PRODUCT_ID}" "$PAYLOAD")"
    printf '%s' "$RESPONSE" | jq -r '
      if .success == true then
        "[sample-write] Updated inventory productId=" + (.data.productId | tostring) +
        " quantity=" + (.data.quantity | tostring) +
        " available=" + (.data.availableQuantity | tostring)
      else
        error("inventory update failed")
      end
    '
    ;;
  *)
    echo "Unknown action: $ACTION"
    echo "Supported values: create-notification, mark-notification-read, create-order, advance-order-status, cancel-order, update-inventory"
    exit 1
    ;;
esac
