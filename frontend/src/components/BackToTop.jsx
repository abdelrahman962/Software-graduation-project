import React from "react";

const BackToTop = () => {
  return (
    <a
      href="#"
      className="fixed right-8 bottom-8 z-50 w-16 h-16 bg-[#3368c6] text-[var(--bs-light)] rounded-full flex items-center justify-center transition duration-500 hover:bg-blue-500"
    >
      <i className="fa fa-arrow-up"></i>
    </a>
  );
};

export default BackToTop;