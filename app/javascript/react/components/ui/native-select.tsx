import * as React from "react"
import { cn } from "@/lib/utils"

// Native <select> with shadcn styling. Used instead of the Radix Select in the
// grid because hundreds of portal-based selects would be slow; native selects
// keep the spreadsheet snappy and keyboard-friendly.
const NativeSelect = React.forwardRef<HTMLSelectElement, React.SelectHTMLAttributes<HTMLSelectElement>>(
  ({ className, children, ...props }, ref) => (
    <select
      className={cn(
        "flex h-9 w-full cursor-pointer rounded-md border border-gray-300 bg-white px-3 py-1 text-sm shadow-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 disabled:cursor-not-allowed disabled:opacity-50",
        className
      )}
      ref={ref}
      {...props}
    >
      {children}
    </select>
  )
)
NativeSelect.displayName = "NativeSelect"

export { NativeSelect }
