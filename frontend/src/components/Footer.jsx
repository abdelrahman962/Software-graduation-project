import React from "react";

const Footer = () => {
  return (
    <div
      className="container-fluid py-16 relative animate-fadeIn"
      style={{
        '--bs-dark': '#031B4E',
        '--bs-primary': '#3368C6',
        '--bs-light': '#F6FAFF',
        '--bs-gray': '#8A91AC',
        '--bs-blue': '#0d6efd',
        '--bs-indigo': '#6610f2',
        '--bs-purple': '#6f42c1',
        '--bs-pink': '#d63384',
        '--bs-red': '#dc3545',
        '--bs-orange': '#fd7e14',
        '--bs-yellow': '#ffc107',
        '--bs-green': '#198754',
        '--bs-teal': '#20c997',
        '--bs-cyan': '#0dcaf0',
        '--bs-white': '#fff',
        '--bs-gray': '#6c757d',
        '--bs-gray-dark': '#343a40',
        '--bs-secondary': '#8A91AC',
        '--bs-success': '#198754',
        '--bs-info': '#0dcaf0',
        '--bs-warning': '#ffc107',
        '--bs-danger': '#dc3545',
        '--bs-font-sans-serif': 'system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", "Liberation Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"',
        '--bs-font-monospace': 'SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace',
        '--bs-gradient': 'linear-gradient(180deg, rgba(255, 255, 255, 0.15), rgba(255, 255, 255, 0))',
        background: 'linear-gradient(var(--bs-dark), var(--bs-dark)), url(/src/assets/footer.png) center center no-repeat',
        backgroundSize: 'contain',
        backgroundBlendMode: 'overlay',
        opacity: 1,
        color: '#FFFFFF',
        animationDelay: '0.1s',
        animationDuration: '0.5s',
      }}
    >
      <div className="container mx-auto py-8 pl-12">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 relative">
          <div className="lg:pr-12">
            <a href="/" className="flex items-center mb-6">
              <h1 className="text-3xl md:text-4xl font-bold text-[var(--bs-primary)] leading-tight">
                Lab<span className="text-white">sky</span>
              </h1>
            </a>
            <p className="text-lg md:text-xl mb-6 text-gray-200 leading-relaxed">
              Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur tellus augue, iaculis id elit eget, ultrices pulvinar tortor.
            </p>
            <p className="text-sm md:text-base mb-3 flex items-center"><i className="fa fa-map-marker-alt mr-3"></i>123 Street, New York, USA</p>
            <p className="text-sm md:text-base mb-3 flex items-center"><i className="fa fa-phone-alt mr-3"></i>+012 345 67890</p>
            <p className="text-sm md:text-base mb-6 flex items-center"><i className="fa fa-envelope mr-3"></i>info@example.com</p>
            <div className="flex space-x-3 mt-6">
              <a href="#" className="bg-[var(--bs-primary)] text-white rounded-full w-12 h-12 flex items-center justify-center hover:bg-blue-700 transition-colors duration-300">
                <i className="fab fa-twitter text-xl"></i>
              </a>
              <a href="#" className="bg-[var(--bs-primary)] text-white rounded-full w-12 h-12 flex items-center justify-center hover:bg-blue-700 transition-colors duration-300">
                <i className="fab fa-facebook-f text-xl"></i>
              </a>
              <a href="#" className="bg-[var(--bs-primary)] text-white rounded-full w-12 h-12 flex items-center justify-center hover:bg-blue-700 transition-colors duration-300">
                <i className="fab fa-linkedin-in text-xl"></i>
              </a>
              <a href="#" className="bg-[var(--bs-primary)] text-white rounded-full w-12 h-12 flex items-center justify-center hover:bg-blue-700 transition-colors duration-300">
                <i className="fab fa-instagram text-xl"></i>
              </a>
            </div>
          </div>
          <div className="lg:pl-12">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-8">
              <div>
                <h4 className="text-xl md:text-2xl text-white mb-6">Quick Links</h4>
                <div className="space-y-4">
                  <a href="#" className="block text-base md:text-lg text-gray-300 hover:text-[var(--bs-primary)] transition-colors duration-300 before:content-['\f105'] before:font-awesome before:text-gray-300 before:mr-3 before:transition-colors before:hover:text-[var(--bs-primary)] text-left leading-loose">About Us</a>
                  <a href="#" className="block text-base md:text-lg text-gray-300 hover:text-[var(--bs-primary)] transition-colors duration-300 before:content-['\f105'] before:font-awesome before:text-gray-300 before:mr-3 before:transition-colors before:hover:text-[var(--bs-primary)] text-left leading-loose">Contact Us</a>
                  <a href="#" className="block text-base md:text-lg text-gray-300 hover:text-[var(--bs-primary)] transition-colors duration-300 before:content-['\f105'] before:font-awesome before:text-gray-300 before:mr-3 before:transition-colors before:hover:text-[var(--bs-primary)] text-left leading-loose">Our Services</a>
                  <a href="#" className="block text-base md:text-lg text-gray-300 hover:text-[var(--bs-primary)] transition-colors duration-300 before:content-['\f105'] before:font-awesome before:text-gray-300 before:mr-3 before:transition-colors before:hover:text-[var(--bs-primary)] text-left leading-loose">Terms & Condition</a>
                  <a href="#" className="block text-base md:text-lg text-gray-300 hover:text-[var(--bs-primary)] transition-colors duration-300 before:content-['\f105'] before:font-awesome before:text-gray-300 before:mr-3 before:transition-colors before:hover:text-[var(--bs-primary)] text-left leading-loose">Support</a>
                </div>
              </div>
              <div>
                <h4 className="text-xl md:text-2xl text-white mb-6">Popular Links</h4>
                <div className="space-y-4">
                  <a href="#" className="block text-base md:text-lg text-gray-300 hover:text-[var(--bs-primary)] transition-colors duration-300 before:content-['\f105'] before:font-awesome before:text-gray-300 before:mr-3 before:transition-colors before:hover:text-[var(--bs-primary)] text-left leading-loose">About Us</a>
                  <a href="#" className="block text-base md:text-lg text-gray-300 hover:text-[var(--bs-primary)] transition-colors duration-300 before:content-['\f105'] before:font-awesome before:text-gray-300 before:mr-3 before:transition-colors before:hover:text-[var(--bs-primary)] text-left leading-loose">Contact Us</a>
                  <a href="#" className="block text-base md:text-lg text-gray-300 hover:text-[var(--bs-primary)] transition-colors duration-300 before:content-['\f105'] before:font-awesome before:text-gray-300 before:mr-3 before:transition-colors before:hover:text-[var(--bs-primary)] text-left leading-loose">Our Services</a>
                  <a href="#" className="block text-base md:text-lg text-gray-300 hover:text-[var(--bs-primary)] transition-colors duration-300 before:content-['\f105'] before:font-awesome before:text-gray-300 before:mr-3 before:transition-colors before:hover:text-[var(--bs-primary)] text-left leading-loose">Terms & Condition</a>
                  <a href="#" className="block text-base md:text-lg text-gray-300 hover:text-[var(--bs-primary)] transition-colors duration-300 before:content-['\f105'] before:font-awesome before:text-gray-300 before:mr-3 before:transition-colors before:hover:text-[var(--bs-primary)] text-left leading-loose">Support</a>
                </div>
              </div>
              {/* <div className="sm:col-span-2">
                <h4 className="text-xl md:text-2xl text-white mb-6">Newsletter</h4>
                <div className="w-full">
                  <div className="flex rounded-lg overflow-hidden">
                    <input
                      type="text"
                      className="flex-1 border-0 py-3 px-5 rounded-l-lg text-lg text-white bg-gray-800 placeholder-gray-400"
                      placeholder="Your Email Address"
                    />
                    <button className="bg-[var(--bs-primary)] text-white py-3 px-6 rounded-r-lg text-lg hover:bg-blue-700 transition-colors duration-300">
                      Sign Up
                    </button>
                  </div>
                </div>
              </div> */}
            </div>
          </div>
          {/* Dashed vertical line for lg screens */}
          <div className="hidden lg:block absolute top-2 right-1/2 h-full w-px bg-transparent after:content-[''] after:absolute after:top-0 after:right-0 after:h-full after:w-px after:border-l after:border-dashed after:border-gray-500/20 after:translate-x-1/2"></div>
        </div>
        {/* Copyright Section */}
        <div
          className="container-fluid bg-[var(--bs-dark)] text-gray-500 py-0 mt-4 mb-0 border-t border-dashed border-[rgba(255,255,255,0.2)]"
        >
          <div className="container mx-auto">
            <div className="flex flex-col md:flex-row justify-between items-center">
              <div className="text-center md:text-left">
                <p className="mb-0 text-base leading-4">&copy; <a href="#" className="text-gray-500 hover:text-[var(--bs-primary)] transition-colors duration-300">Your Site Name</a>. All Rights Reserved.</p>
              </div>
              <div className="text-center md:text-right">
                <p className="mb-0 text-base leading-4">Designed by <a href="https://htmlcodex.com" className="text-gray-500 hover:text-[var(--bs-primary)] transition-colors duration-300">HTML Codex</a></p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Footer;