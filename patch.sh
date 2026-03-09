#!/bin/bash
# Chrome Gemini 启用脚本
# 使用前提：必须先开 VPN 并连接美国节点

set -e

CHROME_DIR="/Users/$(whoami)/Library/Application Support/Google/Chrome"
LOCAL_STATE="$CHROME_DIR/Local State"
PREFS="$CHROME_DIR/Profile 2/Preferences"

echo "🔍 检查 VPN..."
COUNTRY=$(curl -s --max-time 5 https://ipinfo.io/country 2>/dev/null | tr -d '\n')
if [ "$COUNTRY" != "US" ]; then
  echo "❌ 当前 IP 不是美国（当前: ${COUNTRY:-未知}），请先连接美国 VPN 节点"
  exit 1
fi
echo "✅ IP 确认是美国"

echo "🔴 关闭 Chrome..."
pkill -x "Google Chrome" 2>/dev/null || true
sleep 2

echo "🔧 打补丁..."
python3 << 'PYEOF'
import json, sys

# === Local State ===
ls_path = "/Users/" + __import__('os').getenv('USER') + "/Library/Application Support/Google/Chrome/Local State"
with open(ls_path) as f:
    ls = json.load(f)

ls['variations_country'] = 'us'
ls.setdefault('glic', {})['launcher_enabled'] = True
ls.setdefault('glic', {})['multi_instance_enabled_by_tier'] = True

count = 0
for name, profile in ls.get('profile', {}).get('info_cache', {}).items():
    profile['is_glic_eligible'] = True
    count += 1

with open(ls_path, 'w') as f:
    json.dump(ls, f, separators=(',', ':'))
print(f"  Local State: {count} 个 Profile 已设 is_glic_eligible=True")

# === Preferences ===
prefs_path = "/Users/" + __import__('os').getenv('USER') + "/Library/Application Support/Google/Chrome/Profile 2/Preferences"
with open(prefs_path) as f:
    prefs = json.load(f)

prefs.setdefault('glic', {})['completed_fre'] = 1

iph = prefs.get('in_product_help', {}).get('snoozed_feature', {}).get('IPH_GlicTryIt', {})
if iph:
    iph['is_dismissed'] = False
    print("  Preferences: IPH_GlicTryIt dismissed 已重置")

with open(prefs_path, 'w') as f:
    json.dump(prefs, f, separators=(',', ':'))
print("  Preferences: glic.completed_fre=1")
PYEOF

echo "🚀 启动 Chrome..."
open -a "Google Chrome" --args --variations-override-country=us --enable-features=GlicRollout
sleep 5

echo "🔍 验证补丁是否保持..."
python3 << 'PYEOF'
import json, os
ls_path = f"/Users/{os.getenv('USER')}/Library/Application Support/Google/Chrome/Local State"
with open(ls_path) as f:
    ls = json.load(f)
for name, p in ls.get('profile', {}).get('info_cache', {}).items():
    status = p.get('is_glic_eligible', 'N/A')
    icon = "✅" if status is True else "❌"
    print(f"  {icon} {name}: is_glic_eligible = {status}")
PYEOF

echo ""
echo "完成！去 Chrome 工具栏找 ✦ Gemini 图标"
