import * as React from "react"
import { cn } from "@/lib/utils"

export type ToastKind = "success" | "error" | "info"
type Toast = { id: number; message: string; kind: ToastKind }

const ToastContext = React.createContext<(message: string, kind?: ToastKind) => void>(() => {})

export function useToast() {
  return React.useContext(ToastContext)
}

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = React.useState<Toast[]>([])
  const idRef = React.useRef(0)

  const show = React.useCallback((message: string, kind: ToastKind = "info") => {
    const id = ++idRef.current
    setToasts(current => [...current, { id, message, kind }])
    setTimeout(() => setToasts(current => current.filter(t => t.id !== id)), 4500)
  }, [])

  return (
    <ToastContext.Provider value={show}>
      {children}
      <div className="fixed bottom-5 right-5 z-[100] flex flex-col gap-2">
        {toasts.map(toast => (
          <div
            key={toast.id}
            className={cn(
              "max-w-sm rounded-lg px-4 py-3 text-sm font-medium text-white shadow-lg",
              toast.kind === "success" && "bg-green-600",
              toast.kind === "error" && "bg-red-600",
              toast.kind === "info" && "bg-gray-800"
            )}
          >
            {toast.message}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  )
}
