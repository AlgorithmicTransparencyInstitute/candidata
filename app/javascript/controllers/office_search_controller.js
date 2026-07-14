import { Controller } from "@hotwired/stimulus"

// Search-as-you-type office picker backed by /admin/offices/search.
//
// Markup contract (see admin/contests/_form and shared/_office_search):
//   data-controller="office-search"
//   data-office-search-url-value="/admin/offices/search"
//   data-office-search-state-value="CO"        (optional pre-filter)
//   input   [data-office-search-target="input"]
//   div     [data-office-search-target="results"]   (dropdown container)
//   input   [data-office-search-target="hidden" name="contest[office_id]"]
//
// Sets the hidden office_id on selection and shows the chosen office's label.
export default class extends Controller {
  static targets = ["input", "results", "hidden"]
  static values = { url: String, state: String, min: { type: Number, default: 2 } }

  connect() {
    this.timer = null
    this.activeIndex = -1
    this.items = []
    this.hideResults()
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  onInput() {
    if (this.timer) clearTimeout(this.timer)
    // Typing invalidates any prior selection.
    if (this.hasHiddenTarget) this.hiddenTarget.value = ""
    const q = this.inputTarget.value.trim()
    if (q.length < this.minValue) {
      this.hideResults()
      return
    }
    this.timer = setTimeout(() => this.search(q), 200)
  }

  async search(q) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", q)
    if (this.stateValue) url.searchParams.set("state", this.stateValue)
    try {
      const res = await fetch(url, { headers: { Accept: "application/json" } })
      if (!res.ok) return this.hideResults()
      const data = await res.json()
      this.render(data.offices || [])
    } catch {
      this.hideResults()
    }
  }

  render(offices) {
    this.items = offices
    this.activeIndex = -1
    if (offices.length === 0) {
      this.resultsTarget.innerHTML =
        '<div class="px-3 py-2 text-sm text-gray-500">No matching offices</div>'
      this.showResults()
      return
    }
    this.resultsTarget.innerHTML = offices
      .map(
        (o, i) =>
          `<button type="button" data-index="${i}" data-action="click->office-search#choose"
             class="block w-full text-left px-3 py-2 text-sm hover:bg-blue-50 border-b border-gray-100 last:border-0">
             ${this.escape(o.label)}
           </button>`
      )
      .join("")
    this.showResults()
  }

  choose(event) {
    const i = parseInt(event.currentTarget.dataset.index, 10)
    const office = this.items[i]
    if (!office) return
    if (this.hasHiddenTarget) this.hiddenTarget.value = office.id
    this.inputTarget.value = office.label
    this.hideResults()
  }

  onKeydown(event) {
    if (this.resultsTarget.classList.contains("hidden")) return
    const buttons = Array.from(this.resultsTarget.querySelectorAll("button"))
    if (buttons.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.activeIndex = Math.min(this.activeIndex + 1, buttons.length - 1)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.activeIndex = Math.max(this.activeIndex - 1, 0)
    } else if (event.key === "Enter" && this.activeIndex >= 0) {
      event.preventDefault()
      buttons[this.activeIndex].click()
      return
    } else if (event.key === "Escape") {
      this.hideResults()
      return
    } else {
      return
    }
    buttons.forEach((b, i) => b.classList.toggle("bg-blue-50", i === this.activeIndex))
  }

  onBlur() {
    // Delay so a click on a result registers before the dropdown hides.
    setTimeout(() => this.hideResults(), 150)
  }

  showResults() {
    this.resultsTarget.classList.remove("hidden")
  }

  hideResults() {
    this.resultsTarget.classList.add("hidden")
  }

  escape(str) {
    const div = document.createElement("div")
    div.textContent = str == null ? "" : str
    return div.innerHTML
  }
}
