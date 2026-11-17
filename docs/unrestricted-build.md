# 免审批定制构建（unrestricted）

本分支在 `v1.1.0` 之上加了一个编译期开关 `UNRESTRICTED_PHONE_CONTROL`：打开后 DSH Go 的手机操控不再弹
「允许一次 / 本轮允许 / 取消」，也不再按不碰名单、系统页、密码框和微信每写确认拦截。**标准构建行为不变**。

## 怎么构建

```bash
# 1) 运行时（只跑一次，之后增量）——必须在 Linux x86_64 上
bash runtime/build-runtime.sh arm64-v8a

# 2) 定制 APK
bash tooling/build-unrestricted-apk.sh
```

产物：`app/build/app/outputs/flutter-apk/app-arm64-release.apk`。

`tooling/build-unrestricted-apk.sh` 只设置：

- `ORG_GRADLE_PROJECT_unrestrictedPhoneControl=true`
- `ORG_GRADLE_PROJECT_dshUnsignedRelease=true`（仅 `DSH_UNSIGNED=1`）
- `DSH_BETA_TOKEN_FILE=`（禁用官方 beta 通道）
- `DSH_RELEASE_REPO`/`DSH_UPDATE_REPO` 指向定制 fork，并把官方镜像/feed 全部置空

## 签名（决定能否保留数据）

- 第一次从官方版换成定制版时，签名不一致的包**不能**覆盖安装。只有同签名，或已 Root 设备用
  CorePatch 临时允许跨签名，才能 `adb install -r` 保留数据。
- 定制版之间必须始终使用**同一把**私钥；换钥就是又一次跨签名。
- 私钥、`key.properties` 不进 Git、不进 Release、不进日志。

```bash
# 生成一次，之后一直用这把
keytool -genkeypair -v -keystore ~/keys/dsh-go-unrestricted.jks \
  -alias dshgo-unrestricted -keyalg RSA -keysize 4096 -validity 10000

# app/android/key.properties（gitignored）
cat > app/android/key.properties <<EOF
storeFile=$HOME/keys/dsh-go-unrestricted.jks
storePassword=...
keyAlias=dshgo-unrestricted
keyPassword=...
EOF

# 读回验证
apksigner verify --verbose --min-sdk-version 26 --print-certs custom.apk
```

## 改动点

| 文件 | 作用 |
|---|---|
| `app/android/app/build.gradle.kts` | `buildConfig` + `UNRESTRICTED_PHONE_CONTROL`；可选不签名 release |
| `phone/PhoneControlBuildPolicy.kt` | 唯一编译期入口；有效策略清空名单、解除三项硬规则 |
| `phone/PhoneControl.kt` | `policies()` 发布有效策略；设置页仍读写原始 JSON |
| `phone/SafetyGate.kt` | `checkRead/checkOpen/checkWrite/checkVisual/confirmationOnce` 集中放行 |
| `phone/PhoneCore.kt` | `focusText` 密码分支、`afterSystem` 人工核对、Shell 透传 |
| `phone/PhoneAndroidShell.kt` | 去掉逐条审批，保留后端/UID/参数/超时校验 |
| `phone/PhoneGuest.kt` + `runtime/GuestSetup.kt` | 另一套 AGENTS.md 文案，工具 schema 不变 |
| `phone/PhoneToolCatalog.kt` | 工具说明按开关二选一，名称/参数/顺序不变 |
| `phone/a11y/MainScreenDriver.kt` | OCR 不再因自身/系统页被挡 |
| `phone/background/*` | `allowSensitive` 跳过敏感词；秘密字段仍拒绝 |
| `app/lib/update/update_config.dart` | `DSH_UPDATE_REPO` 可注入，默认仍是官方 |
| `tooling/release_assets.py` | `DSH_RELEASE_REPO` 可注入 |

**保留**：任务 owner、暂停/停止、锁屏、无障碍状态、屏幕 ID/坐标/时效/上下文校验、Shell 参数与真实 UID、
秘密字段截图保护、日志脱敏。这些不是审批，删掉会让操作失控。

## 测试

```bash
cd app/android && ./gradlew :app:testArm64DebugUnitTest
cd ../.. && flutter analyze --no-pub && flutter test test/phone test/update
```

新增用例见 `UnrestrictedPhoneControlTest.kt`；标准模式的旧断言不改，继续证明默认行为没变。
