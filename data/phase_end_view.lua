return {
    reducedMotion = false, sabotageDuration = 0.65, hitDuration = 0.6,
    hitTime = 0.22, destructionHold = 0.3, fadeDuration = 0.18,
    width = 620, height = 360, artSize = 192,
    securityIcon = "assets/images/ui_elements/security_icon.png",
    background = { 0.025, 0.045, 0.045, 1 }, text = { 0.95, 0.96, 1, 1 },
    securityColor = { 0.2, 0.85, 0.9, 1 }, damageColor = { 1, 0.36, 0.24, 1 },
    labels = { security = "JACL SECURITY", blocked = "MILL BLOCKED", health = "HEALTH",
        destroyed = "DESTROYED", noTarget = "NO LIVING SILENCER", sabotage = "SABOTAGE" },
    sources = {
        control = { title = "ALLIED CONTROL / TURN START", cause = "CONTROL MILL" },
        silencer = { title = "SILENCER MILLING", cause = "UNBLOCKED ATTEMPTS" },
        glory = { title = "GLORY MILLING", cause = "GLORY PRESSURE" },
    },
}
