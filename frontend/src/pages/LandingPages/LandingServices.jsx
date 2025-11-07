import LandingNavbar from "./../components/LandingPagesComponents/LandingNavbar";
import Footer from "./../components/LandingPagesComponents/Footer";
import FeatureCard from "../../components/LandingPagesComponents/FeatureCard";
import { FaUsers, FaFlask, FaFileInvoice, FaBell } from "react-icons/fa";
import { motion } from "framer-motion";

export default function LandingServices() {
 return (
    <div className="bg-gray-50 dark:bg-gray-900 min-h-screen">
      <LandingNavbar />

      <section className="py-20 px-6">
        <motion.h1
          initial={{ opacity: 0, y: -20 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          className="text-4xl md:text-5xl font-bold text-center text-gray-900 dark:text-white mb-12"
        >
          Services
        </motion.h1>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 max-w-6xl mx-auto">
          <motion.div whileHover={{ scale: 1.05 }}>
            <FeatureCard
              icon={<FaFlask />}
              title="Test Management"
              description="Automate test workflows, sample tracking, and results reporting."
            />
          </motion.div>

          <motion.div whileHover={{ scale: 1.05 }}>
            <FeatureCard
              icon={<FaFileInvoice />}
              title="Billing & Invoicing"
              description="Generate invoices automatically for patients and lab owners."
            />
          </motion.div>

          <motion.div whileHover={{ scale: 1.05 }}>
            <FeatureCard
              icon={<FaChartLine />}
              title="Analytics & Reports"
              description="Get advanced insights into lab performance and financial KPIs."
            />
          </motion.div>
        </div>
      </section>
    </div>
  );
}