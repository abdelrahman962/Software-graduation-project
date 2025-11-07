import React from "react";

export default function MissionSection() {
  return (
    <>
      <style>{`
        @keyframes popIn {
          0% {
            opacity: 0;
            transform: scale(0.95) translateY(20px);
          }
          70% {
            opacity: 1;
            transform: scale(1.05);
          }
          100% {
            opacity: 1;
            transform: scale(1) translateY(0);
          }
        }
        .animate-popIn {
          animation: popIn 0.8s ease-out forwards;
        }
        .group-hover\\:animate-iconBounce {
          transition: transform 0.3s ease;
        }
        .group:hover .group-hover\\:animate-iconBounce {
          transform: rotate(15deg) scale(1.2);
        }
      `}</style>
      <section
        className="container-fluid py-8 md:py-10 lg:py-12 xl:py-16 bg-cover bg-white"
        style={{
          background: `url(/src/assets/mission-bg.jpg) center center no-repeat`,
          backgroundSize: "cover",
        }}
      >
        <div className="container mx-auto px-4 lg:px-24 text-center">
          <h2 className="text-3xl md:text-4xl lg:text-5xl font-semibold text-[#3368C6] mb-6 md:mb-8 lg:mb-10 animate-slideInDown" style={{ animationDuration: '1s' }}>
            Our Mission, Vision & Values
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-6 lg:gap-8 xl:gap-10">
            <div className="bg-white rounded-xl shadow-md p-6 md:p-8 hover:shadow-xl hover:-translate-y-2 transition-all duration-300 group animate-popIn" style={{ animationDelay: '0.3s' }}>
              <div className="flex items-center justify-center w-12 md:w-14 lg:w-16 h-12 md:h-14 lg:h-16 bg-blue-100 rounded-full mb-3 md:mb-4 transition-transform group-hover:animate-iconBounce">
                <i className="bi bi-bullseye text-gray-900 text-lg md:text-xl lg:text-2xl"></i>
              </div>
              <h3 className="text-xl md:text-2xl lg:text-3xl font-semibold text-blue-600 mb-3 md:mb-4 transition-colors group-hover:text-[#3368C6]">Mission</h3>
              <p className="text-gray-600 text-sm md:text-base lg:text-lg">
                To provide accurate, reliable, and timely diagnostic results using state-of-the-art technology and expert staff.
              </p>
            </div>
            <div className="bg-white rounded-xl shadow-md p-6 md:p-8 hover:shadow-xl hover:-translate-y-2 transition-all duration-300 group animate-popIn" style={{ animationDelay: '0.5s' }}>
              <div className="flex items-center justify-center w-12 md:w-14 lg:w-16 h-12 md:h-14 lg:h-16 bg-blue-100 rounded-full mb-3 md:mb-4 transition-transform group-hover:animate-iconBounce">
                <i className="bi bi-eye text-gray-900 text-lg md:text-xl lg:text-2xl"></i>
              </div>
              <h3 className="text-xl md:text-2xl lg:text-3xl font-semibold text-blue-600 mb-3 md:mb-4 transition-colors group-hover:text-[#3368C6]">Vision</h3>
              <p className="text-gray-600 text-sm md:text-base lg:text-lg">
                To be the most trusted medical laboratory in the region, setting the standard for excellence in diagnostics and patient care.
              </p>
            </div>
            <div className="bg-white rounded-xl shadow-md p-6 md:p-8 hover:shadow-xl hover:-translate-y-2 transition-all duration-300 group animate-popIn" style={{ animationDelay: '0.7s' }}>
              <div className="flex items-center justify-center w-12 md:w-14 lg:w-16 h-12 md:h-14 lg:h-16 bg-blue-100 rounded-full mb-3 md:mb-4 transition-transform group-hover:animate-iconBounce">
                <i className="bi bi-heart text-gray-900 text-lg md:text-xl lg:text-2xl"></i>
              </div>
              <h3 className="text-xl md:text-2xl lg:text-3xl font-semibold text-blue-600 mb-3 md:mb-4 transition-colors group-hover:text-[#3368C6]">Values</h3>
              <p className="text-gray-600 text-sm md:text-base lg:text-lg">
                Integrity, precision, compassion, and innovation guide everything we do to improve patient health outcomes.
              </p>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}