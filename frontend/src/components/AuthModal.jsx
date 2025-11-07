import { X } from "lucide-react";

export default function AuthModal({ type, isOpen, onClose }) {
  if (!isOpen) return null;

  const isSignIn = type === "signin";

  return (
    <div
      className="fixed inset-0 flex items-center justify-center bg-black/40 backdrop-blur-sm z-[2000]"
      onClick={() => onClose()}
    >
      <div
        className="bg-white rounded-2xl shadow-lg w-full max-w-md p-6 relative animate-fadeIn"
        onClick={(e) => e.stopPropagation()} // Prevent closing modal when clicking inside
      >
        {/* Close Button */}
        <button
          onClick={() => onClose()}
          className="absolute top-3 right-3 text-gray-500 hover:text-red-500"
        >
          <X size={22} />
        </button>

        {/* Title */}
        <h2 className="text-3xl font-bold text-center text-blue-700 mb-6">
          {isSignIn ? "Sign In" : "Create Patient Account"}
        </h2>

        <form className="space-y-5">
          {!isSignIn && (
            <>
              <div>
                <label className="text-gray-700 font-medium">Full Name</label>
                <input
                  type="text"
                  placeholder="Enter your full name"
                  className="w-full border border-gray-300 rounded-lg px-4 py-2 mt-2 focus:ring-2 focus:ring-blue-600 outline-none"
                />
              </div>

              <div>
                <label className="text-gray-700 font-medium">Phone Number</label>
                <input
                  type="tel"
                  placeholder="Enter your phone number"
                  className="w-full border border-gray-300 rounded-lg px-4 py-2 mt-2 focus:ring-2 focus:ring-blue-600 outline-none"
                />
              </div>
            </>
          )}

          <div>
            <label className="text-gray-700 font-medium">Email</label>
            <input
              type="email"
              placeholder="Enter your email"
              className="w-full border border-gray-300 rounded-lg px-4 py-2 mt-2 focus:ring-2 focus:ring-blue-600 outline-none"
            />
          </div>

          <div>
            <label className="text-gray-700 font-medium">Password</label>
            <input
              type="password"
              placeholder="Enter your password"
              className="w-full border border-gray-300 rounded-lg px-4 py-2 mt-2 focus:ring-2 focus:ring-blue-600 outline-none"
            />
          </div>

          {!isSignIn && (
            <div>
              <label className="text-gray-700 font-medium">Confirm Password</label>
              <input
                type="password"
                placeholder="Re-enter your password"
                className="w-full border border-gray-300 rounded-lg px-4 py-2 mt-2 focus:ring-2 focus:ring-blue-600 outline-none"
              />
            </div>
          )}

          <button
            type="submit"
            className="w-full bg-blue-700 text-white font-semibold py-2 rounded-lg hover:bg-blue-800 transition"
          >
            {isSignIn ? "Sign In" : "Sign Up"}
          </button>

          <p className="text-center text-gray-600 mt-4">
            {isSignIn ? (
              <>
                Don’t have an account?{" "}
                <span
                  onClick={() => onClose("signup")}
                  className="text-blue-700 hover:underline cursor-pointer"
                >
                  Sign Up
                </span>
              </>
            ) : (
              <>
                Already have an account?{" "}
                <span
                  onClick={() => onClose("signin")}
                  className="text-blue-700 hover:underline cursor-pointer"
                >
                  Sign In
                </span>
              </>
            )}
          </p>
        </form>
      </div>
    </div>
  );
}