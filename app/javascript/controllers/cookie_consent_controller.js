import { Controller } from "@hotwired/stimulus"

// Cookie consent banner controller
// Handles showing/hiding the cookie consent banner and storing user acceptance
export default class extends Controller {
  static targets = ["banner"]

  connect() {
    // Check if user has already accepted cookies
    const hasAccepted = localStorage.getItem("cookieConsentAccepted")

    if (!hasAccepted) {
      this.showBanner()
    }
  }

  showBanner() {
    this.bannerTarget.classList.remove("hidden")
    // Trigger animation
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
    localStorage.setItem("cookieConsentAccepted", "true")
    localStorage.setItem("cookieConsentDate", new Date().toISOString())
    this.hideBanner()
  }
}
