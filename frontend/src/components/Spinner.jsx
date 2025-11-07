import React, { useState, useEffect } from "react";

const Spinner = () => {
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => setIsLoading(false), 2000); // Hide after 2 seconds
    return () => clearTimeout(timer);
  }, []);

  return (
    <div
      className={`fixed top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-full h-screen bg-white flex items-center justify-center z-50 ${
        isLoading ? "opacity-100 visible" : "opacity-0 invisible transition-opacity duration-500 delay-500"
      }`}
    >
      <div
        className="w-12 h-12 border-4 border-t-[var(--bs-primary)] border-solid border-gray-200 rounded-full animate-spin"
        role="status"
      />
    </div>
  );
};

export default Spinner;