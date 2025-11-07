import React from "react";

export default function FeatureCard({ icon, title, description }) {
  return (
    <div className="p-6 bg-white dark:bg-gray-800 rounded-xl shadow-md hover:shadow-xl transform transition-all duration-300 hover:scale-105">
      <div className="flex items-center mb-4">
        <div className="text-3xl text-blue-600 dark:text-blue-400 mr-4">{icon}</div>
        <h3 className="text-xl font-bold dark:text-white">{title}</h3>
      </div>
      <p className="text-gray-700 dark:text-gray-300">{description}</p>
    </div>
  );
}
