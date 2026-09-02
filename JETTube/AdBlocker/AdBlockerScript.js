// ==UserScript==
// @name         YouTube Ad Blocker Pro — by JET ⚡
// @namespace    com.jet.youtube.adblock
// @version      3.0
// @description  Chặn triệt để 100% quảng cáo YouTube trên iOS Safari
// @author       JET
// @match        *://*.youtube.com/*
// @match        *://youtube.com/*
// @match        *://m.youtube.com/*
// @run-at       document-start
// @grant        none
// ==/UserScript==

(function() {
  'use strict';

  // ================================================================
  // CSS INJECTION — Ẩn mọi ad elements NGAY LẬP TỨC
  // ================================================================

  const adCSS = document.createElement('style');
  adCSS.textContent = `
    /* Video ads */
    .video-ads,
    .ytp-ad-module,
    .ytp-ad-overlay-container,
    .ytp-ad-text-overlay,
    .ytp-ad-overlay-slot,
    .ytp-ad-player-overlay,
    .ytp-ad-player-overlay-layout,
    .ytp-ad-player-overlay-instream-info,
    .ytp-ad-action-interstitial,
    .ytp-ad-action-interstitial-background-container,
    .ytp-ad-image-overlay,
    .ytp-ad-survey-interstitial,
    .ytp-ad-feedback-dialog-container,
    .ytp-ad-overlay-ad-info-button-container,
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
      width: 0 !important;
      opacity: 0 !important;
      pointer-events: none !important;
    }

    /* Page ads */
    #player-ads,
    #masthead-ad,
    ytd-promoted-sparkles-web-renderer,
    ytd-promoted-sparkles-text-search-renderer,
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
    ytd-background-promo-renderer,
    .ytd-merch-shelf-renderer,
    #offer-module,
    ytd-rich-item-renderer:has(ytd-ad-slot-renderer),
    ytd-rich-section-renderer:has(ytd-ad-slot-renderer) {
      display: none !important;
      height: 0 !important;
      max-height: 0 !important;
      overflow: hidden !important;
    }

    /* Anti-adblock popup */
    ytd-enforcement-message-view-model,
    tp-yt-iron-overlay-backdrop[opened] {
      display: none !important;
    }

    /* Mobile-specific ads */
    .ytm-promoted-sparkles-web-renderer,
    .ytm-companion-ad-renderer,
    ytm-promoted-sparkles-web-renderer,
    ytm-companion-slot,
    .ad-showing .ytp-ad-module {
      display: none !important;
    }
  `;
  (document.head || document.documentElement).appendChild(adCSS);

  // ================================================================
  // STRIP AD DATA
  // ================================================================

  function stripAds(data) {
    if (!data || typeof data !== 'object') return data;

    const adKeys = [
      'adPlacements', 'playerAds', 'adSlots', 'adBreakHeartbeatParams',
      'adBreakParams', 'adParams', 'adConfig', 'instreamAdPlayerOverlayRenderer',
      'adPlacementConfig', 'adVideoId', 'legacyAdServerVideoUrl'
    ];

    for (const key of adKeys) {
      if (key in data) delete data[key];
    }

    if (data.playerConfig) delete data.playerConfig.adPlacementsConfig;
    if (data.playabilityStatus) delete data.playabilityStatus.adBreakParams;

    return data;
  }

  function stripPageAds(data) {
    if (!data || typeof data !== 'object') return data;
    try {
      delete data?.topbar?.desktopTopbarRenderer?.promotionalContent;
      delete data?.topbar?.desktopTopbarRenderer?.adSlots;
      delete data?.topbar?.mobileTopbarRenderer?.promotionalContent;

      // Homepage/browse feed
      const tabs = data?.contents?.twoColumnBrowseResultsRenderer?.tabs;
      if (tabs) {
        for (const tab of tabs) {
          const items = tab?.tabRenderer?.content?.richGridRenderer?.contents;
          if (items) {
            tab.tabRenderer.content.richGridRenderer.contents = items.filter(i =>
              !i?.richItemRenderer?.content?.adSlotRenderer &&
              !i?.richSectionRenderer?.content?.richShelfRenderer?.contents?.some?.(
                c => c?.richItemRenderer?.content?.adSlotRenderer
              )
            );
          }
        }
      }

      // Mobile browse (singleColumnBrowseResultsRenderer)
      const mobileTabs = data?.contents?.singleColumnBrowseResultsRenderer?.tabs;
      if (mobileTabs) {
        for (const tab of mobileTabs) {
          const items = tab?.tabRenderer?.content?.sectionListRenderer?.contents;
          if (items) {
            tab.tabRenderer.content.sectionListRenderer.contents = items.filter(i => {
              const renderer = i?.itemSectionRenderer?.contents?.[0];
              return !renderer?.adSlotRenderer && !renderer?.promotedSparklesWebRenderer;
            });
          }
        }
      }

      // Search results
      const searchItems = data?.contents?.twoColumnSearchResultsRenderer?.primaryContents
        ?.sectionListRenderer?.contents;
      if (searchItems) {
        for (const section of searchItems) {
          const items = section?.itemSectionRenderer?.contents;
          if (items) {
            section.itemSectionRenderer.contents = items.filter(i =>
              !i?.promotedSparklesWebRenderer && !i?.searchPyvRenderer && !i?.adSlotRenderer
            );
          }
        }
      }

      // Continuation items (infinite scroll)
      const actions = data?.onResponseReceivedActions || data?.onResponseReceivedEndpoints || [];
      for (const action of actions) {
        const items = action?.appendContinuationItemsAction?.continuationItems ||
                      action?.reloadContinuationItemsCommand?.continuationItems;
        if (items) {
          const key = action.appendContinuationItemsAction ? 'appendContinuationItemsAction' : 'reloadContinuationItemsCommand';
          action[key].continuationItems = items.filter(i =>
            !i?.promotedSparklesWebRenderer &&
            !i?.adSlotRenderer &&
            !i?.richItemRenderer?.content?.adSlotRenderer
          );
        }
      }
    } catch(e) {}
    return data;
  }

  // ================================================================
  // INTERCEPT ytInitialPlayerResponse (TRƯỚC KHI PLAYER LOAD)
  // ================================================================

  try {
    let _ytIPR = window.ytInitialPlayerResponse;
    Object.defineProperty(window, 'ytInitialPlayerResponse', {
      configurable: true, enumerable: true,
      get() { return _ytIPR; },
      set(v) { _ytIPR = stripAds(v); }
    });
  } catch(e) {}

  try {
    let _ytID = window.ytInitialData;
    Object.defineProperty(window, 'ytInitialData', {
      configurable: true, enumerable: true,
      get() { return _ytID; },
      set(v) { _ytID = stripPageAds(v); }
    });
  } catch(e) {}

  // ================================================================
  // INTERCEPT Response.prototype.json — strip ads từ API responses
  // ================================================================

  const _origJson = Response.prototype.json;
  Response.prototype.json = function() {
    return _origJson.call(this).then(data => {
      if (!data || typeof data !== 'object') return data;
      if (data.videoDetails) stripAds(data);
      if (data.playerResponse) stripAds(data.playerResponse);
      if (data.contents || data.onResponseReceivedActions || data.onResponseReceivedEndpoints) {
        stripPageAds(data);
      }
      return data;
    });
  };

  // ================================================================
  // BLOCK AD NETWORK REQUESTS
  // ================================================================

  const AD_PATTERNS = [
    '/pagead/', '/ptracking', '/api/stats/ads', '/get_midroll_',
    'googleads.', '/ad_data_', 'doubleclick.net', 'googleadservices.com',
    'googlesyndication.com', '/api/stats/qoe?adformat',
    '/api/stats/playback?adformat', '/api/stats/watchtime?adformat',
    '/youtubei/v1/player/ad_break', '/pcs/activeview',
    '/pagead/interaction', 'fundingchoicesmessages.google.com',
    '/youtubei/v1/att/get', 'google.com/pagead',
    '/set_awesome', '/api/stats/delayplay', '/api/stats/atr',
  ];

  function isAdUrl(url) {
    if (typeof url !== 'string') return false;
    for (const p of AD_PATTERNS) {
      if (url.includes(p)) return true;
    }
    return false;
  }

  const _fetch = window.fetch;
  window.fetch = function(input, init) {
    const url = (typeof input === 'string') ? input : input?.url || '';
    if (isAdUrl(url)) return Promise.resolve(new Response('{}', { status: 200 }));
    return _fetch.apply(this, arguments);
  };

  const _xhrOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url, ...rest) {
    if (isAdUrl(url)) {
      return _xhrOpen.call(this, method, 'data:application/json,{}', ...rest);
    }
    return _xhrOpen.call(this, method, url, ...rest);
  };

  // ================================================================
  // INSTANT AD NUKE — Phát hiện quảng cáo → triệt hạ ngay
  // ================================================================

  function nukeVideoAd() {
    const player = document.querySelector('.html5-video-player');
    if (!player) return false;

    const isAd = player.classList.contains('ad-showing') ||
                 player.classList.contains('ad-interrupting');
    if (!isAd) return false;

    const video = player.querySelector('video');
    if (!video) return false;

    // Nhảy đến cuối
    if (video.duration && isFinite(video.duration) && video.duration > 0) {
      video.currentTime = video.duration;
    }
    try { video.playbackRate = 16; } catch(e) {}
    video.muted = true;
    video.dispatchEvent(new Event('ended'));

    // Click skip buttons
    [
      '.ytp-skip-ad-button', '.ytp-ad-skip-button', '.ytp-ad-skip-button-modern',
      'button.ytp-ad-skip-button-modern', '.ytp-ad-skip-button-slot button',
      '.ytp-ad-skip-button-container button', '[id^="skip-button"]',
      '.ytp-ad-overlay-close-button',
    ].forEach(sel => {
      document.querySelectorAll(sel).forEach(b => { try { b.click(); } catch(e) {} });
    });

    // Remove ad elements
    player.querySelectorAll('.video-ads,.ytp-ad-module,.ytp-ad-overlay-container,.ytp-ad-player-overlay,.ytp-ad-action-interstitial,.ytp-ad-image-overlay').forEach(el => el.remove());

    return true;
  }

  // ================================================================
  // NUKE PAGE ADS
  // ================================================================

  function nukePageAds() {
    document.querySelectorAll([
      '#player-ads', '#masthead-ad',
      'ytd-promoted-sparkles-web-renderer', 'ytd-promoted-sparkles-text-search-renderer',
      'ytd-display-ad-renderer', 'ytd-in-feed-ad-layout-renderer',
      'ytd-ad-slot-renderer', 'ytd-banner-promo-renderer',
      'ytd-statement-banner-renderer', 'ytd-mealbar-promo-renderer',
      'ytd-action-companion-ad-renderer', 'ytd-companion-slot-renderer',
      'ytd-promoted-video-renderer', 'ytd-search-pyv-renderer',
      'ytd-background-promo-renderer', '.ytd-merch-shelf-renderer',
      'ytm-promoted-sparkles-web-renderer', 'ytm-companion-slot',
    ].join(',')).forEach(el => el.remove());
  }

  // ================================================================
  // ANTI-ADBLOCK BYPASS
  // ================================================================

  function bypassAntiAdblock() {
    document.querySelectorAll('ytd-enforcement-message-view-model').forEach(el => el.remove());
    document.querySelectorAll('tp-yt-paper-dialog').forEach(popup => {
      const text = (popup.textContent || '').toLowerCase();
      if (text.includes('ad blocker') || text.includes('adblock') ||
          text.includes('allow ads') || text.includes('ad blockers')) {
        popup.remove();
        document.querySelectorAll('tp-yt-iron-overlay-backdrop').forEach(b => b.remove());
        const v = document.querySelector('video');
        if (v?.paused) v.play().catch(() => {});
      }
    });
    document.body.style.removeProperty('overflow');
    document.documentElement.style.removeProperty('overflow');
  }

  // ================================================================
  // PLAYER API HOOKS
  // ================================================================

  function hookPlayer() {
    const player = document.getElementById('movie_player');
    if (!player || player._hooked) return;
    try {
      if (typeof player.getAdState === 'function') player.getAdState = () => -1;
      const origLoadModule = player.loadModule;
      if (origLoadModule) {
        player.loadModule = function(name) {
          if (typeof name === 'string' && name.toLowerCase().includes('ad')) return;
          return origLoadModule.call(this, name);
        };
      }
      player._hooked = true;
    } catch(e) {}
  }

  // ================================================================
  // VIDEO STATE RESTORE
  // ================================================================

  let savedVol = 1, savedMuted = false;

  function saveState() {
    const v = document.querySelector('.html5-video-player:not(.ad-showing) video');
    if (v) { savedMuted = v.muted; savedVol = v.volume || 1; }
  }

  function restoreState() {
    const player = document.querySelector('.html5-video-player');
    if (player && !player.classList.contains('ad-showing')) {
      const v = player.querySelector('video');
      if (v && v.muted && !savedMuted) {
        v.muted = false;
        v.volume = savedVol;
        try { v.playbackRate = 1; } catch(e) {}
      }
    }
  }

  // ================================================================
  // MUTATION OBSERVER
  // ================================================================

  let debounce = null;
  const observer = new MutationObserver((mutations) => {
    for (const m of mutations) {
      if (m.type === 'attributes' && m.attributeName === 'class') {
        if (m.target.classList?.contains('ad-showing') || m.target.classList?.contains('ad-interrupting')) {
          nukeVideoAd();
          setTimeout(nukeVideoAd, 100);
          setTimeout(nukeVideoAd, 300);
          setTimeout(nukeVideoAd, 600);
          setTimeout(nukeVideoAd, 1000);
          return;
        }
      }
    }
    if (debounce) return;
    debounce = setTimeout(() => {
      debounce = null;
      nukePageAds();
      bypassAntiAdblock();
    }, 100);
  });

  // ================================================================
  // SCAN
  // ================================================================

  function scan() {
    if (nukeVideoAd()) {
      setTimeout(nukeVideoAd, 200);
      setTimeout(nukeVideoAd, 500);
    } else {
      restoreState();
    }
    nukePageAds();
    hookPlayer();
    bypassAntiAdblock();
  }

  // ================================================================
  // INIT
  // ================================================================

  function init() {
    observer.observe(document.documentElement, {
      childList: true, subtree: true, attributes: true,
      attributeFilter: ['class']
    });

    scan();

    document.addEventListener('yt-navigate-finish', () => {
      setTimeout(scan, 300);
      setTimeout(scan, 1500);
    });
    document.addEventListener('yt-page-data-updated', () => setTimeout(scan, 300));

    setInterval(() => { saveState(); scan(); }, 1000);

    // Player hook retry
    const hookInterval = setInterval(() => {
      hookPlayer();
      if (document.getElementById('movie_player')?._hooked) clearInterval(hookInterval);
    }, 1000);
    setTimeout(() => clearInterval(hookInterval), 30000);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  window.addEventListener('load', () => {
    setTimeout(scan, 500);
    setTimeout(scan, 2000);
  });

})();
