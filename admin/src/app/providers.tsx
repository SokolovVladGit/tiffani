import { type ReactNode } from "react";
import { BrowserRouter } from "react-router-dom";

interface ProvidersProps {
  children: ReactNode;
}

/**
 * Wraps the app with global providers.
 * Add auth context, toast context, etc. here as needed.
 */
export function Providers({ children }: ProvidersProps) {
  return <BrowserRouter>{children}</BrowserRouter>;
}
