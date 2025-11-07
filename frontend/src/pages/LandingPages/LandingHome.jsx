import React from "react";
import LandingNavbar from "./../components/LandingPagesComponents/LandingNavbar";
import FeatureCard from "./..components/LandingPagesComponents/FeatureCard";
import { FaUsers, FaFlask, FaFileInvoice, FaBell } from "react-icons/fa";
import { motion } from "framer-motion";

export default function LandingHome() {
 
  return (
    <div className="bg-gray-50 dark:bg-gray-900 min-h-screen">
      <LandingNavbar />

      {/* Hero Section */}
      <section className="flex flex-col items-center text-center py-20 px-6">
        <motion.h1
          initial={{ opacity: 0, y: -40 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          className="text-4xl md:text-6xl font-bold text-gray-900 dark:text-white mb-6"
        >
          Manage Your Lab Smarter with <span className="text-blue-600">LabSys</span>
        </motion.h1>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.3, duration: 0.8 }}
          className="text-lg text-gray-700 dark:text-gray-300 max-w-2xl mb-8"
        >
          Automate reports, manage patients, staff, and billing — all in one
          powerful cloud platform built for medical labs and diagnostic centers.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5 }}
        >
          <Link
            to="/apply"
            className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-semibold transition-all"
          >
            Request a Free Demo
          </Link>
        </motion.div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-20 px-6 bg-white dark:bg-gray-800">
        <motion.h2
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          className="text-3xl md:text-4xl font-bold text-center text-gray-900 dark:text-white mb-12"
        >
          Why Choose LabSys?
        </motion.h2>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-6xl mx-auto">
          <motion.div whileHover={{ scale: 1.05 }}>
            <FeatureCard
              icon={<FaFlask />}
              title="Automated Test Management"
              description="Easily manage and track all tests with device integration and smart scheduling."
            />
          </motion.div>

          <motion.div whileHover={{ scale: 1.05 }}>
            <FeatureCard
              icon={<FaFileInvoice />}
              title="Billing & Invoicing"
              description="Generate invoices automatically for patients and insurance providers."
            />
          </motion.div>

          <motion.div whileHover={{ scale: 1.05 }}>
            <FeatureCard
              icon={<FaChartLine />}
              title="Advanced Analytics"
              description="Monitor financials, performance, and lab KPIs with real-time dashboards."
            />
          </motion.div>
        </div>
      </section>

      {/* Screenshots Section */}
      <section className="py-20 px-6 bg-gray-100 dark:bg-gray-900">
        <motion.h2
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          transition={{ duration: 0.8 }}
          className="text-3xl md:text-4xl font-bold text-center text-gray-900 dark:text-white mb-12"
        >
          See It in Action
        </motion.h2>

        <motion.div
          className="flex justify-center space-x-6 overflow-x-auto"
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          transition={{ duration: 0.8 }}
        >
          {[1, 2, 3].map((i) => (
            <img
              key={i}
              src={`/assets/screenshots/dashboard${i}.png`}
              alt={`Dashboard ${i}`}
              className="w-96 rounded-xl shadow-lg"
            />
          ))}
        </motion.div>
      </section>
    </div>
  );
}
