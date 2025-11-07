import LandingNavbar from "./../components/LandingPagesComponents/LandingNavbar";
import Footer from "./../components/LandingPagesComponents/Footer";
import { motion } from "framer-motion";

export default function LandingAbout() {
  return (
    <div className="bg-gray-50 dark:bg-gray-900 min-h-screen">
      <LandingNavbar />

      <section className="py-20 px-6 text-center">
        <motion.h1
          initial={{ opacity: 0, y: -30 }}
          whileInView={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8 }}
          className="text-4xl md:text-5xl font-bold text-gray-900 dark:text-white mb-6"
        >
          About LabSys
        </motion.h1>

        <motion.p
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          transition={{ delay: 0.3, duration: 0.8 }}
          className="text-lg text-gray-700 dark:text-gray-300 max-w-3xl mx-auto"
        >
          LabSys is a comprehensive medical lab management system designed for 
          diagnostic centers, hospitals, and labs. Automate patient records, test 
          workflows, billing, and reporting — all with secure cloud access.
        </motion.p>

        <motion.div
          className="mt-12 flex justify-center space-x-6 overflow-x-auto"
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          transition={{ delay: 0.5, duration: 0.8 }}
        >
          {[1, 2].map((i) => (
            <img
              key={i}
              src={`/assets/screenshots/about${i}.png`}
              alt={`About screenshot ${i}`}
              className="w-96 rounded-xl shadow-lg"
            />
          ))}
        </motion.div>
      </section>
    </div>
  );
}
