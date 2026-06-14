#!/bin/bash
# ============================================================
#  mall-swarm Nacos 配置导入脚本
#
#  功能: 将 nacos-config/ 目录下的所有 prod YAML 文件
#        通过 Nacos Open API 批量导入到 Nacos 配置中心
#
#  使用方式:
#    chmod +x import-config.sh
#    ./import-config.sh [nacos_addr] [nacos_user] [nacos_pass]
#
#  默认: nacos_addr=127.0.0.1:8848, user=nacos, pass=nacos
# ============================================================

set -e

NACOS_ADDR="${1:-127.0.0.1:8848}"
NACOS_USER="${2:-nacos}"
NACOS_PASS="${3:-nacos}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}"

echo "=========================================="
echo " Nacos 配置导入"
echo " Nacos 地址: ${NACOS_ADDR}"
echo " 配置目录: ${CONFIG_DIR}"
echo "=========================================="

# 等待 Nacos 就绪
echo ""
echo "[1/4] 等待 Nacos 就绪..."
MAX_RETRY=30
RETRY=0
until curl -sf "http://${NACOS_ADDR}/nacos/v1/console/health/liveness" > /dev/null 2>&1; do
    RETRY=$((RETRY+1))
    if [ $RETRY -ge $MAX_RETRY ]; then
        echo "❌ Nacos 在 ${MAX_RETRY} 次重试后仍未就绪，退出"
        exit 1
    fi
    echo "  等待中... (${RETRY}/${MAX_RETRY})"
    sleep 5
done
echo "✅ Nacos 已就绪"

# 登录获取 accessToken
echo ""
echo "[2/4] 登录 Nacos 获取认证 token..."
LOGIN_RESP=$(curl -sf -X POST "http://${NACOS_ADDR}/nacos/v1/auth/login" \
    -d "username=${NACOS_USER}&password=${NACOS_PASS}" 2>/dev/null || echo "")

TOKEN=$(echo "${LOGIN_RESP}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))" 2>/dev/null || true)

if [ -z "${TOKEN}" ]; then
    # 尝试 grep 方式
    TOKEN=$(echo "${LOGIN_RESP}" | grep -o '"accessToken":"[^"]*"' | head -1 | cut -d'"' -f4 2>/dev/null || true)
fi

if [ -z "${TOKEN}" ]; then
    echo "⚠️  未能获取 accessToken，尝试不带 token 继续"
    TOKEN_PARAM=""
else
    echo "✅ 获取 token 成功"
    TOKEN_PARAM="accessToken=${TOKEN}"
fi

# 导入配置
echo ""
echo "[3/4] 开始导入配置..."

IMPORTED=0
FAILED=0

for yaml_file in "${CONFIG_DIR}"/*-prod.yaml; do
    if [ ! -f "$yaml_file" ]; then
        continue
    fi

    filename=$(basename "$yaml_file")
    data_id="${filename}"
    group="DEFAULT_GROUP"
    content_type="yaml"

    echo "  导入: ${data_id}"

    # 读取文件内容
    content=$(cat "$yaml_file")

    # 构建POST数据
    POST_DATA="dataId=${data_id}&group=${group}&type=${content_type}"
    if [ -n "${TOKEN_PARAM}" ]; then
        POST_DATA="${POST_DATA}&${TOKEN_PARAM}"
    fi

    # 调用 Nacos Open API 发布配置
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        "http://${NACOS_ADDR}/nacos/v1/cs/configs" \
        -d "${POST_DATA}" \
        --data-urlencode "content=${content}")

    if [ "$http_code" = "200" ]; then
        echo "    ✅ 成功 (HTTP ${http_code})"
        IMPORTED=$((IMPORTED+1))
    else
        echo "    ❌ 失败 (HTTP ${http_code})"
        FAILED=$((FAILED+1))
    fi
done

# 验证
echo ""
echo "[4/4] 验证已导入的配置..."

VERIFY_URL="http://${NACOS_ADDR}/nacos/v1/cs/configs"
for yaml_file in "${CONFIG_DIR}"/*-prod.yaml; do
    if [ ! -f "$yaml_file" ]; then
        continue
    fi
    filename=$(basename "$yaml_file")
    data_id="${filename}"
    group="DEFAULT_GROUP"

    VERIFY_PARAMS="dataId=${data_id}&group=${group}"
    if [ -n "${TOKEN_PARAM}" ]; then
        VERIFY_PARAMS="${VERIFY_PARAMS}&${TOKEN_PARAM}"
    fi

    result=$(curl -sf "${VERIFY_URL}?${VERIFY_PARAMS}" 2>/dev/null || echo "")
    if [ -n "$result" ]; then
        echo "  ✅ ${data_id} - 已确认"
    else
        echo "  ❌ ${data_id} - 未找到"
    fi
done

echo ""
echo "=========================================="
echo " 导入完成: 成功 ${IMPORTED} 个, 失败 ${FAILED} 个"
echo "=========================================="
