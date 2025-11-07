import React from "react";
import { ArrowUpIcon, ArrowDownIcon } from "@heroicons/react/24/solid";
import { Sparklines, SparklinesLine } from "react-sparklines";

export default function StatsCard({
  title,
  value,
  trend = null,
  icon = null,
  color = "blue",
  sparklineData = [],
}) {
  const borderColor = `border-t-4 border-${color}-500`;

  return (
    <div className={`p-6 bg-white rounded-2xl shadow-lg hover:shadow-xl transition-shadow duration-300 ${borderColor}`}>
      {/* Header */}
      <div className="flex justify-between items-center mb-4">
        <h3 className="text-gray-600 font-medium">{title}</h3>
        {icon && <div className="text-gray-400">{icon}</div>}
      </div>

      {/* Main Value */}
      <p className="text-2xl font-bold text-gray-800">{value}</p>

      {/* Trend & Sparkline */}
      <div className="flex items-center justify-between mt-2">
        {trend && (
          <div className={`flex items-center text-sm font-medium ${trend.up ? "text-green-600" : "text-red-600"}`}>
            {trend.up ? <ArrowUpIcon className="w-4 h-4 mr-1" /> : <ArrowDownIcon className="w-4 h-4 mr-1" />}
            {trend.percentage}%
          </div>
        )}
        {sparklineData.length > 0 && (
          <div className="w-24 h-8">
            <Sparklines data={sparklineData}>
              <SparklinesLine color={trend?.up ? "#16a34a" : "#dc2626"} style={{ strokeWidth: 2, fill: "transparent" }} />
            </Sparklines>
          </div>
        )}
      </div>
    </div>
  );
}
