# Chrome Gemini 启用脚本（macOS）

在**非美国地区**的 Google 账号上，强制开启 Chrome 内置 Gemini（工具栏 ✦ 图标）。

> **声明**：本脚本由 [Claude Code](https://claude.ai/code)（Anthropic 出品的 AI 编程助手）辅助编写。
> 运行前建议把 `patch.sh` 的内容复制给任意 AI（ChatGPT、Claude、Gemini 均可），让它帮你检查是否存在安全风险，以及确认脚本逻辑是否符合预期。

---

## 原理

Chrome 启动联网后会向 Google 服务器同步配置。服务器根据账号地区判断资格：

- 美国账号 / Gemini Advanced 订阅 → `is_glic_eligible = true` → 显示 Gemini 图标
- 其他地区 → 强制设回 `false` → 图标消失

**解决思路：** 挂美国 VPN，让服务器认为你在美国；同时在 Chrome 关闭期间修改本地配置文件，并用特殊启动参数绕过 A/B 实验分组。

---

## 前提条件

- macOS
- Chrome（测试版本：145.0.7632.110）
- 能连接**美国节点**的 VPN（ISP 级别效果最好）

---

## 使用方法

**1. 开 VPN，连接美国节点**

**2. 下载并运行脚本（二选一）**

方式 A：一行命令，直接运行（推荐）
```bash
curl -fsSL https://raw.githubusercontent.com/zhangbaoshengrio/chrome-gemini-unlock/master/patch.sh | bash
```

方式 B：先下载再运行
```bash
git clone https://github.com/zhangbaoshengrio/chrome-gemini-unlock.git
cd chrome-gemini-unlock
bash patch.sh
```

**3. 等 Chrome 启动完毕，查看工具栏右上角的 ✦ 图标**

> 如果图标不在工具栏，右键工具栏 → 看有没有 Gemini 选项可以固定

---

## 脚本做了什么（逻辑说明）

### 1. 验证 VPN（IP 必须是美国）

```bash
COUNTRY=$(curl -s https://ipinfo.io/country)
```

向 `ipinfo.io` 查当前出口 IP 的归属地。不是 `US` 直接退出，避免白打补丁。

### 2. 关闭 Chrome

```bash
pkill -x "Google Chrome"
```

补丁必须在 Chrome **关闭状态**下写入，否则 Chrome 退出时会用自己的缓存覆盖修改。

### 3. 修改两个配置文件

**`~/Library/Application Support/Google/Chrome/Local State`**

```json
{
  "variations_country": "us",
  "glic": { "launcher_enabled": true },
  "profile": {
    "info_cache": {
      "<所有 Profile>": { "is_glic_eligible": true }
    }
  }
}
```

**`~/Library/Application Support/Google/Chrome/Profile 2/Preferences`**

```json
{
  "glic": { "completed_fre": 1 },
  "in_product_help": {
    "snoozed_feature": {
      "IPH_GlicTryIt": { "is_dismissed": false }
    }
  }
}
```

- `is_glic_eligible`：告诉 Chrome 此账号有 Gemini 使用资格
- `completed_fre`：标记首次使用引导已完成，跳过新手提示
- `IPH_GlicTryIt`：重置"试用 Gemini"的提示气泡，让图标重新显示

### 4. 用特殊参数启动 Chrome

```bash
open -a "Google Chrome" --args \
  --variations-override-country=us \
  --enable-features=GlicRollout
```

- `--variations-override-country=us`：运行时告诉 Chrome 把自己当成美国用户
- `--enable-features=GlicRollout`：强制开启 Glic 功能，跳过 A/B 实验分组

### 5. 验证补丁是否保持

启动 5 秒后重新读取 Local State，确认 `is_glic_eligible` 没有被服务器重置回 `false`。

---

## 安全说明

- 脚本**只修改当前用户**的 Chrome 配置文件（`~/Library/...`），不涉及系统文件
- **无 `sudo`，无提权**
- 唯一的网络请求是向 `ipinfo.io` 查 IP 归属地（只发 GET，不上传任何数据）
- 不会在系统中留下守护进程或定时任务

如有疑虑，运行前请将 `patch.sh` 内容发给 AI 进行独立核查。

---

## 常见问题

**Q: 关了 VPN 后 Gemini 图标还在吗？**
A: 只要不重启 Chrome，图标还在。重启 Chrome 后如果消失，需要重新运行脚本（开着 VPN）。

**Q: 脚本报错找不到 Preferences 文件？**
A: 你的主 Profile 可能是 `Default` 而非 `Profile 2`。修改脚本顶部的 `PREFS` 变量：
```bash
PREFS="$CHROME_DIR/Default/Preferences"
```

**Q: 补丁验证显示 ❌ is_glic_eligible = False？**
A: VPN 不够"干净"，Google 服务器识别出是代理。换 ISP 级别的美国节点再试。

**Q: Gemini 图标点开后要求登录或提示不可用？**
A: 正常，点击后登录 Google 账号即可使用。

---

## License

MIT
