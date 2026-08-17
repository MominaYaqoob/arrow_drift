package com.sid.arrowdrift.puzzlegame

import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.RatingBar
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class ArrowNativeAdFactory(
    private val inflater: LayoutInflater,
) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: Map<String, Any>?,
    ): NativeAdView {
        val isMedium = customOptions?.get("format")?.toString() == "medium"
        val isDark = when (val raw = customOptions?.get("isDark")) {
            is Boolean -> raw
            else -> raw?.toString() == "true"
        }
        val layoutId = if (isMedium) R.layout.native_ad_medium else R.layout.native_ad_small
        val adView = inflater.inflate(layoutId, null) as NativeAdView

        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        val body = adView.findViewById<TextView>(R.id.ad_body)
        val cta = adView.findViewById<TextView>(R.id.ad_call_to_action)
        val icon = adView.findViewById<ImageView>(R.id.ad_app_icon)
        val stars = adView.findViewById<RatingBar>(R.id.ad_stars)
        val badge = adView.findViewById<TextView>(R.id.ad_attribution)
        val media = adView.findViewById<MediaView>(R.id.ad_media)

        val primary = if (isDark) Color.WHITE else Color.parseColor("#0E1726")
        val secondary = if (isDark) Color.parseColor("#9AA5B5") else Color.parseColor("#6B7280")
        val badgeColor = if (isDark) Color.parseColor("#2EC4A6") else Color.parseColor("#0F8F7A")

        headline.setTextColor(primary)
        body.setTextColor(secondary)
        badge.setTextColor(badgeColor)

        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = cta
        adView.iconView = icon
        adView.starRatingView = stars
        if (media != null) {
            adView.mediaView = media
        }

        headline.text = nativeAd.headline

        val bodyText = nativeAd.body
        if (bodyText.isNullOrBlank()) {
            body.visibility = View.GONE
        } else {
            body.visibility = View.VISIBLE
            body.text = bodyText
        }

        val ctaText = nativeAd.callToAction
        if (ctaText.isNullOrBlank()) {
            cta.visibility = View.GONE
        } else {
            cta.visibility = View.VISIBLE
            cta.text = ctaText
        }

        val adIcon = nativeAd.icon
        if (adIcon == null) {
            icon.visibility = View.GONE
        } else {
            icon.visibility = View.VISIBLE
            icon.setImageDrawable(adIcon.drawable)
            icon.clipToOutline = true
        }

        val rating = nativeAd.starRating
        if (rating == null || rating <= 0) {
            stars.visibility = View.GONE
        } else {
            stars.visibility = View.VISIBLE
            stars.rating = rating.toFloat()
        }

        if (media != null) {
            val content = nativeAd.mediaContent
            if (content == null) {
                media.visibility = View.GONE
            } else {
                media.visibility = View.VISIBLE
                media.mediaContent = content
            }
        }

        adView.setNativeAd(nativeAd)
        return adView
    }
}
