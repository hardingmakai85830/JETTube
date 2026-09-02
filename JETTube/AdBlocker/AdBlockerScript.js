// ==UserScript==
// @name         YouTube Ad Blocker — JET Tube (Mobile Safe)
// @version      4.0
// @description  Chặn quảng cáo YouTube mà không làm hỏng video playback
// @run-at       document-start
// ==/UserScript==

(function() {
  'use strict';

  // ================================================================
  // LAYER 1: CSS — Ẩn toàn bộ ad UI ngay lập tức
  // ================================================================

  const adCSS = document.createElement('style');
  adCSS.textContent = `
    /* Video ad overlays */
    .video-ads,
    .ytp-ad-module,
    .ytp-ad-overlay-container,
    .ytp-ad-text-overlay,
    .ytp-ad-overlay-slot,
    .ytp-ad-player-overlay,
    .ytp-ad-player-overlay-layout,
    .ytp-ad-action-interstitial,
    .ytp-ad-image-overlay,
    .ytp-ad-survey-interstitial,
    .ytp-ad-feedback-dialog-container,
    .ytp-ad-badge,
    .ytp-ad-visit-advertiser-button,
    .ytp-ad-preview-container,
    .ytp-ad-persistent-progress-bar-container,
    .ytp-ad-skip-ad-slot,
    .ytp-ad-message-slot,
    .ytp-ad-overlay-close-container,
    .ytp-ad-progress-list {
      display: none !important;
      visibility: hidden !important;
      height: 0 !important;
      opacity: 0 !important;
      pointer-events: none !important;
    }

    /* Page ads — desktop */
    #player-ads,
    #masthead-ad,
    ytd-promoted-sparkles-web-renderer,
    ytd-display-ad-renderer,
    ytd-in-feed-ad-layout-renderer,
    ytd-ad-slot-renderer,
    ytd-banner-promo-renderer,
    ytd-statement-banner-renderer,
    ytd-mealbar-promo-renderer,
    ytd-action-companion-ad-renderer,
    ytd-companion-slot-renderer,
    ytd-promoted-video-renderer,
    ytd-search-pyv-renderer,
    ytd-rich-item-renderer:has(ytd-ad-slot-renderer),
    ytd-rich-section-renderer:has(ytd-ad-slot-renderer),
    #offer-module {
      display: none !important;
    }

    /* Page ads — mobile */
    ytm-promoted-sparkles-web-renderer,
    ytm-companion-slot,
    .ytm-promoted-sparkles-web-renderer,
    .ytm-companion-ad-renderer,
    ytm-promoted-sparkles-text-search-renderer,
    [class*="companion-ad"] {
      display: none !important;
    }

    /* Anti-adblock popup */
    ytd-enforcement-message-view-model,
    tp-yt-iron-overlay-backdrop[opened] {
      display: none !important;
    }
  `;
  (document.head || document.documentElement).appendChild(adCSS);

  // ================================================================
  // LAYER 2: Skip Video Ads — Nhảy đến cuối + bấm Skip
  // Chỉ xử lý UI, KHÔNG chỉnh sửa player data
  // ================================================================

  function skipVideoAd() {
    const player = document.querySelector('.html5-video-player');
    if (!player) return;

    const isAd = player.classList.contains('ad-showing') ||
                 player.classList.contains('ad-interrupting');
    if (!isAd) return;

    const video = player.querySelector('video');
    if (video) {
      // Nhảy đến cuối ad
      if (video.duration && isFinite(video.duration) && video.duration > 0) {
        video.currentTime = video.duration;
      }
      try { video.playbackRate = 16; } catch(e) {}
      video.muted = true;
    }

    // Click skip buttons
    const skipSelectors = [
      '.ytp-skip-ad-button',
      '.ytp-ad-skip-button',
      '.ytp-ad-skip-button-modern',
      'button.ytp-ad-skip-button-modern',
      '.ytp-ad-skip-button-slot button',
      '.ytp-ad-skip-button-container button',
      '[id^="skip-button"]',
      '.ytp-ad-overlay-close-button',
    ];
    skipSelectors.forEach(sel => {
      document.querySelectorAll(sel).forEach(b => {
        try { b.click(); } catch(e) {}
      });
    });
  }

  // ================================================================
  // LAYER 3: Remove Page Ad Elements
  // ================================================================

  function removePageAds() {
    const adSelectors = [
      '#player-ads', '#masthead-ad',
      'ytd-promoted-sparkles-web-renderer',
      'ytd-display-ad-renderer',
      'ytd-in-feed-ad-layout-renderer',
      'ytd-ad-slot-renderer',
      'ytd-banner-promo-renderer',
      'ytd-action-companion-ad-renderer',
      'ytd-companion-slot-renderer',
      'ytm-promoted-sparkles-web-renderer',
      'ytm-companion-slot',
    ];
    document.querySelectorAll(adSelectors.join(',')).forEach(el => el.remove());
  }

  // ================================================================
  // LAYER 4: Anti-Adblock Bypass
  // ================================================================

  function bypassAntiAdblock() {
    document.querySelectorAll('ytd-enforcement-message-view-model').forEach(el => el.remove());
    document.querySelectorAll('tp-yt-paper-dialog').forEach(popup => {
      const text = (popup.textContent || '').toLowerCase();
      if (text.includes('ad blocker') || text.includes('adblock') || text.includes('allow ads')) {
        popup.remove();
        document.querySelectorAll('tp-yt-iron-overlay-backdrop').forEach(b => b.remove());
        const v = document.querySelector('video');
        if (v && v.paused) v.play().catch(() => {});
      }
    });
    document.body.style.removeProperty('overflow');
    document.documentElement.style.removeProperty('overflow');
  }

  // ================================================================
  // MAIN LOOP — Chạy mỗi 500ms
  // ================================================================

  function adBlockLoop() {
    skipVideoAd();
    removePageAds();
    bypassAntiAdblock();
  }

  // Chờ DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      adBlockLoop();
      setInterval(adBlockLoop, 500);
    });
  } else {
    adBlockLoop();
    setInterval(adBlockLoop, 500);
  }

  // MutationObserver — phản ứng nhanh khi ad xuất hiện
  const observer = new MutationObserver(() => {
    skipVideoAd();
  });

  function startObserver() {
    const playerEl = document.querySelector('.html5-video-player');
    if (playerEl) {
      observer.observe(playerEl, { attributes: true, attributeFilter: ['class'] });
    } else {
      // Thử lại sau 1 giây
      setTimeout(startObserver, 1000);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startObserver);
  } else {
    startObserver();
  }

})();
