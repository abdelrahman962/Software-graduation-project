import React from "react";
import { BrowserRouter as Router, Routes, Route, Navigate } from "react-router-dom";
import Sidebar from "./components/Sidebar";
import Dashboard from "./pages/Dashboard";
import LabOwnerRequests from "./pages/LabOwnerRequests";
import Notifications from "./pages/Notifications";
import Home from "./pages/Home";
import About from "./pages/About";

// Optional: a simple Admin layout
function AdminLayout({ children }) {
  return (
    <div className="flex">
      <Sidebar />
      <div className="flex-1 bg-gray-100 min-h-screen p-6">{children}</div>
    </div>
  );
}

export default function AppRoutes() {
  const isAdminLoggedIn = true; // replace with your auth check

  return (
    <Router>
      <Routes>
        {/* Public pages */}
        <Route path="/" element={<Home />} />
        <Route path="/about" element={<About />} />

        {/* Admin pages */}
        <Route
          path="/admin/*"
          element={
            isAdminLoggedIn ? (
              <AdminLayout>
                <Routes>
                  <Route path="dashboard" element={<Dashboard />} />
                  <Route path="requests" element={<LabOwnerRequests />} />
                  <Route path="notifications" element={<Notifications />} />
                  <Route path="*" element={<Navigate to="dashboard" />} />
                </Routes>
              </AdminLayout>
            ) : (
              <Navigate to="/" />
            )
          }
        />
      </Routes>
    </Router>
  );
}
