import React from "react";

const Services = () => {
  const services = [
    { icon: "bi-heart-pulse", title: "Pathology Testing", delay: "0.1s" },
    { icon: "bi-lungs", title: "Microbiology Tests", delay: "0.2s" },
    { icon: "bi-virus", title: "Biochemistry Tests", delay: "0.3s" },
    { icon: "bi-capsule-pill", title: "Histopatology Tests", delay: "0.4s" },
    { icon: "bi-capsule", title: "Urine Tests", delay: "0.1s" },
    { icon: "bi-prescription2", title: "Blood Tests", delay: "0.2s" },
    { icon: "bi-clipboard2-pulse", title: "Fever Tests", delay: "0.3s" },
    { icon: "bi-file-medical", title: "Allergy Tests", delay: "0.4s" },
  ];

  return (
    <div
      className="w-full py-12 relative"
      style={{
        "--bs-light": "#F6FAFF",
        "--bs-dark": "#031B4E",
        "--bs-primary": "#3368C6",
        "--bs-gray": "#8A91AC",
      }}
    >
      <div className="absolute inset-0 bg-[var(--bs-light)] clip-path-[polygon(0_0,_100%_0,_100%_30%,_0_70%)] z-[-1]"></div>
      
      {/* Added padding for all screen sizes */}
      <div className="w-full px-6 sm:px-10 md:px-16 lg:px-24 xl:px-32">
        <div className="text-center mx-auto animate-fadeInUp max-w-4xl">
          <h1 className="text-4xl md:text-5xl lg:text-5xl mb-3 font-bold text-[var(--bs-dark)]">
            Reliable & High-Quality Laboratory Service
          </h1>
          <p className="text-sm md:text-base lg:text-lg mb-5 text-[var(--bs-gray)]">
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur tellus augue, iaculis id elit eget, ultrices pulvinar tortor.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8 mt-8">
          {services.map((service, index) => (
            <div
              key={index}
              className="group animate-fadeInUp"
              style={{
                animationDelay: service.delay,
                animationDuration: "0.5s",
              }}
            >
              <div
                className="service-item p-4 bg-white shadow-md rounded-lg text-center transition-all duration-300 hover:shadow-lg md:hover:scale-105 m-4"
                style={{
                  background: "white",
                  transition: "background 0.5s ease",
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = `linear-gradient(to bottom, var(--bs-primary), var(--bs-primary))`;
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = "white";
                }}
              >
                <div className="flex justify-center mb-4">
                  <div className="w-10 h-10 bg-[var(--bs-light)] rounded-full flex items-center justify-center transition-transform duration-300 group-hover:scale-110">
                    <i
                      className={`bi ${service.icon} text-[var(--bs-dark)] text-xl md:text-2xl lg:text-2xl`}
                    ></i>
                  </div>
                </div>
                <h5 className="text-lg md:text-xl lg:text-2xl mb-2 font-semibold text-[var(--bs-dark)] text-center transition-colors duration-300 group-hover:text-white">
                  {service.title}
                </h5>
                <p className="text-sm md:text-sm lg:text-base mb-4 text-[var(--bs-gray)] text-center transition-colors duration-300 group-hover:text-white">
                  Lorem ipsum dolor sit amet, consectetur adipiscing elit.
                </p>
                <a
                  href="#"
                  className="inline-block bg-[var(--bs-light)] text-[var(--bs-dark)] py-2 px-4 rounded text-sm md:text-base lg:text-base transition-colors duration-300 hover:bg-[var(--bs-primary)] hover:text-white"
                >
                  Read More<i className="bi bi-chevron-double-right ml-1"></i>
                </a>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default Services;
