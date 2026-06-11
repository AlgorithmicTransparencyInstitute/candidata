import * as React from "react"
import { Badge } from "@/components/ui/badge"
import type { PersonResult } from "./types"

export type TypeaheadState = {
  rowKey: string
  rect: { left: number; bottom: number }
  people: PersonResult[]
  activeIndex: number
}

// Floating person-match menu anchored under the active name cell. Selection by
// click or ArrowUp/Down + Enter (key handling lives in EditorApp so the grid's
// own Enter navigation can yield to the menu).
export function PersonTypeahead({ state, onSelect }: {
  state: TypeaheadState
  onSelect: (person: PersonResult) => void
}) {
  return (
    <div
      className="fixed z-[90] max-h-72 min-w-[320px] max-w-[420px] overflow-auto rounded-lg border border-gray-300 bg-white shadow-xl"
      style={{ left: state.rect.left, top: state.rect.bottom + 2 }}
    >
      {state.people.map((person, index) => (
        <div
          key={person.id}
          className={`cursor-pointer px-3 py-2 text-sm ${index === state.activeIndex ? "bg-blue-50" : "hover:bg-blue-50"}`}
          onMouseDown={e => { e.preventDefault(); onSelect(person) }}
        >
          <div className="font-medium text-gray-900">
            {person.fullName}
            {person.inThisElection && <Badge variant="warning" className="ml-2">already in this election</Badge>}
          </div>
          <div className="text-xs text-gray-500">
            {[person.state, person.party, `${Object.keys(person.socials).length} social account(s)`]
              .filter(Boolean).join(" · ")}
          </div>
        </div>
      ))}
    </div>
  )
}
