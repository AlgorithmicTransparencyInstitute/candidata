import * as React from "react"
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { NativeSelect } from "@/components/ui/native-select"
import { getJSON, postJSON } from "./api"
import type { ContestOption, OfficeResult, Payload } from "./types"

export function NewContestDialog({ payload, open, onOpenChange, onCreated }: {
  payload: Payload
  open: boolean
  onOpenChange: (open: boolean) => void
  onCreated: (contest: ContestOption) => void
}) {
  const [query, setQuery] = React.useState("")
  const [results, setResults] = React.useState<OfficeResult[]>([])
  const [allStates, setAllStates] = React.useState(false)
  const [officeId, setOfficeId] = React.useState<number | null>(null)
  const [party, setParty] = React.useState(payload.contestParties[0] ?? "")
  const [error, setError] = React.useState("")
  const [busy, setBusy] = React.useState(false)
  const timer = React.useRef<ReturnType<typeof setTimeout>>()

  const isPrimary = payload.election.type === "primary"

  React.useEffect(() => {
    if (!open) {
      setQuery(""); setResults([]); setOfficeId(null); setError(""); setAllStates(false)
    }
  }, [open])

  const runSearch = async (value: string, all: boolean) => {
    try {
      const res = await getJSON<{ offices: OfficeResult[]; allStates?: boolean }>(
        `${payload.urls.offices}?q=${encodeURIComponent(value.trim())}${all ? "&all=1" : ""}`
      )
      setResults(res.offices)
      setAllStates(Boolean(res.allStates))
    } catch { /* search is best-effort */ }
  }

  const search = (value: string) => {
    setQuery(value)
    setOfficeId(null)
    clearTimeout(timer.current)
    if (value.trim().length < 2) { setResults([]); return }
    timer.current = setTimeout(() => runSearch(value, false), 250)
  }

  const create = async () => {
    if (!officeId) { setError("Pick an office from the search results"); return }
    setBusy(true)
    setError("")
    try {
      const { contest } = await postJSON<{ contest: ContestOption }>(payload.urls.contests, {
        office_id: officeId,
        party: isPrimary ? party : ""
      })
      onCreated(contest)
      onOpenChange(false)
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not create contest")
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>New contest</DialogTitle>
          <DialogDescription>
            Adds a race to {payload.election.label}{isPrimary ? " on the selected party's ballot" : ""}.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Office</label>
            <Input
              placeholder="Search offices… (e.g. Governor, U.S. House)"
              value={query}
              autoComplete="off"
              onChange={e => search(e.target.value)}
            />
            {results.length > 0 && !officeId && (
              <>
                {allStates && (
                  <p className="mt-1 text-xs text-amber-600">Showing offices from all states.</p>
                )}
                <div className="mt-1 max-h-48 divide-y divide-gray-100 overflow-auto rounded-md border border-gray-200">
                  {results.map(office => (
                    <button
                      key={office.id}
                      type="button"
                      className="block w-full px-3 py-2 text-left text-sm hover:bg-blue-50"
                      onClick={() => { setOfficeId(office.id); setQuery(office.searchLabel ?? office.label); setResults([]) }}
                    >
                      <span className="font-medium">{office.label}</span>
                      <span className="ml-1 text-xs text-gray-500">
                        {[office.state, office.body || office.level].filter(Boolean).join(" · ")}
                      </span>
                    </button>
                  ))}
                </div>
              </>
            )}
            {query.trim().length >= 2 && results.length === 0 && !officeId && (
              <p className="mt-1 text-xs text-gray-500">No matches yet in {payload.election.state} — keep typing.</p>
            )}
            {query.trim().length >= 2 && !officeId && !allStates && (
              <button
                type="button"
                className="mt-1 text-xs text-blue-600 hover:underline"
                onClick={() => runSearch(query, true)}
              >
                Search all states
              </button>
            )}
          </div>

          {isPrimary && (
            <div>
              <label className="mb-1 block text-sm font-medium text-gray-700">Party ballot</label>
              <NativeSelect value={party} onChange={e => setParty(e.target.value)}>
                {payload.contestParties.map(p => <option key={p} value={p}>{p}</option>)}
              </NativeSelect>
            </div>
          )}

          {error && <p className="text-sm text-red-600">{error}</p>}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancel</Button>
          <Button onClick={create} disabled={busy || !officeId}>
            {busy ? "Creating…" : "Create contest"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
