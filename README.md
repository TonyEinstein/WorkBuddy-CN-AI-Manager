# WorkBuddy 国内版与国际版共存 + 关闭自动更新 教程

> 适用场景：同时安装 WorkBuddy（国内版）和 WorkBuddy AI（国际版），希望两者**共存、不互相覆盖、不自动更新**。
> 平台：Windows 10/11。命令行以 **命令提示符（cmd）** 为主，PowerShell 脚本作为可选补充。

---


## ⚠️ 免责声明
本项目及内置修复脚本仅用于技术学习与参考。
1. 运行脚本前请自行备份系统、注册表、文件等重要数据；
2. 脚本会修改本地系统配置，**使用风险由使用者自行承担**；
3. 作者不对因使用本项目造成的数据丢失、系统异常等任何损失承担责任；
4. 本项目不提供任何形式的担保。
5. 
本项目代码基于 [MIT License](./LICENSE) 。



## 目录

1. [背景与目标](#1-背景与目标)
2. [根因分析](#2-根因分析)
3. [完整证据链](#3-完整证据链)
4. [一次性修复步骤](#4-一次性修复步骤)
5. [验证是否修复成功](#5-验证是否修复成功)
6. [以后手动升级怎么做](#6-以后手动升级怎么做)
7. [升级完成后必做清单](#7-升级完成后必做清单)
8. [遗留风险与局限](#8-遗留风险与局限)
9. [附录：关键路径与命令速查](#9-附录关键路径与命令速查)

---

## 1. 背景与目标

| 版本 | 安装目录 | 配置目录 | 主程序 | 官网域名 |
|---|---|---|---|---|
| 国内版 WorkBuddy | `%LOCALAPPDATA%\Programs\WorkBuddy` | `%USERPROFILE%\.workbuddy` | `WorkBuddy.exe` | workbuddy.cn / codebuddy.cn |
| 国际版 WorkBuddy AI | `%LOCALAPPDATA%\Programs\WorkBuddyAI` | `%USERPROFILE%\.workbuddy-ai` | `WorkBuddyAI.exe` | workbuddy.ai |

**目标**：两个版本都能正常打开、登录、各自使用；互不覆盖、互不干扰；都不自动更新。

---

## 2. 根因分析

### 2.1 两个版本本质是「同一产品」

国内版和国际版在打包层面共用同一套身份标识，证据：

- 包名（package name）完全相同：`@genie/workbuddy-desktop`
- appId 完全相同：`1:654800341332:web:4a692de832b55bd57ce0c1`
- 共享同一个更新器缓存目录：`%LOCALAPPDATA%\@genieworkbuddy-desktop-updater`

### 2.2 国际版缓存被国内版云端配置「污染」

国际版 `%USERPROFILE%\.workbuddy-ai\cache\acc-product-config-v3.json` 这个本地缓存，会被国内版云端下发的配置覆盖，导致国际版把自己当成国内版：

| 字段 | 正确值（国际版） | 被污染后 | 后果 |
|---|---|---|---|
| `endpoint` | `https://www.workbuddy.ai` | `https://www.workbuddy.cn` | 去国内服务器拉包 |
| `win32MutexName` | `workbuddy-ai` | `workbuddy` | 单实例锁与国内版同名，无法同时运行 |
| `dataFolderName` | `.workbuddy-ai` | `.workbuddy` | 数据目录与国内版同名，数据互相覆盖 |
| `startupForceAutoUpdate` | — | `true` | 启动即强制更新 |

### 2.3 自动更新的「多重触发」机制

代码里自动更新有两条**互相独立**的通道：

**通道 A：启动强制自动更新**（`startupForceAutoUpdate`）

决策优先级从高到低：
```
用户设置 > 云端远程配置 > 缓存默认值 > product.json 的 startupForceAutoUpdate 字段 > 硬编码兜底(true)
```

国内版 `product.json` 写死 `"startupForceAutoUpdate": true`；国际版缺省，落到硬编码兜底也是 `true`。所以两者一启动就强制检查更新。

**通道 B：定时自动更新**（不受上面开关控制）

```js
// 启动 30 秒后
setTimeout(() => checkForUpdates(), 30000)
// 之后每 1 小时
setInterval(() => { checkForUpdates(); checkForceUpgrade(); }, 3600000)
```

生产环境无条件运行，查到新版本会**自动下载安装包**。

### 2.4 应用内更新的「platform 错位」bug（无法从配置根治）

代码 `resolveUpdateClientTypePrefix()` 会把国际版的 `applicationName=workbuddy-ai` **强制归一成 `workbuddy`**，导致国际版检查更新时发出的 platform 参数和国内版完全相同：

```
platform=workbuddy-win32-x64-user   （两个版本都发这个）
```

实测结果：

| 接口 | platform 参数 | 返回 |
|---|---|---|
| workbuddy.cn | `workbuddy-win32-x64-user` | 国内版安装包 `WorkBuddy-...exe` |
| workbuddy.cn | `workbuddy-ai-win32-x64-user` | 报错 `invalid platform` |
| workbuddy.ai | `workbuddy-win32-x64-user` | 204 无更新 |
| workbuddy.ai | `workbuddy-ai-win32-x64-user` | 报错 `invalid platform` |

**结论**：国际版的应用内更新通道本身是「坏的」——它发的 platform 是国内的标识，一旦国际站上架了对应安装包，极可能指向**国内版安装包**，国际版更新就会再次被国内版覆盖。这是产品代码 bug，用户层面无法根治，只能绕开（见第 6 节）。

---

## 3. 完整证据链

| # | 证据 | 说明 |
|---|---|---|
| 1 | package name 两版同为 `@genie/workbuddy-desktop` | 同一产品 |
| 2 | appId 两版同为 `1:654800341332:web:4a69...` | 同一产品 |
| 3 | 共享更新器缓存 `@genieworkbuddy-desktop-updater` | 互相抢 |
| 4 | 更新日志 `Checking for updates: https://www.workbuddy.cn/v2/update...` | 国际版也走国内更新源 |
| 5 | 国际版缓存 `endpoint=workbuddy.cn`、`win32MutexName=workbuddy` | 缓存被污染 |
| 6 | 安装日志 `install target dir: ...\WorkBuddyAI` 但命令行是 `WorkBuddy-Setup-*.exe` | 国内包覆盖国际目录 |
| 7 | 代码 `resolveUpdateClientTypePrefix` 归一 platform | 应用内更新错位 bug |
| 8 | 代码 `setInterval(checkForUpdates, 3600000)` | 独立定时更新 |

---

## 4. 一次性修复步骤

> 以下命令复制到**命令提示符（cmd）**直接执行即可。路径全部使用 `%LOCALAPPDATA%`、`%USERPROFILE%` 变量，无需修改用户名。

### 步骤 1：备份待修改文件

```cmd
mkdir "%LOCALAPPDATA%\Programs\workbuddy-fix-backup"
copy "%LOCALAPPDATA%\Programs\WorkBuddy\resources\app.asar.unpacked\cli\product.json" "%LOCALAPPDATA%\Programs\workbuddy-fix-backup\product-cn.json"
copy "%LOCALAPPDATA%\Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\product.json" "%LOCALAPPDATA%\Programs\workbuddy-fix-backup\product-ai.json"
copy "%USERPROFILE%\.workbuddy-ai\cache\acc-product-config-v3.json" "%LOCALAPPDATA%\Programs\workbuddy-fix-backup\acc-product-config-v3-ai.json"
```

### 步骤 2：修改两版 product.json 关闭启动强制更新

#### 方式 A（推荐）：用记事本手动改

```cmd
notepad "%LOCALAPPDATA%\Programs\WorkBuddy\resources\app.asar.unpacked\cli\product.json"
notepad "%LOCALAPPDATA%\Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\product.json"
```

**国内版**：找到 `updates` 段，把 `true` 改为 `false`：

```json
// 改前
"updates": {
  "apiVersion": "v2",
  "download": { "scene": "saas" },
  "checkVersion": { "scene": "saas" },
  "startupForceAutoUpdate": true
}

// 改后
"updates": {
  "apiVersion": "v2",
  "download": { "scene": "saas" },
  "checkVersion": { "scene": "saas" },
  "startupForceAutoUpdate": false
}
```

**国际版**：`updates` 段原本没有 `startupForceAutoUpdate` 字段，需要**手动补一行** `false`：

```json
// 改前
"updates": {
  "apiVersion": "v2",
  "download": { "scene": "saas" },
  "checkVersion": { "scene": "saas" }
}

// 改后
"updates": {
  "apiVersion": "v2",
  "download": { "scene": "saas" },
  "checkVersion": { "scene": "saas" },
  "startupForceAutoUpdate": false
}
```

> 补 `false` 而不是留空，是为了防止它落到「硬编码兜底 = true」那一档。

#### 方式 B（可选）：PowerShell 一键修改（无 BOM，安全）

把下面整段粘贴到 **PowerShell** 执行：

```powershell
$utf8 = New-Object System.Text.UTF8Encoding($false)  # UTF-8 无 BOM，避免 JSON 解析出错

# 国内版：true -> false
$cn = "$env:LOCALAPPDATA\Programs\WorkBuddy\resources\app.asar.unpacked\cli\product.json"
$c = [System.IO.File]::ReadAllText($cn)
$c = $c -replace '"startupForceAutoUpdate"\s*:\s*true', '"startupForceAutoUpdate": false'
[System.IO.File]::WriteAllText($cn, $c, $utf8)

# 国际版：缺字段则补 false，有字段则改 false
$ai = "$env:LOCALAPPDATA\Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\product.json"
$c = [System.IO.File]::ReadAllText($ai)
if ($c -match 'startupForceAutoUpdate') {
  $c = $c -replace '"startupForceAutoUpdate"\s*:\s*true', '"startupForceAutoUpdate": false'
} else {
  $c = $c -replace '("checkVersion"\s*:\s*\{\s*"scene"\s*:\s*"saas"\s*\})',
                  "`$1,`n    `"startupForceAutoUpdate`": false"
}
[System.IO.File]::WriteAllText($ai, $c, $utf8)

Write-Host "done"
```

### 步骤 3：删除国际版被污染的缓存

> 删除后，国际版下次启动会回退到磁盘上正确的 `product.json`，并重建出正确的缓存。

```cmd
del "%USERPROFILE%\.workbuddy-ai\cache\acc-product-config-v3.json"
```

### 步骤 4：清理残留的更新安装包

```cmd
del "%LOCALAPPDATA%\@genieworkbuddy-desktop-updater\installer.exe"
rd /s /q "%LOCALAPPDATA%\Temp\workbuddy-update-x64"
```

### 步骤 5：设置环境变量废掉定时更新（第二道保险）

> 这一步是**关键补充**：第 2 步关掉的是「启动强制更新」，但拦不住 2.3 节说的「每 30 秒 / 每 1 小时的定时更新」。设置这个环境变量后，定时更新请求会指向 `127.0.0.1:9`（系统保留端口，必然失败），从而彻底废掉更新通道。

```cmd
setx WORKBUDDY_UPDATE_URL "http://127.0.0.1:9"
```

> 设置后需**重启程序**（或重新登录 Windows）才完全生效。

---

## 5. 验证是否修复成功

### 5.1 验证 product.json 已关闭

```cmd
findstr /C:"startupForceAutoUpdate" "%LOCALAPPDATA%\Programs\WorkBuddy\resources\app.asar.unpacked\cli\product.json"
findstr /C:"startupForceAutoUpdate" "%LOCALAPPDATA%\Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\product.json"
```

两个都应显示 `"startupForceAutoUpdate": false`。

### 5.2 验证环境变量已生效

新开一个 cmd 窗口，执行：

```cmd
echo %WORKBUDDY_UPDATE_URL%
```

应输出 `http://127.0.0.1:9`。

### 5.3 实际启动验证

1. 单独启动国际版 → 应能正常打开、账号正常登录、界面是国际版。
2. 关闭国际版，单独启动国内版 → 应能正常打开、账号正常登录、界面是国内版。

### 5.4 查看更新日志确认不再强制更新

国际版日志 `%USERPROFILE%\.workbuddy-ai\logs\update\` 目录下，最新日志应包含：

```
[early-silent-startup-update] enabled=false source=product-base
Startup force auto-update: enabled=false source=product-base
```

（修复前是 `enabled=true`。）

### 5.5 确认国际版缓存重建正确

启动国际版后，检查（用记事本打开）：

```cmd
notepad "%USERPROFILE%\.workbuddy-ai\cache\acc-product-config-v3.json"
```

确认 `endpoint` 是 `https://www.workbuddy.ai`、`win32MutexName` 是 `workbuddy-ai`、`dataFolderName` 是 `.workbuddy-ai`、`startupForceAutoUpdate` 是 `false`。

---

## 6. 以后手动升级怎么做

> **重要结论**：不要用软件内的「检查更新」来升级，尤其是国际版（见 2.4 节的 platform 错位 bug）。**最安全的方式是去各自官网下载安装包、双击手动安装。**

### 6.1 下载正确的安装包

| 版本 | 下载来源 | 安装包/主程序特征 |
|---|---|---|
| 国内版 | 国内官网 workbuddy.cn / codebuddy.cn | 安装后主程序为 `WorkBuddy.exe`，目录 `WorkBuddy` |
| 国际版 | 国际官网 workbuddy.ai | 安装后主程序为 `WorkBuddyAI.exe`，目录 `WorkBuddyAI` |

> 下载时务必核对：国内版是 `WorkBuddy`，国际版是 `WorkBuddyAI`（多了 `AI`）。认准官网，不要从第三方镜像下载。

### 6.2 分别双击安装

- 国内版安装包双击 → 装进 `WorkBuddy` 目录。
- 国际版安装包双击 → 装进 `WorkBuddyAI` 目录。

两个目录独立，主程序名不同，正常不会互相覆盖。

---

## 7. 升级完成后必做清单

> **关键**：每次重新安装，安装包都会把 `product.json` 还原成默认值（`startupForceAutoUpdate` 变回 `true`），你的防护会被重置。所以装完必须重新做下面三步。

### 7.1 重新关闭启动强制更新

重复 [第 4 节步骤 2](#步骤-2修改两版-productjson-关闭启动强制更新) 的操作，把两版 `product.json` 的 `startupForceAutoUpdate` 改回 `false`。

（PowerShell 快捷版见步骤 2 的方式 B，可直接复用。）

### 7.2 确认环境变量仍在

```cmd
echo %WORKBUDDY_UPDATE_URL%
```

- 若输出 `http://127.0.0.1:9` → 无需操作。
- 若输出为空（例如重装系统后）→ 重新设置：

```cmd
setx WORKBUDDY_UPDATE_URL "http://127.0.0.1:9"
```

### 7.3 启动后确认缓存没被再次污染

分别启动两个版本后，用记事本打开国际版缓存检查：

```cmd
notepad "%USERPROFILE%\.workbuddy-ai\cache\acc-product-config-v3.json"
```

确认：
- `endpoint` = `https://www.workbuddy.ai`（不是 `.cn`）
- `startupForceAutoUpdate` = `false`
- `win32MutexName` = `workbuddy-ai`

若发现又被污染成国内版值，重新执行 [第 4 节步骤 3](#步骤-3删除国际版被污染的缓存) 删除缓存即可。

---

## 8. 遗留风险与局限

| 问题 | 说明 | 能否解决 |
|---|---|---|
| 应用内更新的 platform 错位 bug | 国际版应用内更新可能拿到国内版包 | ❌ 产品代码 bug，用户层面无法根治，只能绕开（官网下载） |
| MSIX 包 `WorkBuddyShareTarget` 同名 | 两版注册同一个系统分享包，后装者抢占 | ❌ 产品设计局限 |
| DeepLink 协议 `workbuddy` 同名 | 两版抢占同一个深链协议 | ❌ 产品设计局限 |
| 开机自启动项 `WorkBuddy.WorkBuddy` 同名 | 只能有一个版本开机自启（不需要自启动可关闭） | ✅ 关闭自启动即可 |
| 云端下发 `startupForceAutoUpdate=true` 复发 | 云端可能再次下发并污染缓存 | ✅ 环境变量 `WORKBUDDY_UPDATE_URL` 兜底拦截 |

---

## 9. 附录：关键路径与命令速查

### 关键文件路径

| 用途 | 路径 |
|---|---|
| 国内版 product.json | `%LOCALAPPDATA%\Programs\WorkBuddy\resources\app.asar.unpacked\cli\product.json` |
| 国际版 product.json | `%LOCALAPPDATA%\Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\product.json` |
| 国际版污染缓存 | `%USERPROFILE%\.workbuddy-ai\cache\acc-product-config-v3.json` |
| 共享更新器缓存 | `%LOCALAPPDATA%\@genieworkbuddy-desktop-updater\` |
| 备份目录 | `%LOCALAPPDATA%\Programs\workbuddy-fix-backup\` |

### 常用命令速查

```cmd
:: 关闭启动强制更新（改 product.json，见正文）
notepad "%LOCALAPPDATA%\Programs\WorkBuddy\resources\app.asar.unpacked\cli\product.json"
notepad "%LOCALAPPDATA%\Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\product.json"

:: 删除国际版污染缓存
del "%USERPROFILE%\.workbuddy-ai\cache\acc-product-config-v3.json"

:: 设置环境变量（废掉定时更新）
setx WORKBUDDY_UPDATE_URL "http://127.0.0.1:9"

:: 删除环境变量（恢复应用内更新，一般不推荐）
reg delete "HKCU\Environment" /v "WORKBUDDY_UPDATE_URL" /f

:: 验证环境变量
echo %WORKBUDDY_UPDATE_URL%

:: 验证 product.json 已关闭
findstr /C:"startupForceAutoUpdate" "%LOCALAPPDATA%\Programs\WorkBuddy\resources\app.asar.unpacked\cli\product.json"
findstr /C:"startupForceAutoUpdate" "%LOCALAPPDATA%\Programs\WorkBuddyAI\resources\app.asar.unpacked\cli\product.json"
```

---

## 10. 附录：WorkBuddy-Manager.bat 自动化工具

> 配套提供了一个**一键批处理脚本** `WorkBuddy-Manager.bat`，把第 4 节的全部手动修复步骤封装成菜单操作，双击即用，无需手敲命令。

### 10.1 脚本是什么

| 项 | 说明 |
|---|---|
| 文件名 | `WorkBuddy-Manager.bat` |
| 编码 | GBK（ANSI），中英双语提示 |
| 依赖 | 仅依赖 Windows 自带的 `cmd` + `powershell`，无需安装任何软件 |
| 可移植性 | 全部路径使用 `%LOCALAPPDATA%`、`%USERPROFILE%` 变量，不写死用户名，换电脑直接可用 |

### 10.2 三个功能选项

| 选项 | 功能 | 对应教程章节 |
|---|---|---|
| `[1] 修复并关闭自动升级` | 一键执行：检测 → 备份 → 关启动强制更新 → 删污染缓存 → 清理残留 → 设环境变量 | 第 4 节全部 |
| `[2] 恢复手动更新` | 删除 `WORKBUDDY_UPDATE_URL` 环境变量（带风险提示 + Y/N 确认） | 反向操作 |
| `[3] 查看关键信息` | 只读显示：两版安装状态、startupForceAutoUpdate、国际版缓存污染情况、环境变量、残留 | 第 5 节 |

### 10.3 使用方法

1. **双击运行** `WorkBuddy-Manager.bat`。
   - 若弹出 SmartScreen「Windows 已保护你的电脑」，点「更多信息 → 仍要运行」。
2. 输入 `1` / `2` / `3` / `0` 选择功能。
3. 选项 1 执行前会提示「请先关闭两个 WorkBuddy 软件」，照做即可。
4. 选项 2 删除环境变量前有 `[Y/N]` 二次确认，输入 `N` 可取消。

### 10.4 各选项的行为细节（重要）

**选项 1（修复）是幂等的，可重复运行：**
- 每次都会在 `%LOCALAPPDATA%\Programs\workbuddy-fix-backup\` 生成**带时间戳的新备份**（不覆盖旧备份）。
- 若 `product.json` 已经是 `false`，会显示 `already false`，不会重复改写。
- 每次都会删除国际版缓存（这是正常行为，下次启动国际版会自动重建正确缓存）。

**选项 2（恢复手动更新）会带来风险：**
- 删除环境变量后，**定时自动更新和手动检查更新都会恢复**（不只是「手动」）。
- 国际版应用内更新有 platform 错位 bug，可能下载国内版包覆盖自己。
- 因此脚本会先显示风险提示，且**建议的升级方式是官网下载安装包**，而不是用选项 2。

### 10.5 注意：英文 Windows 上的显示

- 脚本是 GBK 编码，在**中文 Windows** 上中英文都正常显示。
- 在**英文 Windows** 上，英文提示始终可读；中文提示可能显示为乱码，但**功能不受影响**（关键操作不依赖中文显示）。

### 10.6 与手动步骤的对应关系

| 脚本步骤 | 等价的手动命令（第 4/7/9 节） |
|---|---|
| Step 2 备份+改 product.json | `notepad` 手改 + 备份 |
| Step 3 删污染缓存 | `del "%USERPROFILE%\.workbuddy-ai\cache\acc-product-config-v3.json"` |
| Step 4 清残留 | `del ...\installer.exe` + `rd /s /q ...\workbuddy-update-x64` |
| Step 5 设环境变量 | `setx WORKBUDDY_UPDATE_URL "http://127.0.0.1:9"` |

---

## 总结

1. **根因**：两版是同产品；国际版缓存被国内版云端配置污染；代码有「platform 错位」bug 和「独立定时更新」通道。
2. **修复**：关闭两版 `product.json` 的启动强制更新 + 删除国际版污染缓存 + 清理残留包 + 设置 `WORKBUDDY_UPDATE_URL` 环境变量废掉定时更新。
3. **升级**：一律去**官网下载安装包手动安装**，不要用软件内更新；装完重做「必做清单」三步。
4. **局限**：应用内更新的 platform 错位 bug 是官方代码问题，无法从配置根治，但通过「官网下载」可以完全绕开。
5. **自动化**：配套 `WorkBuddy-Manager.bat` 一键脚本，把修复/恢复/查看封装成菜单，双击即用（见第 10 节）。

> 本文档结论均来自对安装文件、更新日志、注册表、配置文件代码逻辑和线上更新接口的实测核验。
