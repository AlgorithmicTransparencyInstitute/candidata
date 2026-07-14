import * as React from "react"
import { FileUp } from "lucide-react"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { NativeSelect } from "@/components/ui/native-select"
import { getJSON, postJSON } from "./api"
import type {
  ContestOption, ImportContestGroup, ImportPreview, ImportRow, OfficeResult, Payload, StagedImportRow
} from "./types"

// CSV import flow: upload → server-side preview (parse, column mapping,
// validation, office/contest/person matching) → user fixes the mapping and
// resolves any unmatched offices → confirm. Confirm creates missing
// ballots+contests through the existing contests endpoint, then hands the
// staged rows to the grid as unsaved (dirty) rows — nothing touches
// people/candidates/socials until the user reviews and hits Save.
export function ImportCsvDialog({ payload, open, onOpenChange, onImported }: {
  payload: Payload
  open: boolean
  onOpenChange: (open: boolean) => void
  onImported: (newContests: ContestOption[], staged: StagedImportRow[]) => void
}) {
  const [fileName, setFileName] = React.useState("")
  const [csvText, setCsvText] = React.useState<string | null>(null)
  const [preview, setPreview] = React.useState<ImportPreview | null>(null)
  const [resolutions, setResolutions] = React.useState<Record<string, OfficeResult>>({})
  const [skipWithdrawn, setSkipWithdrawn] = React.useState(true)
  const [busy, setBusy] = React.useState(false)
  const [importing, setImporting] = React.useState(false)
  const [error, setError] = React.useState("")
  const [showDetails, setShowDetails] = React.useState(false)

  React.useEffect(() => {
    if (!open) {
      setFileName(""); setCsvText(null); setPreview(null); setResolutions({})
      setSkipWithdrawn(true); setError(""); setShowDetails(false)
    }
  }, [open])

  const runPreview = async (text: string, mapping?: Record<string, string>) => {
    setBusy(true)
    setError("")
    try {
      const body: { csv: string; mapping?: Record<string, string> } = { csv: text }
      if (mapping) body.mapping = mapping
      setPreview(await postJSON<ImportPreview>(payload.urls.import, body))
      setResolutions({})
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not read the CSV")
    } finally {
      setBusy(false)
    }
  }

  const handleFile = async (file: File | undefined) => {
    if (!file) return
    setFileName(file.name)
    const text = await file.text()
    setCsvText(text)
    await runPreview(text)
  }

  // Re-preview with an explicit full mapping whenever the user changes a column.
  const remap = (header: string, field: string) => {
    if (!preview || !csvText) return
    const mapping: Record<string, string> = {}
    for (const entry of preview.mapping) mapping[entry.header] = entry.field ?? ""
    mapping[header] = field
    void runPreview(csvText, mapping)
  }

  // Group status after client-side office resolutions are applied.
  const effectiveGroup = (group: ImportContestGroup): ImportContestGroup => {
    const office = resolutions[group.key]
    if (group.status !== "unresolved" || !office) return group
    return { ...group, status: "create", officeId: office.id, officeLabel: office.label, note: null }
  }

  const groups = (preview?.contestGroups ?? []).map(effectiveGroup)
  const groupByKey = new Map(groups.map(g => [g.key, g]))

  const rowIncluded = (row: ImportRow): boolean => {
    if (row.issues.length > 0) return false
    if (skipWithdrawn && row.withdrawn) return false
    const group = row.contestKey ? groupByKey.get(row.contestKey) : null
    return !!group && group.status !== "unresolved"
  }

  const includedRows = (preview?.rows ?? []).filter(rowIncluded)
  const issueRows = (preview?.rows ?? []).filter(r => r.issues.length > 0)
  const warningRows = (preview?.rows ?? []).filter(r => r.issues.length === 0 && r.warnings.length > 0)
  const withdrawnSkipped = skipWithdrawn ? (preview?.rows ?? []).filter(r => r.issues.length === 0 && r.withdrawn).length : 0
  const unresolvedGroups = groups.filter(g => g.status === "unresolved")
  const contestsToCreate = new Set(
    includedRows.filter(r => !r.contestId).map(r => r.contestKey!)
  )
  const mergeCount = includedRows.filter(r => r.mergeCandidateId).length
  const linkedCount = includedRows.filter(r => r.personId && !r.mergeCandidateId).length
  const newPeopleCount = includedRows.filter(r => !r.personId).length

  const doImport = async () => {
    if (!preview || importing) return
    setImporting(true)
    setError("")
    try {
      const created: Record<string, ContestOption> = {}
      const newContests: ContestOption[] = []
      for (const key of contestsToCreate) {
        const group = groupByKey.get(key)
        if (!group?.officeId) continue
        const { contest } = await postJSON<{ contest: ContestOption }>(payload.urls.contests, {
          office_id: group.officeId,
          party: group.party ?? ""
        })
        created[key] = contest
        if (!newContests.some(c => c.id === contest.id)) newContests.push(contest)
      }
      const staged: StagedImportRow[] = []
      for (const row of includedRows) {
        const contestId = row.contestId ?? created[row.contestKey ?? ""]?.id
        if (contestId) staged.push({ row, contestId })
      }
      onImported(newContests, staged)
      onOpenChange(false)
    } catch (e) {
      setError(e instanceof Error ? e.message : "Import failed")
    } finally {
      setImporting(false)
    }
  }

  const fileErrors = preview?.errors ?? []

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[85vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>Import candidates from CSV</DialogTitle>
          <DialogDescription>
            Rows are validated and staged into the grid as unsaved rows — review them, then Save.
            Missing party ballots and contests are created on import.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          {/* File picker */}
          <div className="flex items-center gap-3">
            <label className="inline-flex cursor-pointer items-center gap-2 rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50">
              <FileUp className="h-4 w-4" />
              {fileName ? "Choose a different file" : "Choose CSV file"}
              <input
                type="file"
                accept=".csv,text/csv"
                className="hidden"
                onChange={e => { void handleFile(e.target.files?.[0]); e.target.value = "" }}
              />
            </label>
            {fileName && <span className="text-sm text-gray-600">{fileName}</span>}
            {busy && <span className="text-sm text-gray-400">Analyzing…</span>}
          </div>

          {!preview && !busy && (
            <p className="text-xs text-gray-500">
              Expected columns: candidate name (or first/last name), party, office, district, plus
              optional incumbent, withdrew, outcome, gender, race, and one column per social platform.
              Unrecognized headers can be mapped manually after upload.
            </p>
          )}

          {/* Column mapping */}
          {preview && preview.mapping.length > 0 && (
            <div>
              <h3 className="mb-1.5 text-sm font-semibold text-gray-800">Column mapping</h3>
              <div className="grid grid-cols-2 gap-x-6 gap-y-1.5 sm:grid-cols-3">
                {preview.mapping.map(entry => (
                  <div key={entry.header} className="flex items-center gap-2">
                    <span className="w-2/5 truncate text-xs text-gray-600" title={entry.header}>{entry.header}</span>
                    <NativeSelect
                      className="h-7 flex-1 text-xs"
                      value={entry.field ?? ""}
                      disabled={busy}
                      onChange={e => remap(entry.header, e.target.value)}
                    >
                      <option value="">— ignored —</option>
                      {preview.fields.map(f => <option key={f.id} value={f.id}>{f.label}</option>)}
                    </NativeSelect>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* File-level errors */}
          {fileErrors.length > 0 && (
            <div className="rounded-md border border-red-200 bg-red-50 p-3 text-sm text-red-700">
              {fileErrors.map((e, i) => <p key={i}>{e}</p>)}
            </div>
          )}

          {/* Contests */}
          {preview && fileErrors.length === 0 && groups.length > 0 && (
            <div>
              <h3 className="mb-1.5 text-sm font-semibold text-gray-800">Contests</h3>
              <div className="divide-y divide-gray-100 rounded-md border border-gray-200">
                {groups.map(group => (
                  <div key={group.key} className="flex flex-wrap items-center gap-x-3 gap-y-1 px-3 py-2 text-sm">
                    <span className="font-medium text-gray-900">{group.label}</span>
                    {group.party && <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs text-gray-600">{group.party}</span>}
                    <span className="text-xs text-gray-400">{group.rowCount} row{group.rowCount === 1 ? "" : "s"}</span>
                    <span className="flex-1" />
                    {group.status === "matched" && (
                      <span className="text-xs text-green-700">✓ existing contest{group.officeLabel ? ` · ${group.officeLabel}` : ""}</span>
                    )}
                    {group.status === "create" && (
                      <span className="text-xs text-blue-700">+ will create contest · {group.officeLabel}</span>
                    )}
                    {group.status === "unresolved" && (
                      <OfficeResolver
                        payload={payload}
                        note={group.note}
                        onPick={office => setResolutions(current => ({ ...current, [group.key]: office }))}
                      />
                    )}
                  </div>
                ))}
              </div>
              {unresolvedGroups.length > 0 && (
                <p className="mt-1 text-xs text-amber-700">
                  Rows in unresolved contests are skipped unless you pick an office for them.
                </p>
              )}
            </div>
          )}

          {/* Summary + issues */}
          {preview && fileErrors.length === 0 && (
            <div className="space-y-2">
              <div className="rounded-md bg-gray-50 p-3 text-sm text-gray-700">
                <p>
                  <strong>{includedRows.length}</strong> of {preview.rows.length} rows will be added to the grid
                  {contestsToCreate.size > 0 && <> · <strong>{contestsToCreate.size}</strong> contest{contestsToCreate.size === 1 ? "" : "s"} will be created</>}
                </p>
                <p className="mt-0.5 text-xs text-gray-500">
                  {linkedCount} linked to existing people · {newPeopleCount} new people
                  {mergeCount > 0 && <> · {mergeCount} update existing candidates</>}
                  {withdrawnSkipped > 0 && <> · {withdrawnSkipped} withdrawn skipped</>}
                  {issueRows.length > 0 && <> · {issueRows.length} skipped with issues</>}
                </p>
              </div>

              {(preview.rows.some(r => r.withdrawn)) && (
                <label className="flex items-center gap-2 text-sm text-gray-700">
                  <input type="checkbox" checked={skipWithdrawn} onChange={e => setSkipWithdrawn(e.target.checked)} />
                  Skip withdrawn candidates
                </label>
              )}

              {(issueRows.length > 0 || warningRows.length > 0) && (
                <div className="text-xs">
                  <button type="button" className="text-blue-600 hover:underline" onClick={() => setShowDetails(s => !s)}>
                    {showDetails ? "Hide" : "Show"} row details
                    ({issueRows.length} issue{issueRows.length === 1 ? "" : "s"}, {warningRows.length} warning{warningRows.length === 1 ? "" : "s"})
                  </button>
                  {showDetails && (
                    <div className="mt-1 max-h-40 space-y-0.5 overflow-y-auto rounded-md border border-gray-200 p-2">
                      {issueRows.map(r => (
                        <p key={`i${r.index}`} className="text-red-700">
                          Row {r.index} ({r.firstName} {r.lastName}): {r.issues.join("; ")}
                        </p>
                      ))}
                      {warningRows.map(r => (
                        <p key={`w${r.index}`} className="text-amber-700">
                          Row {r.index} ({r.firstName} {r.lastName}): {r.warnings.join("; ")}
                        </p>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {error && <p className="text-sm text-red-600">{error}</p>}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
          <Button onClick={doImport} disabled={importing || busy || !preview || fileErrors.length > 0 || includedRows.length === 0}>
            {importing
              ? "Importing…"
              : `Add ${includedRows.length} row${includedRows.length === 1 ? "" : "s"} to grid`}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

// Inline office search for an unresolved contest group (same backend as the
// New Contest dialog's office typeahead).
function OfficeResolver({ payload, note, onPick }: {
  payload: Payload
  note: string | null
  onPick: (office: OfficeResult) => void
}) {
  const [query, setQuery] = React.useState("")
  const [results, setResults] = React.useState<OfficeResult[]>([])
  const timer = React.useRef<ReturnType<typeof setTimeout>>()

  const search = (value: string) => {
    setQuery(value)
    clearTimeout(timer.current)
    if (value.trim().length < 2) { setResults([]); return }
    timer.current = setTimeout(async () => {
      try {
        const { offices } = await getJSON<{ offices: OfficeResult[] }>(
          `${payload.urls.offices}?q=${encodeURIComponent(value.trim())}`
        )
        setResults(offices)
      } catch { /* best-effort */ }
    }, 250)
  }

  return (
    <div className="relative w-64">
      <Input
        className="h-7 text-xs"
        placeholder={note ?? "Search offices…"}
        title={note ?? undefined}
        value={query}
        autoComplete="off"
        onChange={e => search(e.target.value)}
      />
      {results.length > 0 && (
        <div className="absolute right-0 top-8 z-10 max-h-40 w-72 overflow-auto rounded-md border border-gray-200 bg-white shadow-lg">
          {results.map(office => (
            <button
              key={office.id}
              type="button"
              className="block w-full px-2.5 py-1.5 text-left text-xs hover:bg-blue-50"
              onClick={() => { onPick(office); setQuery(office.searchLabel ?? office.label); setResults([]) }}
            >
              <span className="font-medium">{office.label}</span>
              <span className="ml-1 text-gray-500">{[office.state, office.body || office.level].filter(Boolean).join(" · ")}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
