import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { FaMoon, FaSun } from "react-icons/fa";

export default function LandingNavbar() {
  const [darkMode, setDarkMode] = useState(false);

  useEffect(() => {
    if (darkMode) document.documentElement.classList.add("dark");
    else document.documentElement.classList.remove("dark");
  }, [darkMode]);

  return (
    <nav className="flex justify-between items-center p-6 bg-white dark:bg-gray-900 shadow-md">
      <Link to="/" className="text-2xl font-bold text-blue-600 dark:text-blue-400">LabSys</Link>
      <div className="flex items-center space-x-4">
        <Link to="/about" className="hover:text-blue-500 dark:hover:text-blue-300">About</Link>
        <Link to="/services" className="hover:text-blue-500 dark:hover:text-blue-300">Services</Link>
        <Link to="/case-studies" className="hover:text-blue-500 dark:hover:text-blue-300">Case Studies</Link>
        <Link to="/contact" className="hover:text-blue-500 dark:hover:text-blue-300">Contact</Link>
        <Link to="/apply" className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition">Apply Demo</Link>
        <button
          onClick={() => setDarkMode(!darkMode)}
          className="p-2 rounded-full hover:bg-gray-200 dark:hover:bg-gray-700 transition"
        >
          {darkMode ? <FaSun /> : <FaMoon />}
        </button>
      </div>
    </nav>
  );
}
