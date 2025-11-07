import React, { useEffect, useState } from "react";

export default function ExpiringSubscriptions({ mockOwners }) {
  const [owners, setOwners] = useState([]);

  useEffect(() => {
    const today = new Date();
    const expiring = mockOwners.filter((o) => {
      if (!o.subscription_end) return false;
      const endDate = new Date(o.subscription_end);
      const diffDays = (endDate - today) / (1000 * 60 * 60 * 24);
      return diffDays <= 30 && diffDays >= 0;
    });
    setOwners(expiring);
  }, [mockOwners]);

  if (owners.length === 0) {
    return <p className="text-gray-500">No subscriptions are expiring soon.</p>;
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
      {owners.map((o, idx) => {
        const endDate = new Date(o.subscription_end);
        const today = new Date();
        const totalDays = (endDate - today) / (1000 * 60 * 60 * 24);
        const progress = 100 - Math.min(Math.max((totalDays / 30) * 100, 0), 100);

        return (
          <div
            key={o._id}
            className={`p-4 bg-white rounded-2xl shadow-md transform transition-all duration-300 hover:scale-105 hover:shadow-lg hover:-rotate-1 cursor-pointer`}
            style={{ transitionDelay: `${idx * 0.05}s` }}
          >
            <div className="flex justify-between items-center mb-2">
              <p className="font-semibold text-gray-800 truncate">{o.name.first} {o.name.last}</p>
              <p className="text-sm text-gray-500">{endDate.toDateString()}</p>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-3">
              <div
                className="bg-blue-600 h-3 rounded-full transition-all duration-500"
                style={{ width: `${progress}%` }}
              ></div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
