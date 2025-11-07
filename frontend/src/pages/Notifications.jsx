import React, { useEffect, useState } from "react";
import Topbar from "../components/Topbars";

// Mock data
const mockNotifications = [
  { _id: "1", title: "System Maintenance", message: "Scheduled maintenance tomorrow at 08:00." },
  { _id: "2", title: "Subscription Expiry", message: "Alice's subscription will expire soon." },
];

export default function Notifications() {
  const [notifications, setNotifications] = useState([]);
  const [form, setForm] = useState({ title: "", message: "", receiver_model: "LabOwner", type: "info" });

  useEffect(() => setNotifications(mockNotifications), []);

  const handleSend = (e) => {
    e.preventDefault();
    alert(`Sent notification: ${form.title}`);
    setForm({ ...form, title: "", message: "" });
  };

  return (
    <div className="p-6 w-full">
      <Topbar adminName="Admin" />
      <h2 className="text-2xl font-bold text-blue-700 mb-6">Notifications</h2>

      <form onSubmit={handleSend} className="mb-6 space-y-4">
        <input type="text" placeholder="Title" className="w-full p-3 border rounded-lg" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
        <textarea placeholder="Message" className="w-full p-3 border rounded-lg" value={form.message} onChange={(e) => setForm({ ...form, message: e.target.value })} />
        <button type="submit" className="px-6 py-3 bg-blue-700 text-white rounded-lg hover:bg-blue-800">Send Notification</button>
      </form>

      <div className="space-y-4">
        {notifications.map((n) => (
          <div key={n._id} className="p-4 bg-white rounded-2xl shadow-md">
            <p className="font-medium">{n.title}</p>
            <p className="text-gray-500">{n.message}</p>
          </div>
        ))}
      </div>
    </div>
  );
}




// import React, { useEffect, useState } from "react";
// import API from "../api";
// import Topbar from "../components/Topbars";

// export default function Notifications() {
//   const [notifications, setNotifications] = useState([]);
//   const [form, setForm] = useState({ title: "", message: "", receiver_model: "LabOwner", type: "info" });

//   const fetchNotifications = async () => {
//     const res = await API.get("/admin/notifications");
//     setNotifications(res.data);
//   };

//   const handleSend = async (e) => {
//     e.preventDefault();
//     await API.post("/admin/notifications/send", form);
//     setForm({ ...form, title: "", message: "" });
//     fetchNotifications();
//   };

//   useEffect(() => {
//     fetchNotifications();
//   }, []);

//   return (
//     <div className="p-6 w-full">
//       <Topbar adminName="Admin" />
//       <h2 className="text-2xl font-bold text-blue-700 mb-6">Notifications</h2>

//       {/* Form */}
//       <form onSubmit={handleSend} className="mb-6 space-y-4">
//         <input
//           type="text"
//           placeholder="Title"
//           className="w-full p-3 border rounded-lg"
//           value={form.title}
//           onChange={(e) => setForm({ ...form, title: e.target.value })}
//         />
//         <textarea
//           placeholder="Message"
//           className="w-full p-3 border rounded-lg"
//           value={form.message}
//           onChange={(e) => setForm({ ...form, message: e.target.value })}
//         />
//         <button type="submit" className="px-6 py-3 bg-blue-700 text-white rounded-lg hover:bg-blue-800">
//           Send Notification
//         </button>
//       </form>

//       {/* History */}
//       <div className="space-y-4">
//         {notifications.map((n) => (
//           <div key={n._id} className="p-4 bg-white rounded-2xl shadow-md">
//             <p className="font-medium">{n.title}</p>
//             <p className="text-gray-500">{n.message}</p>
//           </div>
//         ))}
//       </div>
//     </div>
//   );
// }
