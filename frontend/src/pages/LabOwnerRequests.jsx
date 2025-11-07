import React, { useEffect, useState } from "react";
import Topbar from "../components/Topbars";

// Mock data
const mockRequests = [
  { _id: "1", name: { first: "Alice", last: "Smith" }, email: "alice@example.com", subscription_end: new Date(), status: "pending" },
  { _id: "2", name: { first: "Bob", last: "Johnson" }, email: "bob@example.com", subscription_end: new Date(), status: "pending" },
];

export default function LabOwnerRequests() {
  const [requests, setRequests] = useState([]);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    setRequests(mockRequests);
    const timer = setTimeout(() => setIsLoaded(true), 100);
    return () => clearTimeout(timer);
  }, []);

  const handleApprove = (id) => alert(`Approved request ID: ${id}`);
  const handleReject = (id) => alert(`Rejected request ID: ${id}`);

  return (
    <div className="p-6 w-full bg-gray-50 min-h-screen">
      <Topbar adminName="Admin" />

      <h2 className="text-3xl font-bold text-blue-700 mb-6">Lab Owner Requests</h2>
      <div className="space-y-4">
        {requests.map((r, idx) => (
          <div
            key={r._id}
            className={`p-6 bg-white rounded-2xl shadow-md hover:shadow-xl transform transition-all duration-300 flex justify-between items-center ${
              isLoaded ? "opacity-100 translate-y-0" : "opacity-0 translate-y-10"
            }`}
            style={{ transitionDelay: `${idx * 0.1}s` }}
          >
            <div>
              <p className="font-semibold text-gray-800">{r.name.first} {r.name.last}</p>
              <p className="text-gray-500">{r.email}</p>
            </div>
            <div className="space-x-2">
              <button
                onClick={() => handleApprove(r._id)}
                className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors duration-300"
              >
                Approve
              </button>
              <button
                onClick={() => handleReject(r._id)}
                className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors duration-300"
              >
                Reject
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}




// import React, { useEffect, useState } from "react";
// import API from "../api";
// import Topbar from "../components/Topbars";

// export default function LabOwnerRequests() {
//   const [requests, setRequests] = useState([]);

//   const fetchRequests = async () => {
//     const res = await API.get("/admin/labowners/pending");
//     setRequests(res.data);
//   };

//   const handleApprove = async (id) => {
//     const endDate = new Date();
//     endDate.setFullYear(endDate.getFullYear() + 1);
//     await API.put(`/admin/labowner/${id}/approve`, { subscription_end: endDate });
//     fetchRequests();
//   };

//   const handleReject = async (id) => {
//     await API.put(`/admin/labowner/${id}/reject`);
//     fetchRequests();
//   };

//   useEffect(() => {
//     fetchRequests();
//   }, []);

//   return (
//     <div className="p-6 w-full">
//       <Topbar adminName="Admin" />
//       <h2 className="text-2xl font-bold text-blue-700 mb-6">Lab Owner Requests</h2>

//       <div className="space-y-4">
//         {requests.map((r) => (
//           <div key={r._id} className="p-6 bg-white rounded-2xl shadow-lg flex justify-between items-center">
//             <div>
//               <p className="font-medium">{r.name.first} {r.name.last}</p>
//               <p className="text-gray-500">{r.email}</p>
//             </div>
//             <div className="space-x-2">
//               <button
//                 onClick={() => handleApprove(r._id)}
//                 className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
//               >
//                 Approve
//               </button>
//               <button
//                 onClick={() => handleReject(r._id)}
//                 className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
//               >
//                 Reject
//               </button>
//             </div>
//           </div>
//         ))}
//       </div>
//     </div>
//   );
// }
