package com.fixbyte.floatingvolume.style

import com.fixbyte.floatingvolume.WidgetSettings

/** Creates the correct [ButtonStyleApplier] for the current widget settings. */
object StyleFactory {

    fun create(
        style:     WidgetSettings.Style,
        isNight:   Boolean,
        colorMode: WidgetSettings.ColorMode,
    ): ButtonStyleApplier = when (style) {
        WidgetSettings.Style.ANDROID        -> AndroidStyleApplier(isNight, colorMode)
        WidgetSettings.Style.ANDROID_12     -> Android12StyleApplier()
        WidgetSettings.Style.IOS            -> IosStyleApplier()
        WidgetSettings.Style.MIUI           -> MiuiStyleApplier()
        WidgetSettings.Style.SAMSUNG_ONE_UI -> OneUiStyleApplier()
        WidgetSettings.Style.RGB_AURORA     -> RgbAuroraStyleApplier()
        WidgetSettings.Style.RGB_NEON       -> RgbNeonStyleApplier()
        WidgetSettings.Style.COSMIC         -> CosmicStyleApplier()
        WidgetSettings.Style.LAVA           -> LavaStyleApplier()
        WidgetSettings.Style.CARDS          -> CardsStyleApplier(isNight)
        WidgetSettings.Style.GLACIER        -> GlacierStyleApplier()
        WidgetSettings.Style.MATRIX         -> MatrixStyleApplier()
        WidgetSettings.Style.RETROWAVE      -> RetrowaveStyleApplier()
    }
}
