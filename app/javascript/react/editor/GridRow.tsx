import * as React from "react"
import { X } from "lucide-react"
import type { ContestOption, RowState } from "./types"
import { isBlankNewRow, isDirty, suspiciousHandle } from "./rows"

type GridRowProps = {
  row: RowState
  visible: boolean
  contests: ContestOption[]
  parties: string[]
  outcomes: string[]
  genders: string[]
  races: string[]
  platforms: string[]
  onPatch: (key: string, patch: Partial<RowState>) => void
  onPatchSocial: (key: string, platform: string, value: string) => void
  onDelete: (key: string) => void
  onNameInput: (key: string, anchor: HTMLInputElement) => void
}

function statusFor(row: RowState, platforms: string[]): { color: string; title: string } {
  if (row.errors.length) return { color: "#dc2626", title: row.errors.join("\n") }
  if (row.justSaved) return { color: "#16a34a", title: "Saved ✓" }
  if (!row.candidateId && isBlankNewRow(row, platforms)) return { color: "#e5e7eb", title: "Empty row" }
  if (isDirty(row, platforms)) {
    return row.candidateId
      ? { color: "#f59e0b", title: "Modified — unsaved" }
      : { color: "#3b82f6", title: "New — unsaved" }
  }
  return { color: "#d1d5db", title: "Saved" }
}

function ContestSelect({ value, contests, onChange }: {
  value: number | null
  contests: ContestOption[]
  onChange: (id: number | null) => void
}) {
  const groups = new Map<string, ContestOption[]>()
  for (const contest of contests) {
    if (!groups.has(contest.ballotLabel)) groups.set(contest.ballotLabel, [])
    groups.get(contest.ballotLabel)!.push(contest)
  }
  return (
    <select
      className="ee-cell"
      data-cell="contestId"
      value={value ?? ""}
      onChange={e => onChange(e.target.value ? Number(e.target.value) : null)}
    >
      <option value="">—</option>
      {[...groups.entries()].map(([ballotLabel, options]) => (
        <optgroup key={ballotLabel} label={ballotLabel}>
          {options.map(option => (
            <option key={option.id} value={option.id}>{option.label}</option>
          ))}
        </optgroup>
      ))}
    </select>
  )
}

export const GridRow = React.memo(function GridRow({
  row, visible, contests, parties, outcomes, genders, races, platforms,
  onPatch, onPatchSocial, onDelete, onNameInput
}: GridRowProps) {
  const status = statusFor(row, platforms)

  return (
    <tr data-key={row.key} className={row.errors.length ? "ee-row-error" : undefined} style={visible ? undefined : { display: "none" }}>
      <td className="ee-c0">
        <span
          className="ee-status-dot"
          style={{ background: status.color }}
          title={status.title + (row.warnings.length ? `\n${row.warnings.join("\n")}` : "")}
        />
      </td>
      <td className="ee-c1">
        <ContestSelect value={row.contestId} contests={contests} onChange={id => onPatch(row.key, { contestId: id })} />
      </td>
      <td className="ee-c2">
        <input
          type="text" className="ee-cell" data-cell="firstName" placeholder="First"
          autoComplete="off" spellCheck={false} value={row.firstName}
          onChange={e => {
            onPatch(row.key, { firstName: e.target.value })
            if (!row.personId) onNameInput(row.key, e.currentTarget)
          }}
        />
      </td>
      <td className="ee-c3">
        <input
          type="text" className="ee-cell" data-cell="lastName" placeholder="Last"
          autoComplete="off" spellCheck={false} value={row.lastName}
          onChange={e => {
            onPatch(row.key, { lastName: e.target.value })
            if (!row.personId) onNameInput(row.key, e.currentTarget)
          }}
        />
      </td>
      <td>
        <select className="ee-cell" data-cell="party" value={row.party} onChange={e => onPatch(row.key, { party: e.target.value })}>
          <option value="">—</option>
          {parties.map(party => <option key={party} value={party}>{party}</option>)}
        </select>
      </td>
      <td className="text-center align-middle">
        <input
          type="checkbox" data-cell="incumbent"
          className="m-2 rounded border-gray-300 text-blue-600"
          checked={row.incumbent}
          onChange={e => onPatch(row.key, { incumbent: e.target.checked })}
        />
      </td>
      <td>
        <select className="ee-cell" data-cell="outcome" value={row.outcome} onChange={e => onPatch(row.key, { outcome: e.target.value })}>
          {outcomes.map(outcome => (
            <option key={outcome} value={outcome}>{outcome[0].toUpperCase() + outcome.slice(1)}</option>
          ))}
        </select>
      </td>
      <td>
        <select className="ee-cell" data-cell="gender" value={row.gender} onChange={e => onPatch(row.key, { gender: e.target.value })}>
          <option value="">—</option>
          {genders.map(gender => <option key={gender} value={gender}>{gender}</option>)}
        </select>
      </td>
      <td>
        <select className="ee-cell" data-cell="race" value={row.race} onChange={e => onPatch(row.key, { race: e.target.value })}>
          <option value="">—</option>
          {races.map(race => <option key={race} value={race}>{race}</option>)}
        </select>
      </td>
      {platforms.map(platform => {
        const cell = row.socials[platform]
        const suspicious = suspiciousHandle(cell.value)
        const title = cell.verified
          ? `Verified — editing will flag for re-verification${cell.url ? `\n${cell.url}` : ""}`
          : suspicious
            ? "Unusual characters for a handle — double-check (saves anyway)"
            : cell.url || platform
        return (
          <td key={platform} className={`ee-social-cell${cell.verified ? " ee-social-verified" : ""}`}>
            <input
              type="text" data-cell={`social-${platform}`}
              className={`ee-cell${suspicious ? " ee-cell-invalid" : ""}`}
              placeholder="@" autoComplete="off" spellCheck={false}
              value={cell.value} title={title}
              onChange={e => onPatchSocial(row.key, platform, e.target.value)}
            />
          </td>
        )
      })}
      <td className="text-center">
        <button
          type="button"
          className="px-2 py-1 text-gray-400 hover:text-red-600"
          title="Delete row"
          onClick={() => onDelete(row.key)}
        >
          <X className="inline h-4 w-4" />
        </button>
      </td>
    </tr>
  )
})
