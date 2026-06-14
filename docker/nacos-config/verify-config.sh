#!/bin/bash
# Verify Nacos configs exist
TOKEN=$(curl -s -X POST "http://127.0.0.1:8848/nacos/v1/auth/login" \
    -d "username=nacos" -d "password=nacos" 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    TOKEN=$(curl -s -X POST "http://127.0.0.1:8848/nacos/v1/auth/login" \
        -d "username=nacos" -d "password=nacos" 2>/dev/null \
        | grep -o '"accessToken":"[^"]*"' | head -1 | cut -d'"' -f4)
fi

echo "Token length: ${#TOKEN}"

for f in mall-admin-prod.yaml mall-auth-prod.yaml mall-gateway-prod.yaml mall-portal-prod.yaml mall-search-prod.yaml; do
    RESULT=$(curl -s "http://127.0.0.1:8848/nacos/v1/cs/configs?dataId=${f}&group=DEFAULT_GROUP&accessToken=${TOKEN}" 2>/dev/null)
    if echo "$RESULT" | grep -q "config data not exist"; then
        echo "MISSING: $f"
    elif [ -z "$RESULT" ]; then
        echo "EMPTY: $f"
    else
        echo "EXISTS: $f (length=$(echo "$RESULT" | wc -c))"
    fi
done
