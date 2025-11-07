import React from "react";

const PageHeader = ({title}) => {
  return (
    <div
      className="container-fluid py-16 sm:py-20 md:py-24 mb-4 animate-fadeIn"
      style={{
        background: `linear-gradient(rgba(3, 27, 78, 0.3), rgba(3, 27, 78, 0.3)), url(/src/assets/testimonial.jpg) center center no-repeat`,
        backgroundSize: "cover",
      }}
    >
      <div className="container text-center py-10 sm:py-12 md:py-20">
        {/* Title */}
        <h1 className="text-white text-3xl sm:text-4xl md:text-5xl font-semibold mb-4 animate-slideInDown">
         {title}
        </h1>

        {/* Breadcrumb */}
        <nav
          aria-label="breadcrumb"
          className="flex flex-wrap justify-center items-center gap-2 text-white font-semibold text-base sm:text-lg animate-slideInDown"
        >
          <a href="#" className="hover:underline">
            Home
          </a>
          <span>/</span>
          <a href="#" className="hover:underline">
            Pages
          </a>
          <span>/</span>
          <span>About</span>
        </nav>
      </div>
    </div>
  );
};

export default PageHeader;
