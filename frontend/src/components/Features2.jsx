import React from "react";
import featureImage from "../assets/feature.jpg";

const Features2 = () => {
  return (
    <section
      className="relative bg-cover bg-center py-20 md:py-28"
      style={{
        backgroundImage: `linear-gradient(rgba(3, 27, 78, 0.7), rgba(3, 27, 78, 0.7)), url(${featureImage})`,
      }}
    >
      <div className="container mx-auto px-6 text-center text-white">
        {/* Header Section */}
        <div className="max-w-3xl mx-auto mb-14 animate-fadeIn">
          <h1 className="text-3xl md:text-4xl lg:text-5xl font-bold mb-6">
            The Best Medical Test & Laboratory Solution
          </h1>
          <p className="text-gray-200 text-base md:text-lg leading-relaxed">
            We provide state-of-the-art lab services and expert analysis, ensuring precision and care in every test we perform.
          </p>
        </div>

        {/* Features Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-6">
          {[
            {
              icon: "bi-person-plus",
              title: "Experienced Doctors",
              text: "Highly qualified professionals dedicated to your health.",
            },
            {
              icon: "bi-check-all",
              title: "Advanced Microscopy",
              text: "Cutting-edge technology for accurate sample analysis.",
            },
            {
              icon: "bi-heart-pulse",
              title: "Heart Monitoring",
              text: "Reliable and real-time heart diagnostics and monitoring.",
            },
            {
              icon: "bi-droplet",
              title: "Blood Analysis",
              text: "Comprehensive blood tests with rapid results.",
            },
            {
              icon: "bi-gear-wide",
              title: "Modern Lab Equipment",
              text: "Precision instruments ensuring dependable results.",
            },
          ].map((item, i) => (
            <div
              key={i}
              className="bg-white text-gray-800 rounded-2xl p-6 shadow-lg hover:shadow-2xl transition duration-300 transform hover:-translate-y-2 animate-fadeIn group"
              style={{ animationDelay: `${0.2 * (i + 1)}s` }}
            >
              <div className="flex items-center justify-center w-16 h-16 mx-auto mb-4 bg-[#3368C6]/10 rounded-full group-hover:bg-[#3368C6]/20 transition">
                <i className={`bi ${item.icon} text-[#3368C6] text-3xl`}></i>
              </div>
              <h3 className="text-xl font-semibold mb-2 group-hover:text-[#3368C6] transition">
                {item.title}
              </h3>
              <p className="text-gray-600 text-sm">{item.text}</p>
            </div>
          ))}
        </div>

        {/* Button */}
        <div className="mt-12">
          <a
            href="#"
            className="inline-block bg-[#3368C6] hover:bg-blue-700 text-white font-semibold py-3 px-8 rounded-lg transition-colors duration-300"
          >
            Explore More
          </a>
        </div>
      </div>
    </section>
  );
};

export default Features2;
