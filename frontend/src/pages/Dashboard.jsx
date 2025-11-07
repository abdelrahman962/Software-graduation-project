import React, { useEffect, useState } from "react";
import ExpiringSubscriptions from "../components/ExpiringSubscriptions";
import Topbar from "../components/Topbars";
import { FaUsers, FaClock, FaCheckCircle } from "react-icons/fa";

// Mock data
const mockOwners = [
  { _id: "1", name: { first: "Alice", last: "Smith" }, status: "pending", is_active: true, subscription_end: new Date() },
  { _id: "2", name: { first: "Bob", last: "Johnson" }, status: "approved", is_active: true, subscription_end: new Date() },
  { _id: "3", name: { first: "Charlie", last: "Brown" }, status: "pending", is_active: false, subscription_end: new Date() },
];

export default function Dashboard() {
  const [stats, setStats] = useState({ totalLabOwners: 0, pendingRequests: 0, activeSubscriptions: 0 });
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    const total = mockOwners.length;
    const pending = mockOwners.filter((o) => o.status === "pending").length;
    const active = mockOwners.filter((o) => o.is_active).length;
    setStats({ totalLabOwners: total, pendingRequests: pending, activeSubscriptions: active });

    const timer = setTimeout(() => setIsLoaded(true), 100);
    return () => clearTimeout(timer);
  }, []);

  const statItems = [
    { title: "Total Lab Owners", value: stats.totalLabOwners, icon: <FaUsers className="text-2xl text-white" /> },
    { title: "Pending Requests", value: stats.pendingRequests, icon: <FaClock className="text-2xl text-white" /> },
    { title: "Active Subscriptions", value: stats.activeSubscriptions, icon: <FaCheckCircle className="text-2xl text-white" /> },
  ];

  return (
    <div className="p-6 w-full bg-gray-50 min-h-screen">
      <Topbar adminName="Admin" />

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 mb-6">
        {statItems.map((stat, idx) => (
          <div
            key={idx}
            className={`relative p-6 rounded-2xl shadow-md transform transition-all duration-300 cursor-pointer overflow-hidden group min-w-0 bg-white hover:shadow-xl hover:scale-105`}
            style={{ transitionDelay: `${idx * 0.1}s`, opacity: isLoaded ? 1 : 0, transform: isLoaded ? "translateY(0)" : "translateY(20px)" }}
          >
            <div className="flex items-center mb-4">
              <div className="w-12 h-12 flex items-center justify-center rounded-full bg-blue-700 group-hover:bg-gradient-to-br from-blue-600 to-blue-800 transition-all duration-300 flex-shrink-0">
                {stat.icon}
              </div>
              <h3 className="ml-4 text-gray-700 font-semibold text-base sm:text-lg md:text-lg lg:text-lg group-hover:text-white transition-colors duration-300 truncate">
                {stat.title}
              </h3>
            </div>
            <p className="text-2xl sm:text-3xl md:text-4xl font-bold text-gray-800 group-hover:text-white transition-colors duration-300 truncate">
              {stat.value}
            </p>

            {/* Hover gradient overlay */}
            <div className="absolute inset-0 bg-gradient-to-br from-blue-600 to-blue-800 opacity-0 group-hover:opacity-20 transition-opacity duration-300 rounded-2xl pointer-events-none"></div>
          </div>
        ))}
      </div>

      {/* Expiring Subscriptions */}
      <div
        className={`p-6 rounded-2xl shadow-md transform transition-all duration-300 bg-white hover:shadow-xl hover:scale-105 ${
          isLoaded ? "opacity-100 translate-y-0" : "opacity-0 translate-y-10"
        }`}
      >
        <h3 className="text-xl font-bold text-blue-700 mb-4">Expiring Subscriptions (Next 30 Days)</h3>
        <ExpiringSubscriptions mockOwners={mockOwners} />
      </div>
    </div>
  );
}




// import React, { useEffect, useState } from "react";
// import API from "../api";
// import StatsCard from "../components/StatsCard";
// import ExpiringSubscriptions from "../components/ExpiringSubscriptions";
// import MonthlySubscriptionChart from "../components/MonthlySubscriptionChart";
// import Topbar from "../components/Topbars";

// export default function Dashboard() {
//   const [stats, setStats] = useState({
//     totalLabOwners: 0,
//     pendingRequests: 0,
//     activeSubscriptions: 0,
//   });

//   useEffect(() => {
//     const fetchStats = async () => {
//       const res = await API.get("/admin/labowners");
//       const owners = res.data;
//       const pending = owners.filter((o) => o.status === "pending").length;
//       const active = owners.filter((o) => o.is_active).length;
//       setStats({
//         totalLabOwners: owners.length,
//         pendingRequests: pending,
//         activeSubscriptions: active,
//       });
//     };
//     fetchStats();
//   }, []);

//   return (
//     <div className="p-6 w-full">
//       <Topbar adminName="Admin" />

//       <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
//         <StatsCard title="Total Lab Owners" value={stats.totalLabOwners} />
//         <StatsCard title="Pending Requests" value={stats.pendingRequests} />
//         <StatsCard title="Active Subscriptions" value={stats.activeSubscriptions} />
//       </div>

//       <ExpiringSubscriptions />
//       <MonthlySubscriptionChart />
//     </div>
//   );
// }
