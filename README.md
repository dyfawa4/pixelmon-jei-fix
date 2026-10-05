# Pixelmon JEI Connection Fix

一个用于 Minecraft 1.16.5 的小型 Forge 兼容补丁，尝试解决 Pixelmon 9.1.12 / 9.1.13 与 JEI 共存时，配方 **「＋ / 转移物品」** 按钮误报 **「服务器必须安装 JEI」** 的问题。

当前版本：`1.0.0`。当前状态：**已由用户在目标整合包的 Java 11 单人模式中确认问题修复；独立服务器及代理切服尚未验证。**

下载：[v1.0.0 发布页](https://github.com/dyfawa4/pixelmon-jei-fix/releases/tag/v1.0.0) · [补丁 JAR](https://github.com/dyfawa4/pixelmon-jei-fix/releases/download/v1.0.0/pixelmon-jei-fix-1.16.5-1.0.0.jar) · [补丁与源码分享包](https://github.com/dyfawa4/pixelmon-jei-fix/releases/download/v1.0.0/pixelmon-jei-fix-1.0.0-share.zip)

整合包作者只需将补丁 JAR 加入客户端实例的 `mods`；开发者可使用本仓库源码复现构建。

## 目录

- [问题表现](#问题表现)
- [兼容范围](#兼容范围)
- [原因与修复方式](#原因与修复方式)
- [安装](#安装)
- [测试步骤](#测试步骤)
- [日志与排错](#日志与排错)
- [卸载与撤回](#卸载与撤回)
- [源码与构建](#源码与构建)
- [验证状态](#验证状态)
- [常见问题](#常见问题)
- [参考资料与许可](#参考资料与许可)

## 问题表现

JEI 的物品列表和配方查看功能正常，但打开工作台或背包合成界面后，配方的「＋」按钮无法将背包材料自动排入合成格，鼠标悬停时显示：

```text
转移物品
服务器必须安装JEI。
```

英文提示为 `The server must have JEI installed`。在该兼容问题中，即使玩的是单人存档，也可能出现这条提示。

Pixelmon 的官方问题记录中，维护者确认了 JEI + Pixelmon 的冲突，并有用户反馈 9.1.13 仍然存在同类问题。本补丁是针对识别状态的本地修复尝试，并非 Pixelmon 或 JEI 官方发布的补丁。

## 兼容范围

| 组件 | 声明兼容范围 | 当前构建所用环境 |
| --- | --- | --- |
| Minecraft | 1.16.5 | 1.16.5 |
| Forge | 36.2.x，低于 37 | 36.2.42 |
| Pixelmon | 9.1.12 / 9.1.13 | 文件名为 9.1.13 的版本 |
| JEI | **7.8.1.1018** | 7.8.1.1018 |
| Java 运行环境 | Java 11 | 使用 JDK 11，输出 Java 11 字节码 |

兼容范围写入了 `resources/META-INF/mods.toml`。它是加载约束，不能替代实际游戏测试。其他 JEI 版本暂未声明兼容。

请使用 Java 11 启动目标整合包。该整合包仅适配 Java 11，本项目不声明 Java 8、17 或其他运行版本的整合包兼容性。补丁的字节码目标为 Java 11（class major version 55）。

分析所用的 Pixelmon 9.1.13 JAR 内，模组元数据仍声明为 `9.1.12`，补丁的版本范围覆盖这两种标识。

补丁的事件监听仅在客户端加载。单人游戏将补丁放入当前实例的 `mods` 即可；连接独立服务器时，将补丁安装在客户端，服务器仍需实际安装兼容的 JEI 才能支持其配方转移功能。

## 原因与修复方式

### 本地分析结果

这份 Pixelmon JAR 内包含 `Client Reset Packet`。其 `MixinFMLHandshakeHandler` 替换了 Forge 的 `handleServerModListOnClient`，本地字节码检查显示，该实现保存了服务端模组和通道信息，却没有调用 Forge 原本的 `NetworkRegistry.validateClientChannels`。

JEI 7.8.1.1018 在注册网络通道时，依靠客户端通道检查回调执行 `ServerInfo.onConnectedToServer(...)`，更新「服务端是否有 JEI」的状态。上述握手替换跳过了该回调，与当前误报相吻合。

这一具体机制来自本地 JAR 分析；官方问题记录确认的是兼容冲突，并未证明所有出现相同提示的整合包都由同一个原因引起。

### 补丁做了什么

1. 以 `LOWEST` 优先级监听客户端 `LoggedInEvent`。
2. 通过 Forge 的 `NetworkHooks.getConnectionData(...)` 读取握手保存的连接数据。
3. 检查服务端通道列表中是否存在 `jei:channel`。
4. 将检查结果传给 JEI 的 `ServerInfo.onConnectedToServer(...)`，恢复识别状态。
5. 客户端退出世界时将状态清空，避免沿用上一个世界的判定。

如果连接数据为空，补丁保留 JEI 原有判定并写入警告日志。外部服务器缺少 `jei:channel` 时，判定仍为 `false`。

补丁不新增物品、方块或配方，不修改世界存档，不替换 Pixelmon / JEI 的原始 JAR，也没有自定义网络通道。它只恢复 JEI 的连接识别；实际的材料移动仍由 JEI 原来的逻辑处理。

## 安装

1. 完全退出 Minecraft。
2. 将 `pixelmon-jei-fix-1.16.5-1.0.0.jar` 放入**当前整合包实例**的 `mods` 文件夹。
3. 确认文件夹中只有一份该补丁，并已安装兼容范围内的 Forge、Pixelmon 和 JEI。
4. 从启动器重新启动游戏。

HMCL 开启版本隔离时，应使用 `.minecraft/versions/<实例名称>/mods`，而不是根目录的 `.minecraft/mods`。

常见实例布局：

```text
<游戏根目录>/.minecraft/versions/<实例名称>/mods/pixelmon-jei-fix-1.16.5-1.0.0.jar
```

正在运行的游戏不会热加载补丁或其更新，必须完全退出后重启。

## 测试步骤

建议先在测试存档中验证，保持生存模式。只看到提示消失不足以证明成功，还需确认材料移动和产物领取。

| 测试 | 操作 | 预期结果 |
| --- | --- | --- |
| 背包 2×2 合成 | 背包放一块原木，查看对应木板配方，点击「＋」 | 原木进入合成格，能取出木板 |
| 工作台 3×3 合成 | 背包放足够木板，打开工作台，查看箱子配方并点击「＋」 | 木板排入正确格子，能取出箱子 |
| 材料不足 | 在缺少材料时查看配方 | 显示材料不足，而非误报未安装 JEI |
| 宝可梦配方 | 使用材料齐全、由普通工作台支持的宝可梦物品配方 | 材料转移且产物可领取 |
| 重新进入存档 | 返回主菜单，再进入测试存档重复操作 | 配方转移仍正常，日志重新记录识别结果 |

如果测试独立服务器，也应分别验证安装 JEI 和未安装 JEI 的情况。未安装 JEI 的服务器应继续得到未安装提示。

## 日志与排错

日志通常位于当前实例的 `logs/latest.log`。进入世界后搜索 `PixelmonJeiFix`。

### 成功读取到 JEI 通道

```text
[PixelmonJeiFix] Restored JEI server detection from negotiated channels: true
```

这表示识别已更新为「服务端有 JEI」，仍需按测试表确认实际合成行为。

### 服务端通道列表没有 JEI

```text
[PixelmonJeiFix] Restored JEI server detection from negotiated channels: false
```

连接独立服务器时，先检查服务端 JEI 是否加载。单人存档出现该结果时，说明握手保存的通道信息与预期不符，需要进一步分析；补丁不会强制改为 `true`。

### 没有连接元数据

```text
[PixelmonJeiFix] No negotiated channel metadata; kept original JEI detection
```

补丁已收到进入世界事件，但连接数据为空。请保留当次日志和准确版本信息，继续定位其他握手改动或事件时序问题。

### 没有任何补丁日志

先确认已经进入世界、安装路径是实际启动的实例、补丁只有一份，并检查启动日志中是否有依赖版本错误。日志缺失也可能表示模组没有加载或事件监听没有触发。

### 启动时提示无法加载 ResourcePackInfo

第一版打包遗漏了 `pack.mcmeta`，可导致类似警告：

```text
Couldn't get pack info ... 'pack.mcmeta'
```

当前包已补充根目录 `pack.mcmeta`，其中 `pack_format` 为 `6`。重新启动后的日志中已未出现该资源元数据警告。若仍出现，请确认使用的是重新打包后的文件。

### 提示消失，但材料仍无法转移

确认材料在玩家背包中、当前容器支持该配方，以及该配方有可用的转移处理器。再检查日志是否有 JEI 的数据包错误。本补丁只处理服务端识别，不修复所有容器或配方的兼容问题。

反馈时提供 Minecraft / Forge / Pixelmon / JEI / 补丁版本、单人或联机模式、容器与配方名称、复现步骤，以及相关日志片段。公开分享前，请删去令牌、私人服务器地址和其他个人信息。

## 卸载与撤回

1. 完全退出游戏。
2. 将 `pixelmon-jei-fix-1.16.5-1.0.0.jar` 移到 `mods` 文件夹以外。
3. 重启游戏。

补丁不写入持久配置或世界数据，卸载后恢复 JEI 原有识别流程。若自行保留旧包，请存放在 mods 之外，**不要将两份补丁同时放进 mods**。

## 源码与构建

项目结构：

```text
pixelmon-jei-fix/
├── README.md
├── LICENSE
├── .gitignore
├── 使用说明.md
├── build.ps1
├── src/local/jeifix/PixelmonJeiFix.java
├── resources/
│   ├── META-INF/mods.toml
│   ├── META-INF/LICENSE
│   └── pack.mcmeta
├── build/                                # 隔离的编译输出，忽略提交
└── dist/                                 # JAR 和 SHA256SUMS.txt，忽略提交
```

玩家使用已构建的 JAR 时无需安装开发工具。开发者重新构建需要：

- Windows PowerShell 5.1 或更新版本。
- 推荐使用 JDK 11，包含 `javac` 和 `jar`。更高版本编译器可以使用 `--release 11` 构建，但这不代表整合包可以改用更高版本 Java 运行。
- 已安装并至少启动过一次的 Minecraft 1.16.5 / Forge 36.2.x 客户端，以及其完整 libraries 目录。
- JEI 7.8.1.1018 JAR。

构建脚本不包含固定的盘符、用户名、启动器、实例名称或 JDK 安装位置。它从调用参数读取依赖路径，优先使用显式 JDK 参数，其次使用 `JAVA_HOME`，最后从 `PATH` 查找工具。

以下路径均为占位符，请填写自己机器上的实际路径；项目可以放在任意目录，无需靠近 `.minecraft`：

```powershell
& .\build.ps1 `
  -LibrariesDirectory '<完整 libraries 目录>' `
  -JeiJar '<JEI 7.8.1.1018 JAR 的完整路径>'
```

| 参数 | 必填 | 用途 |
| --- | --- | --- |
| `-LibrariesDirectory` | 是 | Minecraft / Forge 的完整依赖目录 |
| `-JeiJar` | 是 | 编译所用 JEI JAR 的路径，可带中文或空格 |
| `-ForgeClientJar` | 否 | 指定经过 Forge 修补的客户端 JAR；缓存存在多个匹配版本时必填 |
| `-JdkDirectory` | 否 | JDK 根目录，下面应有 `bin/javac.exe` 和 `bin/jar.exe` |
| `-OutputDirectory` | 否 | 输出目录，默认项目内 `dist` |

不传 `-ForgeClientJar` 时，脚本会在 libraries 下查找 `forge-1.16.5-36.2.*-client.jar`。匹配数量不是一份时会停止，要求明确指定，不会猜测使用哪个版本。

脚本使用 `javac --release 11 -proc:none` 编译，将 Java 类、模组元数据、资源元数据和许可文本打包为 JAR。输出文件名中的补丁版本从 `mods.toml` 读取，`dist/SHA256SUMS.txt` 记录对应校验值。

构建过程中不会下载依赖、安装模组或修改游戏设置。构建完成后，在游戏退出时将输出 JAR 复制到实际实例的 mods。当前构建脚本面向 Windows；生成的补丁 JAR 不含 Windows API，可供其他系统上的兼容 Forge 客户端测试。

### 分享文件

给普通玩家分享输出 JAR，并附上 README 或使用说明即可。分享源码时保留 `src`、`resources`、`build.ps1`、README 和 LICENSE；不需要附带 Minecraft、Pixelmon、JEI、Forge 的依赖 JAR、整合包、个人存档或游戏日志。

## 验证状态

| 项目 | 当前状态 |
| --- | --- |
| Java 11 目标编译 | 已通过 |
| 模组元数据与事件监听字节码检查 | 已通过 |
| JAR 资源元数据检查 | 已通过，包内包含 pack.mcmeta |
| 用户机器安装 | 按安装步骤放入实际启动实例的 mods |
| 无资源元数据警告启动 | 当前重启日志未出现该警告 |
| JEI 服务端识别 | 当前进入世界日志记录为 true |
| 单人模式问题 | 用户确认修复完成，截图中未安装 JEI 提示已消失 |
| 各容器、各配方和全部测试用例 | 尚未逐项验收 |
| 独立服务器、代理切服兼容性 | 尚未验证 |

验证反馈日期：2026-10-05。确认环境为 Minecraft 1.16.5、Forge 36.2.42、Pixelmon 文件版本 9.1.13、JEI 7.8.1.1018、Java 11。该结论来自用户游戏内反馈和当前日志，不代表对所有整合包完成兼容性测试。

## 常见问题

**为什么单人游戏也提示服务器必须安装 JEI？**

单人游戏同样有内置服务端。JEI 的自动填料需要正确识别服务端能力，握手识别状态错误时也会显示这条提示。

**需要删除 JEI，或者换成 REI 吗？**

使用本补丁时保留 JEI。替换配方查看模组是另一种方案，需要单独评估整合包的插件兼容性。

**只要出现同样的提示，都适用这个补丁吗？**

不一定。服务端确实没装 JEI、JEI 版本不兼容、其他握手修改等，也可能产生类似表现。

**能够绕过服务器权限或开启作弊吗？**

补丁不会更改权限设置或开放作弊。它根据实际服务端通道恢复 JEI 的识别状态；JEI 原有的服务端权限检查仍然存在。

**会修复整合包中的其他 JEI 报错吗？**

没有覆盖。例如拼音搜索模组 `jecharacters` 的 `opcodes is not defined` 转换错误属于不同链路。

## 参考资料与许可

- [Pixelmon 官方问题 #22036：单人模式 JEI 无法转移物品](https://pixelmonmod.com/tracker.php?p=2&t=22036)
- [Pixelmon 官方问题 #22995：9.1.12 / 9.1.13 同类问题与旧版本支持状态](https://pixelmonmod.com/tracker.php?p=2&t=22995)
- [JEI 问题 #3685：1.16.5 单人模式提示服务端未安装 JEI](https://github.com/mezz/JustEnoughItems/issues/3685)
- [Forge Client Reset Packet 项目](https://github.com/Just-Chaldea/Forge-Client-Reset-Packet)
- [JEI 源码项目](https://github.com/mezz/JustEnoughItems)

补丁独立实现，未打包 Pixelmon、Minecraft、JEI 或 Forge 的类与资产。补丁源码按 [MIT License](LICENSE) 分享，许可文本也包含在 JAR 的 `META-INF/LICENSE`。依赖项目的代码和资源遵循各自许可。
