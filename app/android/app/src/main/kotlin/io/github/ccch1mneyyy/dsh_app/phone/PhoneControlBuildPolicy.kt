package io.github.ccch1mneyyy.dsh_app.phone

import io.github.ccch1mneyyy.dsh_app.BuildConfig

/**
 * 免审批定制的唯一编译期入口（`-PunrestrictedPhoneControl=true`）。
 *
 * 这里只产生“有效策略”，不改写磁盘上的用户 JSON：设置页仍是用户原来的名单和解除限制，
 * 回退到标准构建时行为原样恢复。标准构建 [unrestricted] 恒为 false，所有调用点保持上游语义。
 */
internal object PhoneControlBuildPolicy {
    val unrestricted: Boolean
        get() = BuildConfig.UNRESTRICTED_PHONE_CONTROL

    /**
     * 定制构建的有效策略：不碰名单、每次写入确认名单清空，硬规则三项全部解除。
     * 只放宽“是否询问/拒绝”，任务归属、暂停、锁屏、坐标与上下文校验仍由调用方保留。
     */
    fun effectivePolicies(base: PhonePolicies): PhonePolicies {
        if (!unrestricted) return base
        return base.copy(
            denyPackages = emptyList(),
            confirmEveryWritePackages = emptyList(),
            // ALWAYS 让状态栏和 waived() 与免审批状态一致；真正的放行在各入口的
            // unrestricted 分支，即使这里是 ASK 也不会再产生确认卡。
            confirmMode = ConfirmMode.ALWAYS,
            unlocks = PhoneUnlocks(
                systemPages = true,
                secretFields = true,
                ownApp = true,
            ),
        )
    }
}
