#!/usr/bin/env bash
# 免审批定制构建入口。只负责三件事：打开编译期开关、把更新源指向定制 fork、委托上游
# tooling/build-apk.sh（不复制它的构建逻辑）。普通上游构建不受影响。
#
#   tooling/build-unrestricted-apk.sh                 # release, arm64，使用 key.properties 签名
#   DSH_UNSIGNED=1 tooling/build-unrestricted-apk.sh  # 产物不签名，交给独立签名 job
#   DSH_FLAVOR=x64 tooling/build-unrestricted-apk.sh  # 模拟器
#   DSH_RELEASE_REPO=owner/repo tooling/build-unrestricted-apk.sh
#
# 依赖：runtime/out/arm64-v8a 已由 runtime/build-runtime.sh 生成；flutter、JDK 17 在 PATH。
# 签名：默认读 app/android/key.properties（同一把定制私钥，跨版本一致）。没有 key.properties
# 时必须显式 DSH_UNSIGNED=1，绝不静默回落到 debug 签名——那会让下一次更新又变成跨签名。
set -euo pipefail

ROOT=$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
flavor=${DSH_FLAVOR:-arm64}
repo=${DSH_RELEASE_REPO:-soyoung5565/dsh-Go}
unsigned=${DSH_UNSIGNED:-0}

case "$flavor" in
  arm64 | x64) ;;
  *) echo "build-unrestricted-apk: DSH_FLAVOR is arm64 or x64: $flavor" >&2; exit 1 ;;
esac

if [[ ! -f $ROOT/app/android/key.properties && $unsigned != 1 ]]; then
  cat >&2 <<'EOF'
build-unrestricted-apk: app/android/key.properties 不存在。
定制版必须用一把固定的私钥签名，否则下一次更新又会变成跨签名（只能清数据）。
先创建 keystore 和 key.properties，或显式 DSH_UNSIGNED=1 交给独立签名 job。
EOF
  exit 1
fi

export ORG_GRADLE_PROJECT_unrestrictedPhoneControl=true
[[ $unsigned == 1 ]] && export ORG_GRADLE_PROJECT_dshUnsignedRelease=true
# 不读内测通道令牌：公开构建绝不携带 beta feed。
export DSH_BETA_TOKEN_FILE=
export DSH_RELEASE_REPO=$repo

echo "unrestricted build · flavor=$flavor · update repo=$repo · unsigned=$unsigned"
exec bash "$ROOT/tooling/build-apk.sh" -f "$flavor" --keep-daemon -- \
  "--dart-define=DSH_UPDATE_REPO=$repo" \
  "--dart-define=DSH_UPDATE_MIRROR=" \
  "--dart-define=DSH_UPDATE_FEED=" \
  "--dart-define=DSH_UPDATE_MIRRORS=" \
  "$@"
