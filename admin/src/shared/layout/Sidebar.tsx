import { NavLink } from "react-router-dom";
import { supabase } from "../../lib/supabase";

const NAV_ITEMS = [
  { label: "Обзор", to: "/dashboard" },
  { label: "Товары", to: "/products" },
] as const;

export function Sidebar() {
  async function handleSignOut() {
    await supabase.auth.signOut();
  }

  return (
    <aside className="flex w-56 flex-col border-r border-gray-200 bg-white">
      <div className="flex h-14 items-center px-4">
        <span className="text-sm font-semibold tracking-tight text-gray-900">
          TIFFANI
        </span>
      </div>

      <nav className="flex-1 space-y-0.5 px-2 py-2">
        {NAV_ITEMS.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) =>
              `block rounded-md px-3 py-2 text-sm transition-colors ${
                isActive
                  ? "bg-gray-100 font-medium text-gray-900"
                  : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
              }`
            }
          >
            {item.label}
          </NavLink>
        ))}
      </nav>

      <div className="border-t border-gray-200 p-2">
        <button
          onClick={handleSignOut}
          className="w-full rounded-md px-3 py-2 text-left text-sm text-gray-500 transition-colors hover:bg-gray-50 hover:text-gray-700"
        >
          Выйти
        </button>
      </div>
    </aside>
  );
}
