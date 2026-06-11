import { Controller } from "@hotwired/stimulus"

// Spreadsheet-style election editor.
//
// All data is embedded in the page as JSON (data target). Rows are plain JS
// objects; the table is uncontrolled DOM with event delegation, so hundreds
// of rows stay fast. Saving POSTs only dirty rows and applies per-row results
// (new ids, normalized handles, errors) back into the grid.
export default class extends Controller {
  static targets = [
    "data", "thead", "tbody", "contestFilter", "search", "counts", "saveButton",
    "contestDialog", "officeSearch", "officeResults", "officeId",
    "contestParty", "contestPartyWrap", "contestError", "contestCreateButton", "toast"
  ]

  connect() {
    this.data = JSON.parse(this.dataTarget.textContent)
    this.rowSeq = 0
    this.rows = this.data.rows.map(r => this.makeRow(r))
    this.deletedCandidateIds = []
    this.saving = false

    this.renderHeader()
    this.renderContestFilter()
    this.renderBody()
    if (this.rows.length === 0 && this.data.contests.length > 0) this.addRow()
    this.updateCounts()

    this.onBeforeUnload = (e) => {
      if (this.pendingChanges() > 0) { e.preventDefault(); e.returnValue = "" }
    }
    window.addEventListener("beforeunload", this.onBeforeUnload)

    this.onGlobalKeydown = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "s") { e.preventDefault(); this.saveAll() }
    }
    document.addEventListener("keydown", this.onGlobalKeydown)

    this.onDocumentClick = (e) => {
      if (this.typeaheadEl && !this.typeaheadEl.contains(e.target)) this.closeTypeahead()
    }
    document.addEventListener("click", this.onDocumentClick)
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    document.removeEventListener("keydown", this.onGlobalKeydown)
    document.removeEventListener("click", this.onDocumentClick)
  }

  // ---------- row model ----------

  makeRow(r = {}) {
    const socials = {}
    for (const platform of this.data.platforms) {
      const cell = (r.socials || {})[platform] || {}
      socials[platform] = {
        accountId: cell.accountId || null,
        value: cell.handle || cell.url || "",
        url: cell.url || null,
        verified: !!cell.verified
      }
    }
    const row = {
      key: `r${++this.rowSeq}`,
      candidateId: r.candidateId || null,
      personId: r.personId || null,
      contestId: r.contestId || null,
      firstName: r.firstName || "",
      lastName: r.lastName || "",
      party: r.party || "",
      outcome: r.outcome || "pending",
      incumbent: !!r.incumbent,
      gender: r.gender || "",
      race: r.race || "",
      socials,
      errors: [],
      warnings: []
    }
    row.baseline = this.snapshot(row)
    return row
  }

  snapshot(row) {
    return JSON.stringify([
      row.contestId, row.firstName, row.lastName, row.party, row.outcome,
      row.incumbent, row.gender, row.race,
      this.data.platforms.map(p => row.socials[p].value.trim())
    ])
  }

  isDirty(row) { return this.snapshot(row) !== row.baseline }

  isBlankNewRow(row) {
    return !row.candidateId && !row.personId &&
      !row.firstName.trim() && !row.lastName.trim() &&
      this.data.platforms.every(p => !row.socials[p].value.trim())
  }

  pendingChanges() {
    return this.rows.filter(r => this.isDirty(r) && !this.isBlankNewRow(r)).length +
      this.deletedCandidateIds.length
  }

  // ---------- rendering ----------

  renderHeader() {
    const socialThs = this.data.platforms
      .map(p => `<th class="bg-blue-50/70">${p}</th>`).join("")
    this.theadTarget.innerHTML = `
      <tr>
        <th class="ee-c0"></th>
        <th class="ee-c1">Contest</th>
        <th class="ee-c2">First name</th>
        <th class="ee-c3">Last name</th>
        <th>Party</th>
        <th class="text-center">Inc.</th>
        <th>Outcome</th>
        <th>Gender</th>
        <th>Race</th>
        ${socialThs}
        <th></th>
      </tr>`
  }

  contestOptionsHtml(selectedId, includeBlank = true) {
    const groups = new Map()
    for (const c of this.data.contests) {
      if (!groups.has(c.ballotLabel)) groups.set(c.ballotLabel, [])
      groups.get(c.ballotLabel).push(c)
    }
    let html = includeBlank ? `<option value="">—</option>` : ""
    for (const [ballotLabel, contests] of groups) {
      html += `<optgroup label="${this.esc(ballotLabel)}">`
      for (const c of contests) {
        html += `<option value="${c.id}" ${String(selectedId) === String(c.id) ? "selected" : ""}>${this.esc(c.label)}</option>`
      }
      html += `</optgroup>`
    }
    return html
  }

  renderContestFilter() {
    const current = this.contestFilterTarget.value
    let html = `<option value="">All contests</option>`
    for (const c of this.data.contests) {
      const prefix = c.party || this.data.election.type
      html += `<option value="${c.id}" ${current === String(c.id) ? "selected" : ""}>${this.esc(prefix)} · ${this.esc(c.label)}</option>`
    }
    this.contestFilterTarget.innerHTML = html
  }

  selectHtml(field, options, selected, { blank = true, blankLabel = "—" } = {}) {
    let html = `<select class="ee-cell" data-field="${field}">`
    if (blank) html += `<option value="">${blankLabel}</option>`
    for (const opt of options) {
      const [value, label] = Array.isArray(opt) ? opt : [opt, opt]
      html += `<option value="${this.esc(value)}" ${selected === value ? "selected" : ""}>${this.esc(label)}</option>`
    }
    return html + `</select>`
  }

  buildRowEl(row) {
    const tr = document.createElement("tr")
    tr.dataset.key = row.key
    if (row.errors.length) tr.classList.add("ee-row-error")

    const socialTds = this.data.platforms.map(platform => {
      const cell = row.socials[platform]
      const verifiedClass = cell.verified ? " ee-social-verified" : ""
      const title = cell.verified
        ? `Verified — editing will flag for re-verification${cell.url ? `\n${cell.url}` : ""}`
        : (cell.url || platform)
      return `<td class="ee-social-cell${verifiedClass}">
        <input type="text" class="ee-cell" data-field="social" data-platform="${platform}"
               value="${this.esc(cell.value)}" placeholder="@" title="${this.esc(title)}"
               autocomplete="off" spellcheck="false" />
      </td>`
    }).join("")

    tr.innerHTML = `
      <td class="ee-c0"><span class="ee-status-dot" data-role="status"></span></td>
      <td class="ee-c1"><select class="ee-cell" data-field="contestId">${this.contestOptionsHtml(row.contestId)}</select></td>
      <td class="ee-c2"><input type="text" class="ee-cell" data-field="firstName" value="${this.esc(row.firstName)}" placeholder="First" autocomplete="off" spellcheck="false" /></td>
      <td class="ee-c3"><input type="text" class="ee-cell" data-field="lastName" value="${this.esc(row.lastName)}" placeholder="Last" autocomplete="off" spellcheck="false" /></td>
      <td>${this.selectHtml("party", this.data.parties.map(p => p.name), row.party)}</td>
      <td class="text-center align-middle"><input type="checkbox" data-field="incumbent" ${row.incumbent ? "checked" : ""} class="rounded border-gray-300 text-blue-600 m-2" /></td>
      <td>${this.selectHtml("outcome", this.data.outcomes.map(o => [o, o[0].toUpperCase() + o.slice(1)]), row.outcome, { blank: false })}</td>
      <td>${this.selectHtml("gender", this.data.genders, row.gender)}</td>
      <td>${this.selectHtml("race", this.data.races, row.race)}</td>
      ${socialTds}
      <td class="text-center">
        <button type="button" data-role="delete" class="px-2 py-1 text-gray-400 hover:text-red-600" title="Delete row">✕</button>
      </td>`

    this.applyStatus(row, tr)
    return tr
  }

  renderBody() {
    const tbody = this.tbodyTarget
    tbody.innerHTML = ""
    if (this.data.contests.length === 0) {
      tbody.innerHTML = `<tr><td colspan="${10 + this.data.platforms.length}" class="px-4 py-10 text-center text-gray-500 text-sm">
        No contests in this election yet — click “+ New contest” to create one, then add candidates.</td></tr>`
      return
    }
    const frag = document.createDocumentFragment()
    for (const row of this.rows) frag.appendChild(this.buildRowEl(row))
    tbody.appendChild(frag)

    if (!this.tableBound) {
      this.tableBound = true
      tbody.addEventListener("input", e => this.onCellInput(e))
      tbody.addEventListener("change", e => this.onCellChange(e))
      tbody.addEventListener("keydown", e => this.onCellKeydown(e))
      tbody.addEventListener("focusout", e => this.onCellBlur(e))
      tbody.addEventListener("click", e => {
        if (e.target.dataset.role === "delete") this.deleteRow(e)
      })
    }
    this.applyFilter()
  }

  rowFor(el) {
    const tr = el.closest("tr")
    return [this.rows.find(r => r.key === tr.dataset.key), tr]
  }

  applyStatus(row, tr = null) {
    tr ||= this.tbodyTarget.querySelector(`tr[data-key="${row.key}"]`)
    if (!tr) return
    const dot = tr.querySelector('[data-role="status"]')
    let color, title
    if (row.errors.length) {
      color = "#dc2626"; title = row.errors.join("\n")
      tr.classList.add("ee-row-error")
    } else {
      tr.classList.remove("ee-row-error")
      if (!row.candidateId && this.isBlankNewRow(row)) { color = "#e5e7eb"; title = "Empty row" }
      else if (this.isDirty(row)) { color = row.candidateId ? "#f59e0b" : "#3b82f6"; title = row.candidateId ? "Modified — unsaved" : "New — unsaved" }
      else { color = "#d1d5db"; title = "Saved" }
    }
    if (row.justSaved) { color = "#16a34a"; title = "Saved ✓" }
    dot.style.background = color
    dot.title = title + (row.warnings.length ? `\n${row.warnings.join("\n")}` : "")
  }

  // ---------- cell events ----------

  onCellInput(e) {
    const field = e.target.dataset.field
    if (!field) return
    const [row] = this.rowFor(e.target)
    if (!row) return
    row.justSaved = false

    if (field === "social") {
      row.socials[e.target.dataset.platform].value = e.target.value
      this.validateSocialInput(e.target)
    } else if (field === "firstName" || field === "lastName") {
      row[field] = e.target.value
      if (!row.personId) this.queueTypeahead(row, e.target)
    }
    this.applyStatus(row)
    this.updateCounts()
  }

  onCellChange(e) {
    const field = e.target.dataset.field
    if (!field) return
    const [row] = this.rowFor(e.target)
    if (!row) return
    row.justSaved = false

    if (field === "incumbent") row.incumbent = e.target.checked
    else if (field === "contestId") row.contestId = e.target.value ? Number(e.target.value) : null
    else if (field !== "social") row[field] = e.target.value

    this.applyStatus(row)
    this.updateCounts()
  }

  onCellBlur(e) {
    if (e.target.dataset.field === "social") this.validateSocialInput(e.target)
    if (["firstName", "lastName"].includes(e.target.dataset.field)) {
      setTimeout(() => {
        if (this.typeaheadEl && !this.typeaheadEl.contains(document.activeElement)) this.closeTypeahead()
      }, 150)
    }
  }

  onCellKeydown(e) {
    if (this.typeaheadEl && ["ArrowDown", "ArrowUp", "Enter", "Escape"].includes(e.key)) {
      if (this.handleTypeaheadKey(e)) return
    }
    if (e.key !== "Enter") return
    e.preventDefault()

    const td = e.target.closest("td")
    const tr = td.closest("tr")
    const cellIndex = Array.from(tr.children).indexOf(td)
    const targetTr = e.shiftKey ? tr.previousElementSibling : tr.nextElementSibling

    if (!targetTr && !e.shiftKey) {
      this.addRow()
      const newTr = this.tbodyTarget.lastElementChild
      newTr?.children[cellIndex]?.querySelector("input, select")?.focus()
      return
    }
    targetTr?.children[cellIndex]?.querySelector("input, select")?.focus()
  }

  validateSocialInput(input) {
    const value = input.value.trim()
    const bad = value && !/^https?:\/\//i.test(value) && /[^A-Za-z0-9._\-@]/.test(value)
    input.classList.toggle("ee-cell-invalid", !!bad)
    if (bad) input.title = "Unusual characters for a handle — double-check (saves anyway)"
  }

  // ---------- rows ----------

  addRow() {
    if (this.data.contests.length === 0) {
      this.showToast("Create a contest first", "error")
      return
    }
    const filterContest = this.contestFilterTarget.value
    const row = this.makeRow({ contestId: filterContest ? Number(filterContest) : null })
    this.rows.push(row)
    const tr = this.buildRowEl(row)
    this.tbodyTarget.appendChild(tr)
    tr.querySelector('[data-field="firstName"]')?.focus()
    this.updateCounts()
  }

  deleteRow(e) {
    const [row, tr] = this.rowFor(e.target)
    if (!row) return
    if (row.candidateId) {
      if (!confirm(`Remove ${row.firstName} ${row.lastName} from this contest?\n(The person and their social accounts are kept — only the candidacy is removed.)`)) return
      this.deletedCandidateIds.push(row.candidateId)
    }
    this.rows = this.rows.filter(r => r.key !== row.key)
    tr.remove()
    this.closeTypeahead()
    this.updateCounts()
  }

  // ---------- person typeahead ----------

  queueTypeahead(row, input) {
    clearTimeout(this.typeaheadTimer)
    const query = `${row.firstName} ${row.lastName}`.trim()
    if (query.length < 2) { this.closeTypeahead(); return }
    this.typeaheadTimer = setTimeout(() => this.fetchTypeahead(row, input, query), 250)
  }

  async fetchTypeahead(row, input, query) {
    try {
      const resp = await fetch(`${this.data.urls.people}?q=${encodeURIComponent(query)}`, {
        headers: { "Accept": "application/json" }
      })
      if (!resp.ok) return
      const { people } = await resp.json()
      if (document.activeElement !== input) return
      this.showTypeahead(row, input, people)
    } catch { /* typeahead is best-effort */ }
  }

  showTypeahead(row, input, people) {
    this.closeTypeahead()
    if (!people.length) return

    const menu = document.createElement("div")
    menu.className = "ee-typeahead"
    menu.innerHTML = people.map((p, i) => `
      <div class="ee-typeahead-item" data-index="${i}">
        <div class="font-medium">${this.esc(p.fullName)}
          ${p.inThisElection ? '<span class="text-amber-600 text-xs font-semibold ml-1">already in this election</span>' : ""}
        </div>
        <div class="ee-meta">${[p.state, p.party, `${Object.keys(p.socials).length} social account(s)`].filter(Boolean).join(" · ")}</div>
      </div>`).join("")

    const rect = input.getBoundingClientRect()
    menu.style.position = "fixed"
    menu.style.left = `${rect.left}px`
    menu.style.top = `${rect.bottom + 2}px`
    document.body.appendChild(menu)

    this.typeaheadEl = menu
    this.typeaheadPeople = people
    this.typeaheadRow = row
    this.typeaheadIndex = -1

    menu.addEventListener("mousedown", e => {
      const item = e.target.closest(".ee-typeahead-item")
      if (item) { e.preventDefault(); this.selectPerson(Number(item.dataset.index)) }
    })
  }

  handleTypeaheadKey(e) {
    const items = this.typeaheadEl.querySelectorAll(".ee-typeahead-item")
    if (e.key === "Escape") { this.closeTypeahead(); return true }
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault()
      this.typeaheadIndex = e.key === "ArrowDown"
        ? Math.min(this.typeaheadIndex + 1, items.length - 1)
        : Math.max(this.typeaheadIndex - 1, 0)
      items.forEach((el, i) => el.classList.toggle("ee-active", i === this.typeaheadIndex))
      return true
    }
    if (e.key === "Enter" && this.typeaheadIndex >= 0) {
      e.preventDefault()
      this.selectPerson(this.typeaheadIndex)
      return true
    }
    return false
  }

  selectPerson(index) {
    const person = this.typeaheadPeople[index]
    const row = this.typeaheadRow
    this.closeTypeahead()
    if (!person || !row) return

    row.personId = person.id
    row.firstName = person.firstName
    row.lastName = person.lastName
    if (!row.gender) row.gender = person.gender || ""
    if (!row.race) row.race = person.race || ""
    if (!row.party && person.party) row.party = person.party
    for (const platform of this.data.platforms) {
      const existing = person.socials[platform]
      if (existing && !row.socials[platform].value.trim()) {
        row.socials[platform] = {
          accountId: existing.accountId,
          value: existing.handle || existing.url || "",
          url: existing.url,
          verified: !!existing.verified
        }
      }
    }

    const oldTr = this.tbodyTarget.querySelector(`tr[data-key="${row.key}"]`)
    const newTr = this.buildRowEl(row)
    oldTr.replaceWith(newTr)
    newTr.querySelector(`[data-field="${row.contestId ? "party" : "contestId"}"]`)?.focus()
    this.updateCounts()
    this.showToast(`Linked to existing person: ${person.fullName}`, "info")
  }

  closeTypeahead() {
    this.typeaheadEl?.remove()
    this.typeaheadEl = null
    this.typeaheadPeople = null
    this.typeaheadRow = null
    this.typeaheadIndex = -1
  }

  // ---------- filter / counts ----------

  applyFilter() {
    const contest = this.contestFilterTarget.value
    const term = this.searchTarget.value.trim().toLowerCase()
    for (const row of this.rows) {
      const tr = this.tbodyTarget.querySelector(`tr[data-key="${row.key}"]`)
      if (!tr) continue
      const matchContest = !contest || String(row.contestId) === contest
      const matchTerm = !term || `${row.firstName} ${row.lastName}`.toLowerCase().includes(term)
      tr.style.display = matchContest && matchTerm ? "" : "none"
    }
    this.updateCounts()
  }

  updateCounts() {
    const total = this.rows.length
    const dirty = this.rows.filter(r => this.isDirty(r) && !this.isBlankNewRow(r)).length
    const errors = this.rows.filter(r => r.errors.length).length
    const parts = [`${total} row${total === 1 ? "" : "s"}`]
    if (dirty) parts.push(`${dirty} unsaved`)
    if (this.deletedCandidateIds.length) parts.push(`${this.deletedCandidateIds.length} deletion${this.deletedCandidateIds.length === 1 ? "" : "s"} pending`)
    if (errors) parts.push(`${errors} error${errors === 1 ? "" : "s"}`)
    this.countsTarget.textContent = parts.join(" · ")

    const pending = this.pendingChanges()
    this.saveButtonTarget.textContent = this.saving ? "Saving…" : (pending ? `Save (${pending})` : "Save")
    this.saveButtonTarget.disabled = this.saving || pending === 0
  }

  // ---------- save ----------

  async saveAll() {
    if (this.saving) return
    const candidates = this.rows.filter(r => this.isDirty(r) && !this.isBlankNewRow(r))

    const valid = []
    for (const row of candidates) {
      row.errors = []
      if (!row.contestId) row.errors.push("Contest is required")
      if (!row.firstName.trim()) row.errors.push("First name is required")
      if (!row.lastName.trim()) row.errors.push("Last name is required")
      this.applyStatus(row)
      if (!row.errors.length) valid.push(row)
    }
    const skipped = candidates.length - valid.length

    if (valid.length === 0 && this.deletedCandidateIds.length === 0) {
      if (skipped) this.showToast(`${skipped} row(s) have missing required fields`, "error")
      return
    }

    this.saving = true
    this.updateCounts()

    try {
      const resp = await fetch(this.data.urls.save, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({
          rows: valid.map(r => this.rowPayload(r)),
          deletedCandidateIds: this.deletedCandidateIds
        })
      })
      if (!resp.ok) throw new Error(`Save failed (${resp.status})`)
      const { results, deleted } = await resp.json()

      let saved = 0, failed = 0
      const warnings = []
      for (const result of results) {
        const row = this.rows.find(r => r.key === result.key)
        if (!row) continue
        if (result.ok) {
          saved++
          row.candidateId = result.candidateId
          row.personId = result.personId
          row.warnings = result.warnings || []
          warnings.push(...row.warnings)
          for (const [platform, cell] of Object.entries(result.socials || {})) {
            row.socials[platform] = cell
              ? { accountId: cell.accountId, value: cell.handle || cell.url || "", url: cell.url, verified: !!cell.verified }
              : { accountId: null, value: "", url: null, verified: false }
          }
          row.errors = []
          row.baseline = this.snapshot(row)
          row.justSaved = true
          const oldTr = this.tbodyTarget.querySelector(`tr[data-key="${row.key}"]`)
          oldTr?.replaceWith(this.buildRowEl(row))
          setTimeout(() => { row.justSaved = false; this.applyStatus(row) }, 2500)
        } else {
          failed++
          row.errors = result.errors || ["Save failed"]
          this.applyStatus(row)
        }
      }
      this.deletedCandidateIds = this.deletedCandidateIds.filter(id => !(deleted || []).includes(id))

      let message = `Saved ${saved} row${saved === 1 ? "" : "s"}`
      if (deleted?.length) message += `, deleted ${deleted.length}`
      if (failed) message += ` · ${failed} failed`
      if (skipped) message += ` · ${skipped} skipped (missing fields)`
      this.showToast(message, failed || skipped ? "error" : "success")
      if (warnings.length) setTimeout(() => this.showToast(warnings[0], "info"), 1500)
    } catch (err) {
      this.showToast(err.message || "Save failed — check your connection", "error")
    } finally {
      this.saving = false
      this.applyFilter()
      this.updateCounts()
    }
  }

  rowPayload(row) {
    const socials = {}
    for (const platform of this.data.platforms) {
      const cell = row.socials[platform]
      if (cell.accountId || cell.value.trim()) {
        socials[platform] = { accountId: cell.accountId, value: cell.value.trim() }
      }
    }
    return {
      key: row.key,
      candidateId: row.candidateId,
      personId: row.personId,
      contestId: row.contestId,
      firstName: row.firstName,
      lastName: row.lastName,
      party: row.party,
      outcome: row.outcome,
      incumbent: row.incumbent,
      gender: row.gender,
      race: row.race,
      socials
    }
  }

  // ---------- new contest dialog ----------

  openContestDialog() {
    this.officeSearchTarget.value = ""
    this.officeIdTarget.value = ""
    this.officeResultsTarget.innerHTML = ""
    this.officeResultsTarget.classList.add("hidden")
    this.contestErrorTarget.classList.add("hidden")

    const isPrimary = this.data.election.type === "primary"
    this.contestPartyWrapTarget.style.display = isPrimary ? "" : "none"
    this.contestPartyTarget.innerHTML =
      (isPrimary ? "" : `<option value="">—</option>`) +
      this.data.contestParties.map(p => `<option value="${this.esc(p)}">${this.esc(p)}</option>`).join("")

    this.contestDialogTarget.showModal()
    this.officeSearchTarget.focus()
  }

  closeContestDialog() { this.contestDialogTarget.close() }

  searchOffices() {
    clearTimeout(this.officeTimer)
    const q = this.officeSearchTarget.value.trim()
    this.officeIdTarget.value = ""
    if (q.length < 2) { this.officeResultsTarget.classList.add("hidden"); return }
    this.officeTimer = setTimeout(async () => {
      try {
        const resp = await fetch(`${this.data.urls.offices}?q=${encodeURIComponent(q)}`, { headers: { "Accept": "application/json" } })
        const { offices } = await resp.json()
        this.officeResultsTarget.innerHTML = offices.length
          ? offices.map(o => `
              <button type="button" class="block w-full text-left px-3 py-2 text-sm hover:bg-blue-50" data-office-id="${o.id}">
                <span class="font-medium">${this.esc(o.label)}</span>
                <span class="text-gray-500 text-xs ml-1">${this.esc([o.level, o.body].filter(Boolean).join(" · "))}</span>
              </button>`).join("")
          : `<div class="px-3 py-2 text-sm text-gray-500">No offices found for “${this.esc(q)}” in ${this.esc(this.data.election.state)}</div>`
        this.officeResultsTarget.classList.remove("hidden")
        this.officeResultsTarget.querySelectorAll("[data-office-id]").forEach(btn => {
          btn.addEventListener("click", () => {
            this.officeIdTarget.value = btn.dataset.officeId
            this.officeSearchTarget.value = btn.querySelector("span").textContent
            this.officeResultsTarget.classList.add("hidden")
          })
        })
      } catch { /* search is best-effort */ }
    }, 250)
  }

  async createContest() {
    const officeId = this.officeIdTarget.value
    if (!officeId) {
      this.contestErrorTarget.textContent = "Pick an office from the search results"
      this.contestErrorTarget.classList.remove("hidden")
      return
    }
    this.contestCreateButtonTarget.disabled = true
    try {
      const resp = await fetch(this.data.urls.contests, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ office_id: officeId, party: this.contestPartyTarget.value })
      })
      const body = await resp.json()
      if (!resp.ok) throw new Error(body.error || "Could not create contest")

      const hadNoContests = this.data.contests.length === 0
      if (!this.data.contests.some(c => c.id === body.contest.id)) this.data.contests.push(body.contest)
      this.renderContestFilter()
      this.contestFilterTarget.value = String(body.contest.id)
      if (hadNoContests) this.renderBody()
      this.tbodyTarget.querySelectorAll('select[data-field="contestId"]').forEach(select => {
        const current = select.value
        const row = this.rows.find(r => r.key === select.closest("tr").dataset.key)
        select.innerHTML = this.contestOptionsHtml(row?.contestId ?? current)
      })
      this.applyFilter()
      this.closeContestDialog()
      this.showToast(`Contest created: ${body.contest.label}`, "success")
    } catch (err) {
      this.contestErrorTarget.textContent = err.message
      this.contestErrorTarget.classList.remove("hidden")
    } finally {
      this.contestCreateButtonTarget.disabled = false
    }
  }

  // ---------- misc ----------

  showToast(message, type = "info") {
    const el = this.toastTarget
    el.textContent = message
    el.className = el.className.replace(/bg-\S+/g, "")
    el.classList.add(type === "success" ? "bg-green-600" : type === "error" ? "bg-red-600" : "bg-gray-800")
    el.classList.remove("hidden")
    clearTimeout(this.toastTimer)
    this.toastTimer = setTimeout(() => el.classList.add("hidden"), 4500)
  }

  esc(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;").replaceAll("'", "&#39;")
  }
}
