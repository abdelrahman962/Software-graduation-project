import LabHeader from "../components/LabComponents/LabHeader";
import LabSidebar from "../components/LabComponents/LabSidebar";
import TestList from "../components/LabComponents/TestList";
import AppointmentList from "../components/LabComponents/AppointmentList";
import ResultList from "../components/LabComponents/ResultList";
import DashboardCard from "../components/LabComponents/DashboardCard";

export default function LabDashboard() {
  return (
    <div className="flex min-h-screen bg-gray-50">
      <LabSidebar />
      <div className="flex-1 flex flex-col">
        <LabHeader />

        <main className="p-6 space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <DashboardCard title="Tests Today" value="12" color="green" />
            <DashboardCard title="Appointments" value="5" color="blue" />
            <DashboardCard title="Pending Results" value="3" color="yellow" />
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <TestList />
            <AppointmentList />
            <ResultList />
          </div>
        </main>
      </div>
    </div>
  );
}
