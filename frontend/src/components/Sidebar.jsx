import React, { useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { HomeIcon, UsersIcon, ChartBarIcon } from "@heroicons/react/24/outline";

export default function Sidebar() {
  const location = useLocation();
  const [openMenus, setOpenMenus] = useState({});
  const [isCollapsed, setIsCollapsed] = useState(false);

  const links = [
    { name: "Dashboard", path: "/admin/dashboard", icon: <HomeIcon className="w-6 h-6" /> },
    {
      name: "Lab Owner Management",
      icon: <UsersIcon className="w-6 h-6" />,
      subLinks: [
        { name: "Requests", path: "/admin/requests" },
        { name: "All Lab Owners", path: "/admin/labowners" },
      ],
    },
    {
      name: "Reports",
      icon: <ChartBarIcon className="w-6 h-6" />,
      subLinks: [
        { name: "Financial Report", path: "/admin/reports/financial" },
        { name: "Performance Report", path: "/admin/reports/performance" },
      ],
    },
  ];

  const toggleMenu = (name) => {
    setOpenMenus((prev) => ({ ...prev, [name]: !prev[name] }));
  };

  return (
    <div
      className={`bg-white shadow-lg h-screen flex flex-col transition-all duration-300 ${
        isCollapsed ? "w-20" : "w-64"
      }`}
    >
      {/* Logo / Toggle */}
      <div className="flex items-center justify-between p-4 border-b">
        {!isCollapsed && <h1 className="text-2xl font-bold text-blue-700">Admin Panel</h1>}
        <button
          onClick={() => setIsCollapsed(!isCollapsed)}
          className="text-gray-500 hover:text-blue-700 focus:outline-none"
        >
          {isCollapsed ? "☰" : "✖"}
        </button>
      </div>

      {/* Navigation Links */}
      <nav className="flex-1 flex flex-col p-2 space-y-1">
        {links.map((link) =>
          link.subLinks ? (
            <div key={link.name}>
              <button
                onClick={() => toggleMenu(link.name)}
                className={`flex items-center w-full p-2 rounded-lg hover:bg-blue-100 transition-colors ${
                  location.pathname.startsWith(link.subLinks[0].path) ? "bg-blue-100" : ""
                }`}
              >
                {link.icon && <span className="mr-2">{link.icon}</span>}
                {!isCollapsed && <span className="flex-1 text-gray-700">{link.name}</span>}
                {!isCollapsed && <span>{openMenus[link.name] ? "▲" : "▼"}</span>}
              </button>

              {/* Submenu */}
              {openMenus[link.name] && !isCollapsed && (
                <div className="ml-8 flex flex-col mt-1 space-y-1">
                  {link.subLinks.map((sub) => (
                    <Link
                      key={sub.name}
                      to={sub.path}
                      className={`p-2 rounded-lg text-gray-700 hover:bg-blue-100 transition-colors ${
                        location.pathname === sub.path ? "bg-blue-700 text-white" : ""
                      }`}
                    >
                      {sub.name}
                    </Link>
                  ))}
                </div>
              )}
            </div>
          ) : (
            <Link
              key={link.name}
              to={link.path}
              className={`flex items-center p-2 rounded-lg hover:bg-blue-100 transition-colors ${
                location.pathname === link.path ? "bg-blue-700 text-white" : "text-gray-700"
              }`}
            >
              {link.icon && <span className="mr-2">{link.icon}</span>}
              {!isCollapsed && <span>{link.name}</span>}
            </Link>
          )
        )}
      </nav>
    </div>
  );
}
