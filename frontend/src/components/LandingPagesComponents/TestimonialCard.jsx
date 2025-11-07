import React from "react";

export default function TestimonialCard({ name, lab, quote }) {
  return (
    <div className="p-6 bg-white dark:bg-gray-800 rounded-xl shadow-md hover:shadow-xl transition-all duration-300">
      <p className="text-gray-700 dark:text-gray-300 italic">"{quote}"</p>
      <h4 className="mt-4 font-bold text-gray-900 dark:text-white">{name}</h4>
      <p className="text-sm text-gray-500 dark:text-gray-400">{lab}</p>
    </div>
  );
}
