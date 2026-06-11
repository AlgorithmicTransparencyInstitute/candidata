import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  connect() {
    console.log("Election editor connected")
  }

  switchBallot(event) {
    const ballotId = event.currentTarget.dataset.ballotId
    const tabIndex = event.currentTarget.dataset.tabIndex

    // Hide all panels
    this.element.querySelectorAll('[data-ballot-panel]').forEach(panel => {
      panel.classList.add('hidden')
    })

    // Show selected panel
    const selectedPanel = this.element.querySelector(`[data-ballot-panel="${ballotId}"]`)
    if (selectedPanel) {
      selectedPanel.classList.remove('hidden')
    }

    // Update tab styles
    this.element.querySelectorAll('[role="tab"]').forEach((tab, idx) => {
      if (idx == tabIndex) {
        tab.classList.remove('border-transparent', 'text-gray-600')
        tab.classList.add('border-blue-500', 'text-blue-600')
      } else {
        tab.classList.remove('border-blue-500', 'text-blue-600')
        tab.classList.add('border-transparent', 'text-gray-600')
      }
    })
  }

  addBallot(event) {
    alert("Add ballot feature coming soon")
  }

  addContest(event) {
    const ballotId = event.currentTarget.dataset.ballotId
    alert(`Add contest to ballot ${ballotId} - coming soon`)
  }

  addCandidate(event) {
    const contestId = event.currentTarget.dataset.contestId
    alert(`Add candidate to contest ${contestId} - coming soon`)
  }

  save(event) {
    event.preventDefault()
    alert("Save feature coming soon - collecting form data")

    // Collect all form data
    const ballots = []
    this.element.querySelectorAll('[data-ballot-id]').forEach(ballotPanel => {
      const ballotId = ballotPanel.dataset.ballotId
      const contests = []

      ballotPanel.querySelectorAll('table').forEach(table => {
        const candidates = []
        table.querySelectorAll('tbody tr:not(:last-child)').forEach(row => {
          const nameInput = row.querySelector('input[type="text"]')
          const partySelect = row.querySelector('select:nth-of-type(1)')
          const outcomeSelect = row.querySelector('select:nth-of-type(2)')
          const incumbentCheckbox = row.querySelector('input[type="checkbox"]')

          if (nameInput && nameInput.value) {
            candidates.push({
              name: nameInput.value,
              party: partySelect?.value,
              outcome: outcomeSelect?.value,
              incumbent: incumbentCheckbox?.checked
            })
          }
        })
        contests.push({ candidates })
      })

      ballots.push({ ballotId, contests })
    })

    console.log("Collected data:", ballots)
  }
}
