package com.keepwan.kinetic_player.gsy

import android.graphics.Color
import com.shuyu.gsyvideoplayer.render.effect.AutoFixEffect
import com.shuyu.gsyvideoplayer.render.effect.BarrelBlurEffect
import com.shuyu.gsyvideoplayer.render.effect.BlackAndWhiteEffect
import com.shuyu.gsyvideoplayer.render.effect.BrightnessEffect
import com.shuyu.gsyvideoplayer.render.effect.ContrastEffect
import com.shuyu.gsyvideoplayer.render.effect.CrossProcessEffect
import com.shuyu.gsyvideoplayer.render.effect.DocumentaryEffect
import com.shuyu.gsyvideoplayer.render.effect.DuotoneEffect
import com.shuyu.gsyvideoplayer.render.effect.FillLightEffect
import com.shuyu.gsyvideoplayer.render.effect.GammaEffect
import com.shuyu.gsyvideoplayer.render.effect.GaussianBlurEffect
import com.shuyu.gsyvideoplayer.render.effect.GrainEffect
import com.shuyu.gsyvideoplayer.render.effect.GreyScaleEffect
import com.shuyu.gsyvideoplayer.render.effect.HueEffect
import com.shuyu.gsyvideoplayer.render.effect.InvertColorsEffect
import com.shuyu.gsyvideoplayer.render.effect.LamoishEffect
import com.shuyu.gsyvideoplayer.render.effect.NoEffect
import com.shuyu.gsyvideoplayer.render.effect.OverlayEffect
import com.shuyu.gsyvideoplayer.render.effect.PosterizeEffect
import com.shuyu.gsyvideoplayer.render.effect.SampleBlurEffect
import com.shuyu.gsyvideoplayer.render.effect.SaturationEffect
import com.shuyu.gsyvideoplayer.render.effect.SepiaEffect
import com.shuyu.gsyvideoplayer.render.effect.SharpnessEffect
import com.shuyu.gsyvideoplayer.render.effect.TemperatureEffect
import com.shuyu.gsyvideoplayer.render.effect.TintEffect
import com.shuyu.gsyvideoplayer.render.effect.VignetteEffect
import com.shuyu.gsyvideoplayer.render.view.GSYVideoGLView

/** Maps effect id / name to GSY GL shader effects (requires GLSURFACE render type). */
object GsyEffectRegistry {
    val effectNames: List<String> =
        listOf(
            "none",
            "autoFix",
            "barrelBlur",
            "blackAndWhite",
            "brightness",
            "contrast",
            "crossProcess",
            "documentary",
            "duotone",
            "fillLight",
            "gamma",
            "gaussianBlur",
            "grain",
            "greyScale",
            "hue",
            "invertColors",
            "lamoish",
            "overlay",
            "posterize",
            "sampleBlur",
            "saturation",
            "sepia",
            "sharpness",
            "temperature",
            "tint",
            "vignette",
        )

    fun resolve(name: String): GSYVideoGLView.ShaderInterface =
        when (name.lowercase()) {
            "autofix" -> AutoFixEffect(1f)
            "barrelblur" -> BarrelBlurEffect()
            "blackandwhite" -> BlackAndWhiteEffect()
            "brightness" -> BrightnessEffect(0.2f)
            "contrast" -> ContrastEffect(1.5f)
            "crossprocess" -> CrossProcessEffect()
            "documentary" -> DocumentaryEffect()
            "duotone" -> DuotoneEffect(Color.CYAN, Color.MAGENTA)
            "filllight" -> FillLightEffect(0.5f)
            "gamma" -> GammaEffect(1.5f)
            "gaussianblur" -> GaussianBlurEffect(1f)
            "grain" -> GrainEffect(0.5f)
            "greyscale" -> GreyScaleEffect()
            "hue" -> HueEffect(90f)
            "invertcolors" -> InvertColorsEffect()
            "lamoish" -> LamoishEffect()
            "overlay" -> OverlayEffect()
            "posterize" -> PosterizeEffect()
            "sampleblur" -> SampleBlurEffect()
            "saturation" -> SaturationEffect(1.5f)
            "sepia" -> SepiaEffect()
            "sharpness" -> SharpnessEffect(1f)
            "temperature" -> TemperatureEffect(1f)
            "tint" -> TintEffect(Color.argb(80, 255, 0, 0))
            "vignette" -> VignetteEffect(0.5f)
            else -> NoEffect()
        }
}
