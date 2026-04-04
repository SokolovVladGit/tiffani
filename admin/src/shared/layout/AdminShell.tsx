import { Outlet } from "react-router-dom";
import { Sidebar } from "./Sidebar";

export function AdminShell() {
  return (
    <div className="flex h-screen">
      <Sidebar />
      <main className="flex-1 overflow-y-auto p-6 lg:p-8">
        <Outlet />
      </main>
    </div>
  );
}
