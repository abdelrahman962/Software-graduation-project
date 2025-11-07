import useScrollHide from "../hooks/useScrollHide";
import { MapPin, Clock } from "lucide-react";

export default function TopBar() {
  const hidden = useScrollHide(100);

  return (
    <div
      className={`fixed top-0 left-0 w-full bg-gray-100 border-b border-gray-300 py-2 z-[1000] shadow-sm transition-transform duration-500 ease-in-out hidden lg:flex ${
        hidden ? "-translate-y-full" : "translate-y-0"
      }`}
    >
      <div className="max-w-screen-xl mx-auto flex justify-between items-center text-sm text-gray-700 px-6 lg:px-10">
        <div className="flex space-x-6">
          <span className="inline-flex items-center gap-1">
            <MapPin size={14} />
            <span>123 Street, New York, USA</span>
          </span>
          <span className="inline-flex items-center gap-1">
            <Clock size={14} />
            <span>Mon - Sat 09:00 - 18:00</span>
          </span>
        </div>
        <nav className="flex space-x-4 text-gray-600 text-sm">
          <a href="#" className="hover:underline">Career</a>
          <a href="#" className="hover:underline">Support</a>
          <a href="#" className="hover:underline">Terms</a>
          <a href="#" className="hover:underline">FAQs</a>
        </nav>
      </div>
    </div>
  );
}
