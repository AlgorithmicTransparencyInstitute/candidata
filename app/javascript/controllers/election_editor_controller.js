import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [""]

  connect() {
    this.currentContestId = null
    this.candidatesData = {}
    this.socialMediaPlatforms = [
      'facebook', 'twitter', 'instagram', 'youtube', 'tiktok',
      'bluesky', 'truthsocial', 'gettr', 'rumble', 'telegram', 'threads'
    ]
  }

  // Handle state selection
  onStateChange(event) {
    const stateId = event.target.value
    this.clearSelections()
  }

  // Handle ballot type selection
  onBallotTypeChange(event) {
    this.clearSelections()
  }

  // Handle contest selection
  onContestChange(event) {
    const contestId = event.target.value
    this.currentContestId = contestId

    if (!contestId) {
      this.clearTable()
      return
    }

    // Load candidates for this contest
    this.loadCandidates(contestId)
  }

  async loadCandidates(contestId) {
    try {
      // For now, we'll just clear and let users add rows
      // In the next phase, we'll fetch actual candidates from API
      this.clearTable()
      this.updateRowCount()
    } catch (error) {
      console.error('Error loading candidates:', error)
      alert('Error loading candidates')
    }
  }

  addCandidateRow(event) {
    event.preventDefault()

    const template = document.getElementById('candidate-row-template')
    const tbody = document.querySelector('[data-tbody="candidates"]')

    // Clear placeholder row if it exists
    const placeholderRow = tbody.querySelector('tr:has(td[colspan])')
    if (placeholderRow) {
      placeholderRow.remove()
    }

    // Clone template and add to table
    const newRow = template.content.cloneNode(true)
    const rowElement = newRow.querySelector('tr')
    rowElement.dataset.candidateId = `new-${Date.now()}`

    tbody.appendChild(newRow)
    this.updateRowCount()

    // Focus on the name field
    const nameInput = rowElement.querySelector('[data-field="name"]')
    if (nameInput) {
      nameInput.focus()
    }
  }

  deleteRow(event) {
    event.preventDefault()
    const row = event.target.closest('tr')

    if (confirm('Delete this candidate row?')) {
      row.remove()
      this.updateRowCount()
    }
  }

  clearTable() {
    const tbody = document.querySelector('[data-tbody="candidates"]')
    const rows = tbody.querySelectorAll('tr:not(:has(td[colspan]))')
    rows.forEach(row => row.remove())

    // Show placeholder if no candidates
    if (tbody.querySelectorAll('tr').length === 0) {
      tbody.innerHTML = `
        <tr class="hover:bg-gray-50">
          <td colspan="16" class="px-4 py-8 text-center text-gray-500">
            No candidates yet. Click "Add Candidate Row" to get started.
          </td>
        </tr>
      `
    }

    this.updateRowCount()
  }

  clearSelections() {
    this.currentContestId = null
    this.clearTable()
  }

  updateRowCount() {
    const tbody = document.querySelector('[data-tbody="candidates"]')
    const rows = tbody.querySelectorAll('tr:not(:has(td[colspan]))')
    const count = document.querySelector('[data-count="row-count"]')
    if (count) {
      count.textContent = `${rows.length} candidate${rows.length !== 1 ? 's' : ''}`
    }
  }

  async saveAll(event) {
    event.preventDefault()

    if (!this.currentContestId) {
      alert('Please select a contest first')
      return
    }

    const tbody = document.querySelector('[data-tbody="candidates"]')
    const rows = tbody.querySelectorAll('tr:not(:has(td[colspan]))')

    const candidates = Array.from(rows).map(row => {
      const candidateId = row.dataset.candidateId

      const getData = (field) => {
        const input = row.querySelector(`[data-field="${field}"]`)
        if (!input) return null

        if (input.type === 'checkbox') {
          return input.checked
        }
        return input.value || null
      }

      return {
        id: candidateId.startsWith('new-') ? null : candidateId,
        contest_id: this.currentContestId,
        name: getData('name'),
        party_id: getData('party'),
        outcome: getData('outcome'),
        incumbent: getData('incumbent'),
        socialMedia: {
          facebook: getData('facebook'),
          twitter: getData('twitter'),
          instagram: getData('instagram'),
          youtube: getData('youtube'),
          tiktok: getData('tiktok'),
          bluesky: getData('bluesky'),
          truthsocial: getData('truthsocial'),
          gettr: getData('gettr'),
          rumble: getData('rumble'),
          telegram: getData('telegram'),
          threads: getData('threads')
        }
      }
    })

    console.log('Saving candidates:', candidates)

    // TODO: Send to API
    alert(`Ready to save ${candidates.length} candidates. API integration coming next!`)
  }
}
