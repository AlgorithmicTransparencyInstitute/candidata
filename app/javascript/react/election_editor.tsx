import { createRoot } from "react-dom/client"
import { EditorApp } from "@/editor/EditorApp"
import { ToastProvider } from "@/components/ui/toast"
import type { Payload } from "@/editor/types"

function mount() {
  const dataEl = document.getElementById("editor-data")
  const rootEl = document.getElementById("election-editor-root")
  if (!dataEl || !rootEl) return

  const payload = JSON.parse(dataEl.textContent || "{}") as Payload
  createRoot(rootEl).render(
    <ToastProvider>
      <EditorApp payload={payload} />
    </ToastProvider>
  )
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", mount)
} else {
  mount()
}
