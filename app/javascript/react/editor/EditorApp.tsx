import * as React from "react"
import { ArrowDown, ArrowUp, FileUp, Plus } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { NativeSelect } from "@/components/ui/native-select"
import { useToast } from "@/components/ui/toast"
import { getJSON, postJSON } from "./api"
import { contestOptionLabel, GridRow } from "./GridRow"
import { ImportCsvDialog } from "./ImportCsvDialog"
import { NewContestDialog } from "./NewContestDialog"
import { PersonTypeahead, type TypeaheadState } from "./PersonTypeahead"
import {
  applySaveResult, initialRows, isBlankNewRow, isDirty, linkPerson, makeImportedRow, makeRow,
  mergeImportIntoRow, rowPayload
} from "./rows"
import type { ContestOption, Payload, PersonResult, RowState, SaveResponse, StagedImportRow } from "./types"

export function EditorApp({ payload }: { payload: Payload }) {
  const toast = useToast()
  const platforms = payload.platforms

  const [rows, setRows] = React.useState<RowState[]>(() => initialRows(payload))
  const [contests, setContests] = React.useState<ContestOption[]>(payload.contests)
  const [deletedCandidateIds, setDeletedCandidateIds] = React.useState<number[]>([])
  const [contestFilter, setContestFilter] = React.useState("")
  const [search, setSearch] = React.useState("")
  const [saving, setSaving] = React.useState(false)
  const [dialogOpen, setDialogOpen] = React.useState(false)
  const [importOpen, setImportOpen] = React.useState(false)
  const [typeahead, setTypeahead] = React.useState<TypeaheadState | null>(null)
  const [sort, setSort] = React.useState<{ key: string; dir: 1 | -1 } | null>(null)
  const [rowOrder, setRowOrder] = React.useState<string[] | null>(null)

  const tableRef = React.useRef<HTMLTableElement>(null)
  const typeaheadTimer = React.useRef<ReturnType<typeof setTimeout>>()
  const pendingFocus = React.useRef<{ key: string; cell: string } | null>(null)

  // Row tint per contest, keyed by ballot party: Dem blue, Rep red, other
  // parties pick up distinct hues in order of appearance.
  const contestTints = React.useMemo(() => {
    const PARTY_TINTS: Record<string, string> = { Democratic: "#eff6ff", Republican: "#fff1f2" }
    const EXTRA_TINTS = ["#f0fdf4", "#faf5ff", "#fffbeb", "#ecfeff", "#f7fee7", "#fdf2f8"]
    const byParty = new Map<string, string>()
    const map = new Map<number, string>()
    let nextExtra = 0
    for (const contest of contests) {
      if (!contest.party) { map.set(contest.id, "#ffffff"); continue }
      if (!byParty.has(contest.party)) {
        byParty.set(contest.party, PARTY_TINTS[contest.party] ?? EXTRA_TINTS[nextExtra++ % EXTRA_TINTS.length])
      }
      map.set(contest.id, byParty.get(contest.party)!)
    }
    return map
  }, [contests])


  // ---------- row mutation ----------

  const patchRow = React.useCallback((key: string, patch: Partial<RowState>) => {
    setRows(current => current.map(row =>
      row.key === key ? { ...row, ...patch, justSaved: false } : row
    ))
  }, [])

  const patchSocial = React.useCallback((key: string, platform: string, value: string) => {
    setRows(current => current.map(row =>
      row.key === key
        ? { ...row, justSaved: false, socials: { ...row.socials, [platform]: { ...row.socials[platform], value } } }
        : row
    ))
  }, [])

  const deleteRow = React.useCallback((key: string) => {
    setRows(current => {
      const row = current.find(r => r.key === key)
      if (!row) return current
      if (row.candidateId) {
        const ok = confirm(
          `Remove ${row.firstName} ${row.lastName} from this contest?\n` +
          "(The person and their social accounts are kept — only the candidacy is removed.)"
        )
        if (!ok) return current
        setDeletedCandidateIds(ids => [...ids, row.candidateId!])
      }
      return current.filter(r => r.key !== key)
    })
    setTypeahead(null)
  }, [])

  const addRow = React.useCallback(() => {
    if (contests.length === 0) {
      toast("Create a contest first", "error")
      return
    }
    const row = makeRow({ contestId: contestFilter ? Number(contestFilter) : null }, platforms)
    pendingFocus.current = { key: row.key, cell: "firstName" }
    setRows(current => [...current, row])
  }, [contests.length, contestFilter, platforms, toast])

  // Auto-add a starter row on an empty election
  React.useEffect(() => {
    if (rows.length === 0 && contests.length > 0) addRow()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // Focus newly added rows
  React.useEffect(() => {
    if (!pendingFocus.current) return
    const { key, cell } = pendingFocus.current
    pendingFocus.current = null
    tableRef.current
      ?.querySelector<HTMLInputElement>(`tr[data-key="${key}"] [data-cell="${cell}"]`)
      ?.focus()
  }, [rows])

  // ---------- derived state ----------

  const dirtyRows = rows.filter(r => isDirty(r, platforms) && !isBlankNewRow(r, platforms))
  const errorCount = rows.filter(r => r.errors.length > 0).length
  const pending = dirtyRows.length + deletedCandidateIds.length

  React.useEffect(() => {
    const handler = (e: BeforeUnloadEvent) => {
      if (pending > 0) { e.preventDefault(); e.returnValue = "" }
    }
    window.addEventListener("beforeunload", handler)
    return () => window.removeEventListener("beforeunload", handler)
  }, [pending])

  // ---------- person typeahead ----------

  const handleNameInput = React.useCallback((key: string, anchor: HTMLInputElement) => {
    clearTimeout(typeaheadTimer.current)
    typeaheadTimer.current = setTimeout(async () => {
      const row = rowsRef.current.find(r => r.key === key)
      if (!row || row.personId) return
      const query = `${row.firstName} ${row.lastName}`.trim()
      if (query.length < 2) { setTypeahead(null); return }
      try {
        const { people } = await getJSON<{ people: PersonResult[] }>(
          `${payload.urls.people}?q=${encodeURIComponent(query)}`
        )
        if (document.activeElement !== anchor || people.length === 0) { setTypeahead(null); return }
        const rect = anchor.getBoundingClientRect()
        setTypeahead({ rowKey: key, rect: { left: rect.left, bottom: rect.bottom }, people, activeIndex: -1 })
      } catch { /* best-effort */ }
    }, 250)
  }, [payload.urls.people])

  // rows snapshot for async callbacks
  const rowsRef = React.useRef(rows)
  rowsRef.current = rows

  const selectPerson = React.useCallback((person: PersonResult) => {
    const state = typeahead
    setTypeahead(null)
    if (!state) return
    setRows(current => current.map(row =>
      row.key === state.rowKey ? linkPerson(row, person, platforms) : row
    ))
    pendingFocus.current = { key: state.rowKey, cell: "party" }
    toast(`Linked to existing person: ${person.fullName}`, "info")
  }, [typeahead, platforms, toast])

  // ---------- keyboard ----------

  const onTableKeyDown = (e: React.KeyboardEvent) => {
    if (typeahead) {
      if (e.key === "Escape") { e.preventDefault(); setTypeahead(null); return }
      if (e.key === "ArrowDown" || e.key === "ArrowUp") {
        e.preventDefault()
        setTypeahead(t => t && {
          ...t,
          activeIndex: e.key === "ArrowDown"
            ? Math.min(t.activeIndex + 1, t.people.length - 1)
            : Math.max(t.activeIndex - 1, 0)
        })
        return
      }
      if (e.key === "Enter" && typeahead.activeIndex >= 0) {
        e.preventDefault()
        selectPerson(typeahead.people[typeahead.activeIndex])
        return
      }
    }
    if (e.key !== "Enter") return
    const target = e.target as HTMLElement
    if (!(target instanceof HTMLInputElement || target instanceof HTMLSelectElement)) return
    e.preventDefault()
    setTypeahead(null)

    const td = target.closest("td")
    const tr = target.closest("tr")
    if (!td || !tr) return
    const cellIndex = Array.from(tr.children).indexOf(td)
    let targetTr = e.shiftKey ? tr.previousElementSibling : tr.nextElementSibling
    while (targetTr && (targetTr as HTMLElement).style.display === "none") {
      targetTr = e.shiftKey ? targetTr.previousElementSibling : targetTr.nextElementSibling
    }
    if (!targetTr && !e.shiftKey) {
      addRow()
      return
    }
    (targetTr?.children[cellIndex]?.querySelector("input, select") as HTMLElement | null)?.focus()
  }

  React.useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "s") { e.preventDefault(); save() }
    }
    document.addEventListener("keydown", handler)
    return () => document.removeEventListener("keydown", handler)
  })

  // ---------- save ----------

  const save = async () => {
    if (saving) return
    const candidates = rowsRef.current.filter(r => isDirty(r, platforms) && !isBlankNewRow(r, platforms))

    // Validate synchronously. Do NOT compute `valid` as a side effect inside a
    // setRows updater: React may defer that updater, so `valid` would still be
    // empty when we read it below and the save would silently no-op (the
    // reported "save button does nothing / only one row saves" bug).
    const rowErrors = new Map<string, string[]>()
    for (const row of candidates) {
      const errors: string[] = []
      if (!row.contestId) errors.push("Contest is required")
      if (!row.firstName.trim()) errors.push("First name is required")
      if (!row.lastName.trim()) errors.push("Last name is required")
      if (errors.length) rowErrors.set(row.key, errors)
    }
    const valid = candidates.filter(r => !rowErrors.has(r.key))
    const skipped = rowErrors.size

    // Reflect validation state in the grid (pure updater: set errors on bad
    // rows, clear stale errors on the rows we're about to save).
    setRows(current => current.map(row => {
      if (!candidates.some(c => c.key === row.key)) return row
      const errors = rowErrors.get(row.key)
      if (errors) return { ...row, errors }
      return row.errors.length ? { ...row, errors: [] } : row
    }))

    if (valid.length === 0 && deletedCandidateIds.length === 0) {
      if (skipped) toast(`${skipped} row(s) have missing required fields`, "error")
      return
    }

    setSaving(true)
    try {
      const response = await postJSON<SaveResponse>(payload.urls.save, {
        rows: valid.map(r => rowPayload(r, platforms)),
        deletedCandidateIds
      })

      // Derive counts from the response itself, not as side effects inside the
      // setRows updater (which React may defer — that made the toast report
      // "Saved 0 rows" even when rows saved fine).
      const resultByKey = new Map(response.results.map(r => [r.key, r]))
      const saved = response.results.filter(r => r.ok).length
      const failed = response.results.filter(r => !r.ok).length
      const warnings = response.results.flatMap(r => (r.ok ? r.warnings ?? [] : []))

      setRows(current => current.map(row => {
        const result = resultByKey.get(row.key)
        if (!result) return row
        return result.ok
          ? applySaveResult(row, result, platforms)
          : { ...row, errors: result.errors ?? ["Save failed"] }
      }))
      setDeletedCandidateIds(ids => ids.filter(id => !response.deleted.includes(id)))

      setTimeout(() => {
        setRows(current => current.map(row => row.justSaved ? { ...row, justSaved: false } : row))
      }, 2500)

      let message = `Saved ${saved} row${saved === 1 ? "" : "s"}`
      if (response.deleted.length) message += `, deleted ${response.deleted.length}`
      if (failed) message += ` · ${failed} failed`
      if (skipped) message += ` · ${skipped} skipped (missing fields)`
      toast(message, failed || skipped ? "error" : "success")
      if (warnings.length) setTimeout(() => toast(warnings[0], "info"), 1200)
    } catch (e) {
      toast(e instanceof Error ? e.message : "Save failed — check your connection", "error")
    } finally {
      setSaving(false)
    }
  }

  // ---------- sorting ----------
  // Sorting snapshots an order of row keys rather than live-sorting, so rows
  // don't jump around while the user is typing. Click a header again to
  // re-apply (toggles direction). New rows append at the bottom.

  const sortValueFor = (row: RowState, key: string): string | number => {
    switch (key) {
      case "contest": {
        const contest = contests.find(c => c.id === row.contestId)
        return contest ? contestOptionLabel(contest) : ""
      }
      case "incumbent": return row.incumbent ? 0 : 1
      case "firstName": return row.firstName
      case "middleName": return row.middleName
      case "lastName": return row.lastName
      case "suffix": return row.suffix
      case "party": return row.party
      case "outcome": return row.outcome
      case "gender": return row.gender
      case "race": return row.race
      case "website": return row.website
      default: return row.socials[key]?.value ?? ""
    }
  }

  const applySort = (key: string) => {
    const dir: 1 | -1 = sort?.key === key && sort.dir === 1 ? -1 : 1
    const sorted = [...rowsRef.current].sort((a, b) => {
      const av = sortValueFor(a, key)
      const bv = sortValueFor(b, key)
      const aEmpty = av === ""
      const bEmpty = bv === ""
      if (aEmpty !== bEmpty) return aEmpty ? 1 : -1 // blanks last either direction
      if (typeof av === "number" && typeof bv === "number") return dir * (av - bv)
      return dir * String(av).localeCompare(String(bv), undefined, { sensitivity: "base" })
    })
    setSort({ key, dir })
    setRowOrder(sorted.map(r => r.key))
  }

  const displayRows = React.useMemo(() => {
    if (!rowOrder) return rows
    const byKey = new Map(rows.map(r => [r.key, r]))
    const ordered: RowState[] = []
    for (const key of rowOrder) {
      const row = byKey.get(key)
      if (row) { ordered.push(row); byKey.delete(key) }
    }
    for (const row of rows) if (byKey.has(row.key)) ordered.push(row)
    return ordered
  }, [rows, rowOrder])

  const SortableTh = ({ sortKey, className, children }: {
    sortKey: string
    className?: string
    children: React.ReactNode
  }) => (
    <th className={className}>
      <button
        type="button"
        className="flex w-full items-center gap-1 uppercase tracking-[0.03em] text-gray-600 hover:text-gray-900"
        title="Sort"
        onClick={() => applySort(sortKey)}
      >
        {children}
        {sort?.key === sortKey && (sort.dir === 1
          ? <ArrowUp className="h-3 w-3 shrink-0 text-blue-600" />
          : <ArrowDown className="h-3 w-3 shrink-0 text-blue-600" />)}
      </button>
    </th>
  )

  // ---------- contest creation ----------

  const handleContestCreated = (contest: ContestOption) => {
    setContests(current => current.some(c => c.id === contest.id) ? current : [...current, contest])
    setContestFilter(String(contest.id))
    toast(`Contest created: ${contest.label}`, "success")
  }

  // ---------- CSV import ----------

  // Staged rows arrive validated with their contest already resolved/created.
  // Rows for people already candidates in a contest merge into that grid row;
  // the rest append as new dirty rows. Nothing is saved until the user saves.
  const handleImported = (newContests: ContestOption[], staged: StagedImportRow[]) => {
    if (newContests.length > 0) {
      setContests(current => [
        ...current,
        ...newContests.filter(contest => !current.some(c => c.id === contest.id))
      ])
    }
    let merged = 0
    setRows(current => {
      const next = [...current]
      const appended: RowState[] = []
      for (const { row: imp, contestId } of staged) {
        if (imp.mergeCandidateId) {
          const i = next.findIndex(r => r.candidateId === imp.mergeCandidateId)
          if (i >= 0) {
            next[i] = mergeImportIntoRow(next[i], imp, platforms)
            merged++
            continue
          }
        }
        appended.push(makeImportedRow(imp, contestId, platforms))
      }
      return next.concat(appended)
    })
    setContestFilter("")
    setRowOrder(null)
    const parts = [`Imported ${staged.length} row${staged.length === 1 ? "" : "s"}`]
    if (merged) parts.push(`${merged} merged into existing candidates`)
    if (newContests.length) parts.push(`${newContests.length} contest${newContests.length === 1 ? "" : "s"} created`)
    toast(`${parts.join(" · ")} — review and Save`, "success")
  }

  // ---------- render ----------

  const visibleKey = (row: RowState) => {
    const matchContest = !contestFilter || String(row.contestId) === contestFilter
    const term = search.trim().toLowerCase()
    const matchTerm = !term || `${row.firstName} ${row.lastName}`.toLowerCase().includes(term)
    return matchContest && matchTerm
  }

  const counts: string[] = [`${rows.length} row${rows.length === 1 ? "" : "s"}`]
  if (dirtyRows.length) counts.push(`${dirtyRows.length} unsaved`)
  if (deletedCandidateIds.length) counts.push(`${deletedCandidateIds.length} deletion${deletedCandidateIds.length === 1 ? "" : "s"} pending`)
  if (errorCount) counts.push(`${errorCount} error${errorCount === 1 ? "" : "s"}`)

  return (
    <div>
      {/* Toolbar */}
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="flex items-center gap-2">
          <label className="text-sm font-medium text-gray-600">Contest</label>
          <NativeSelect className="h-8 w-auto" value={contestFilter} onChange={e => setContestFilter(e.target.value)}>
            <option value="">All contests</option>
            {contests.map(contest => (
              <option key={contest.id} value={contest.id}>{contestOptionLabel(contest)}</option>
            ))}
          </NativeSelect>
          <Button variant="link" size="sm" onClick={() => setDialogOpen(true)}>+ New contest</Button>
          <Button variant="outline" size="sm" onClick={() => setImportOpen(true)}>
            <FileUp className="h-4 w-4" /> Import CSV
          </Button>
        </div>
        <Input
          type="search" placeholder="Search names…" className="h-8 w-56"
          value={search} onChange={e => setSearch(e.target.value)}
        />
        <div className="flex-1" />
        <span className="text-sm text-gray-500">{counts.join(" · ")}</span>
        <Button onClick={save} disabled={saving || pending === 0}>
          {saving ? "Saving…" : pending ? `Save (${pending})` : "Save"}
        </Button>
      </div>

      {/* Grid */}
      <div className="overflow-auto rounded-lg border border-gray-200 bg-white shadow-sm" style={{ maxHeight: "calc(100vh - 180px)" }}>
        <table ref={tableRef} className="ee-grid w-full" onKeyDown={onTableKeyDown}>
          <thead>
            <tr>
              <th className="ee-c0"></th>
              <SortableTh sortKey="contest" className="ee-c1">Contest</SortableTh>
              <SortableTh sortKey="firstName" className="ee-c2">First</SortableTh>
              <SortableTh sortKey="middleName" className="ee-c3">Mid.</SortableTh>
              <SortableTh sortKey="lastName" className="ee-c4">Last</SortableTh>
              <SortableTh sortKey="suffix" className="ee-c5">Sfx</SortableTh>
              <SortableTh sortKey="party">Party</SortableTh>
              <SortableTh sortKey="incumbent" className="text-center">Inc.</SortableTh>
              <SortableTh sortKey="outcome">Outcome</SortableTh>
              <SortableTh sortKey="gender">Gender</SortableTh>
              <SortableTh sortKey="race">Race</SortableTh>
              <SortableTh sortKey="website">Website</SortableTh>
              {platforms.map(platform => (
                <SortableTh key={platform} sortKey={platform} className="bg-blue-50/70">
                  <span
                    className="shrink-0"
                    dangerouslySetInnerHTML={{ __html: payload.platformIcons[platform] ?? "" }}
                  />
                  {platform}
                </SortableTh>
              ))}
              <th></th>
            </tr>
          </thead>
          <tbody>
            {contests.length === 0 ? (
              <tr>
                <td colSpan={13 + platforms.length} className="px-4 py-10 text-center text-sm text-gray-500">
                  No contests in this election yet — click “+ New contest” to create one, then add candidates.
                </td>
              </tr>
            ) : displayRows.map(row => (
              <GridRow
                key={row.key}
                row={row}
                visible={visibleKey(row)}
                tint={contestTints.get(row.contestId ?? -1) ?? "#ffffff"}
                contests={contests}
                parties={payload.parties}
                outcomes={payload.outcomes}
                genders={payload.genders}
                races={payload.races}
                platforms={platforms}
                onPatch={patchRow}
                onPatchSocial={patchSocial}
                onDelete={deleteRow}
                onNameInput={handleNameInput}
              />
            ))}
          </tbody>
        </table>
      </div>

      {/* Footer */}
      <div className="mt-3 flex items-center gap-3">
        <Button variant="outline" size="sm" onClick={addRow}>
          <Plus className="h-4 w-4" /> Add row
        </Button>
        <span className="text-xs text-gray-400">
          Enter ↵ next row · Shift+Enter ↑ · ⌘S save · type a name to link an existing person
        </span>
      </div>

      {typeahead && <PersonTypeahead state={typeahead} onSelect={selectPerson} />}

      <NewContestDialog
        payload={payload}
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        onCreated={handleContestCreated}
      />

      <ImportCsvDialog
        payload={payload}
        open={importOpen}
        onOpenChange={setImportOpen}
        onImported={handleImported}
      />
    </div>
  )
}
