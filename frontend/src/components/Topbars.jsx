import React from "react";
import { BellIcon } from "@heroicons/react/24/outline";

export default function Topbar({ adminName, notificationsCount = 0 }) {
  return (
    <div className="w-full flex justify-between items-center bg-white p-4 shadow-md rounded-xl mb-6">
      {/* Greeting */}
      <h2 className="text-xl font-bold text-gray-700">Welcome, {adminName}</h2>

      {/* Notifications */}
      <div className="relative">
        <button className="relative">
          <BellIcon className="w-6 h-6 text-gray-700 hover:text-blue-700" />
          {notificationsCount > 0 && (
            <span className="absolute -top-1 -right-1 w-4 h-4 bg-red-500 text-white text-xs rounded-full flex items-center justify-center">
              {notificationsCount}
            </span>
          )}
        </button>
      </div>
    </div>
  );
}
