# JET Tube 🚀

**App YouTube không quảng cáo — by JET ⚡**

Custom iOS YouTube client sử dụng WKWebView + JavaScript ad blocker injection. Không mod YouTube binary — clean, legal, dễ maintain.

## Tính năng

- 🚫 **Chặn 100% quảng cáo** — JS injection + WKContentRuleList + CSS hiding
- 🎬 **Trải nghiệm YouTube đầy đủ** — login, playlist, comments, subscriptions
- 🔊 **Background audio** — nghe nhạc khi tắt màn hình
- 📺 **Picture-in-Picture** — video thu nhỏ khi dùng app khác
- 🌙 **Dark mode** — luôn dark, dễ nhìn ban đêm
- ⚡ **Nhanh** — không overhead, chỉ WebView + ad blocker

## Cách hoạt động

```
┌──────────────────────────┐
│       JET Tube App       │
│  ┌────────────────────┐  │
│  │     WKWebView      │  │
│  │   m.youtube.com    │  │
│  │                    │  │
│  │  WKUserScript ──── │──│── JS Injection (document-start)
│  │  WKContentRuleList │──│── Native URL Blocking (WebKit level)  
│  │  CSS Injection ─── │──│── Hide Ad Elements
│  │  NavigationDelegate│──│── Block Ad Navigation
│  └────────────────────┘  │
│  [🏠] [🔍] [📺] [⚙️]    │
└──────────────────────────┘
```

## Build

### Tự động (GitHub Actions)
Push code lên GitHub → Actions tự build IPA → Download từ Artifacts.

### Thủ công (cần Mac)
```bash
brew install xcodegen
cd JETTube
xcodegen generate
xcodebuild -project JETTube.xcodeproj -scheme JETTube -sdk iphoneos archive
```

## Cài đặt lên iPhone

1. Download file `JETTube.ipa` từ GitHub Actions artifacts
2. Mở **SideStore** trên iPhone
3. Nhấn **+** → chọn file IPA
4. Install → Mở **JET Tube** → 🎉

## Requirements

- iOS 16.0+
- SideStore / AltStore để cài IPA

## License

MIT — Dev by JET ⚡
