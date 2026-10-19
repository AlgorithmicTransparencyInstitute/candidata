import { Controller } from "@hotwired/stimulus"

// Home page map: switches between the tile grid (default) and the geographic
// map. The geographic map is a lazy turbo-frame, so its path data is only
// fetched the first time it's shown. The switch is hidden until this connects,
// so without JavaScript visitors simply get the grid. The last choice is a
// per-visitor convenience in localStorage; losing it just means the grid.
const KEY = "homeMapView"

export default class extends Controller {
  static targets = ["switch", "button", "view"]

  connect() {
    this.switchTarget.hidden = false
    let stored = null
    try { stored = localStorage.getItem(KEY) } catch (e) { /* storage blocked */ }
    this.show(stored === "geo" ? "geo" : "grid", false)
  }

  select(event) {
    this.show(event.currentTarget.dataset.view, true)
  }

  show(view, remember) {
    this.viewTargets.forEach(el => { el.hidden = el.dataset.view !== view })
    this.buttonTargets.forEach(b => b.setAttribute("aria-pressed", b.dataset.view === view))
    if (remember) {
      try { localStorage.setItem(KEY, view) } catch (e) { /* storage blocked */ }
    }
  }
}
