import { useState } from "react";
import { Menu, ChevronDown } from "lucide-react";
import { Link } from "react-router-dom";
import AuthModal from "../components/AuthModal"; // adjust path if needed

export default function Navbar() {
  const [isOpen, setIsOpen] = useState(false);
  const [isPagesOpen, setIsPagesOpen] = useState(false);
  const [authType, setAuthType] = useState(null); // "signin" or "signup"

  return (
    <>
      <div className="sticky top-0 z-[1020] bg-white shadow transition-all duration-500">
        <div className="container mx-auto px-4">
          {/* Navbar Wrapper */}
          <nav className="flex items-center justify-between py-4 lg:py-3">
            {/* Logo */}
            <Link to="/" className="text-2xl font-bold text-[#3368C6] lg:hidden">
              Lab<span className="text-[#031B4E]">sky</span>
            </Link>

            {/* Hamburger Menu (Mobile Only) */}
            <button
              className="lg:hidden text-gray-700"
              onClick={() => setIsOpen(!isOpen)}
            >
              <Menu size={24} />
            </button>

            {/* Desktop Menu */}
            <div className="hidden lg:flex items-center justify-between w-full">
              {/* Left Navigation Links */}
              <div className="flex space-x-6 text-gray-700">
                <Link to="/" className="hover:text-[#3368C6]">Home</Link>
                <Link to="/about" className="hover:text-[#3368C6]">About</Link>
                <Link to="/service" className="hover:text-[#3368C6]">Services</Link>

                {/* Pages Dropdown */}
                <div className="relative group">
                  <button className="flex items-center hover:text-[#3368C6]">
                    Pages
                    <ChevronDown size={16} className="ml-1" />
                  </button>
                  <div className="absolute hidden group-hover:block bg-white shadow-lg mt-2 rounded">
                    <Link to="/feature" className="block px-4 py-2 hover:bg-gray-100">Features</Link>
                    <Link to="/team" className="block px-4 py-2 hover:bg-gray-100">Our Team</Link>
                    <Link to="/testimonial" className="block px-4 py-2 hover:bg-gray-100">Testimonial</Link>
                    <Link to="/appointment" className="block px-4 py-2 hover:bg-gray-100">Appointment</Link>
                    <Link to="/404" className="block px-4 py-2 hover:bg-gray-100">404 Page</Link>
                  </div>
                </div>

                <Link to="/contact" className="hover:text-[#3368C6]">Contact</Link>
              </div>

              {/* Right Navigation — Sign In/Sign Up buttons */}
              <div className="flex items-center space-x-4">
                <button
                  onClick={() => setAuthType("signin")}
                  className="px-4 py-2 border border-blue-700 text-blue-700 rounded-lg hover:bg-blue-700 hover:text-white transition"
                >
                  Sign In
                </button>
                <button
                  onClick={() => setAuthType("signup")}
                  className="bg-blue-700 text-white px-4 py-2 rounded-lg hover:bg-blue-800 transition"
                >
                  Sign Up
                </button>
              </div>
            </div>
          </nav>

          {/* Mobile Dropdown Menu */}
          {isOpen && (
            <div className="lg:hidden bg-white shadow-md rounded-md mt-2 p-4 animate-fadeIn text-center">
              <div className="flex flex-col space-y-3 text-gray-700 font-medium">
                <Link to="/" className="hover:text-[#3368C6]">Home</Link>
                <Link to="/about" className="hover:text-[#3368C6]">About</Link>
                <Link to="/service" className="hover:text-[#3368C6]">Services</Link>

                {/* Pages Dropdown */}
                <button
                  onClick={() => setIsPagesOpen(!isPagesOpen)}
                  className="flex justify-center items-center hover:text-[#3368C6]"
                >
                  Pages
                  <ChevronDown
                    size={16}
                    className={`ml-1 transition-transform ${isPagesOpen ? "rotate-180" : "rotate-0"}`}
                  />
                </button>

                {isPagesOpen && (
                  <div className="flex flex-col space-y-2 mt-2 text-gray-600">
                    <Link to="/feature" className="hover:text-[#3368C6]">Features</Link>
                    <Link to="/team" className="hover:text-[#3368C6]">Our Team</Link>
                    <Link to="/testimonial" className="hover:text-[#3368C6]">Testimonial</Link>
                    <Link to="/appointment" className="hover:text-[#3368C6]">Appointment</Link>
                    <Link to="/404" className="hover:text-[#3368C6]">404 Page</Link>
                  </div>
                )}

                <Link to="/contact" className="hover:text-[#3368C6]">Contact</Link>

                {/* Mobile Sign In / Sign Up */}
                <button
                  onClick={() => setAuthType("signin")}
                  className="px-4 py-2 border border-blue-700 text-blue-700 rounded-lg hover:bg-blue-700 hover:text-white transition"
                >
                  Sign In
                </button>
                <button
                  onClick={() => setAuthType("signup")}
                  className="bg-blue-700 text-white px-4 py-2 rounded-lg hover:bg-blue-800 transition"
                >
                  Sign Up
                </button>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Auth Modal */}
      <AuthModal
  type={authType}
  isOpen={!!authType}
  onClose={(nextType) => {
    if (nextType === "signin" || nextType === "signup") {
      setAuthType(nextType); // switch modal type
    } else {
      setAuthType(null); // close modal
    }
  }}
/>

    </>
  );
}
