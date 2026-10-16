import { Controller } from "@hotwired/stimulus"

// Privacy banner: records the visitor's analytics choice ("granted" / "denied")
// and loads Mixpanel on accept (see shared/_mixpanel.html.erb). The banner
// shows until a choice is made. The old "cookieConsentAccepted" key only
// acknowledged essential cookies, so it doesn't count as an analytics choice.
const KEY = "analyticsConsent"

export default class extends Controller {
  static targets = ["banner"]

  connect() {
    if (!this.storedChoice()) this.showBanner()
  }

  storedChoice() {
    try { return localStorage.getItem(KEY) } catch (e) { return null }
  }

  store(choice) {
    try {
      localStorage.setItem(KEY, choice)
      localStorage.setItem(`${KEY}Date`, new Date().toISOString())
    } catch (e) { /* storage blocked: banner simply shows again next visit */ }
  }

  showBanner() {
    this.bannerTarget.classList.remove("hidden")
    setTimeout(() => {
      this.bannerTarget.classList.remove("translate-y-full", "opacity-0")
    }, 100)
  }

  hideBanner() {
    this.bannerTarget.classList.add("translate-y-full", "opacity-0")
    setTimeout(() => {
      this.bannerTarget.classList.add("hidden")
    }, 300)
  }

  accept() {
    this.store("granted")
    if (typeof window.candidataLoadAnalytics === "function") window.candidataLoadAnalytics()
    this.hideBanner()
  }

  decline() {
    this.store("denied")
    if (window.mixpanel && typeof window.mixpanel.opt_out_tracking === "function") {
      window.mixpanel.opt_out_tracking()
    }
    this.hideBanner()
  }
}
