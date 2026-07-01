import { NavLink, useNavigate, useParams } from "react-router-dom";
import { LayoutDashboard, FolderOpen, Settings, LogOut, ChevronDown } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { useAuthStore } from "../stores/auth.store";
import { logout } from "../api/auth";
import { listOrgs } from "../api/orgs";
import clsx from "clsx";

export function Sidebar() {
  const { orgSlug } = useParams<{ orgSlug?: string }>();
  const navigate = useNavigate();
  const user = useAuthStore((s) => s.user);
  const signout = useAuthStore((s) => s.logout);
  const [orgOpen, setOrgOpen] = useState(false);

  const { data: orgs = [] } = useQuery({ queryKey: ["orgs"], queryFn: listOrgs });

  const currentOrg = orgs.find((o) => o.slug === orgSlug) ?? orgs[0];

  async function handleLogout() {
    try { await logout(); } catch {}
    signout();
    navigate("/login");
  }

  const navLink = (to: string, icon: React.ReactNode, label: string) => (
    <NavLink
      to={to}
      className={({ isActive }) =>
        clsx(
          "flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm font-medium transition-colors",
          isActive
            ? "bg-white/10 text-white"
            : "text-slate-400 hover:text-white hover:bg-white/5"
        )
      }
    >
      {icon}
      {label}
    </NavLink>
  );

  return (
    <nav className="w-56 bg-sidebar flex flex-col shrink-0 border-r border-white/5">
      {/* Logo */}
      <div className="flex items-center gap-2.5 px-4 py-4 border-b border-white/5">
        <div className="w-7 h-7 rounded bg-brand-500 flex items-center justify-center text-white font-bold text-sm">T</div>
        <span className="text-white font-semibold text-sm tracking-wide">Trace Cloud</span>
      </div>

      {/* Org switcher */}
      {orgs.length > 0 && (
        <div className="px-3 py-3 border-b border-white/5">
          <button
            onClick={() => setOrgOpen(!orgOpen)}
            className="w-full flex items-center justify-between px-2 py-1.5 rounded-md hover:bg-white/5 text-slate-300 text-sm"
          >
            <span className="truncate">{currentOrg?.name ?? "Select org"}</span>
            <ChevronDown size={14} className={clsx("shrink-0 transition-transform", orgOpen && "rotate-180")} />
          </button>
          {orgOpen && (
            <div className="mt-1 bg-slate-800 rounded-md py-1 shadow-lg">
              {orgs.map((o) => (
                <button
                  key={o.id}
                  onClick={() => { navigate(`/orgs/${o.slug}`); setOrgOpen(false); }}
                  className={clsx(
                    "w-full text-left px-3 py-1.5 text-sm hover:bg-white/10",
                    o.slug === orgSlug ? "text-white" : "text-slate-400"
                  )}
                >
                  {o.name}
                </button>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Navigation */}
      <div className="flex-1 px-3 py-3 space-y-1">
        {navLink("/dashboard", <LayoutDashboard size={16} />, "Dashboard")}
        {currentOrg && navLink(`/orgs/${currentOrg.slug}`, <FolderOpen size={16} />, "Projects")}
        {navLink("/settings", <Settings size={16} />, "Settings")}
      </div>

      {/* User */}
      <div className="px-3 py-3 border-t border-white/5">
        <div className="flex items-center gap-2 px-2 py-1.5">
          <div className="w-6 h-6 rounded-full bg-brand-500 flex items-center justify-center text-white text-xs font-bold shrink-0">
            {user?.name?.[0]?.toUpperCase() ?? "?"}
          </div>
          <div className="min-w-0 flex-1">
            <p className="text-slate-300 text-xs font-medium truncate">{user?.name}</p>
            <p className="text-slate-500 text-xs truncate">{user?.email}</p>
          </div>
          <button onClick={handleLogout} className="text-slate-500 hover:text-slate-300 p-1" title="Log out">
            <LogOut size={14} />
          </button>
        </div>
      </div>
    </nav>
  );
}
