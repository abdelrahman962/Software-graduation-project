
const Contact = () => {
  return (
    <section className="relative bg-white py-20 px-4 sm:px-8 lg:px-24 overflow-hidden">
      <div className="container mx-auto">
        {/* Section Header */}
        <div
          className="text-center mx-auto max-w-2xl mb-16 animate-fadeInUp"
          style={{ animationDelay: "0.1s" }}
        >
          <h2 className="text-blue-700 text-sm uppercase font-semibold tracking-wider mb-3">
            Contact Us
          </h2>
          <h1 className="text-3xl sm:text-4xl md:text-5xl font-bold text-[#031B4E] mb-6">
            Have Any Query? Feel Free To Contact Us
          </h1>
          <p className="text-gray-600 text-lg leading-relaxed">
            We’re here to help! Whether you have a question about your test results, want to
            schedule an appointment, or simply need more information about our laboratory
            services in Nablus — our team is ready to assist.
          </p>
        </div>

        {/* Contact Info Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-8 mb-16">
          {/* Phone */}
          <div
            className="flex items-center justify-center bg-[#021640] rounded-2xl p-8 shadow-lg hover:shadow-2xl transition-all duration-300 animate-fadeInUp"
            style={{ animationDelay: "0.1s" }}
          >
            <div className="flex items-center gap-4">
              <div className="bg-white text-blue-800 p-4 rounded-full">
                <i className="bi bi-telephone text-2xl"></i>
              </div>
              <div>
                <h5 className="text-blue-100 font-semibold text-sm uppercase">Call Us</h5>
                <h2 className="text-2xl font-bold text-white">+972 599 123 456</h2>
              </div>
            </div>
          </div>

          {/* Email */}
          <div
            className="flex items-center justify-center bg-[#021640] rounded-2xl p-8 shadow-lg hover:shadow-2xl transition-all duration-300 animate-fadeInUp"
            style={{ animationDelay: "0.2s" }}
          >
            <div className="flex items-center gap-4">
              <div className="bg-white text-blue-800 p-4 rounded-full">
                <i className="bi bi-envelope text-2xl"></i>
              </div>
              <div>
                <h5 className="text-blue-100 font-semibold text-sm uppercase">Mail Us</h5>
                <h2 className="text-2xl font-bold text-white">info@gmail.com</h2>
              </div>
            </div>
          </div>
        </div>

        {/* Contact Form + Map */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-start">
          {/* Contact Form */}
          <div
            className="bg-white shadow-lg rounded-2xl p-8 animate-fadeInUp"
            style={{ animationDelay: "0.1s" }}
          >
            <h3 className="text-2xl font-semibold text-gray-900 mb-4">
              Send Us a Message
            </h3>
            <p className="text-gray-600 mb-6">
              Fill out the form below and our support team will contact you as soon as possible.
            </p>

            <form className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <input
                  type="text"
                  placeholder="Your Name"
                  className="border border-gray-300 rounded-lg px-4 py-3 focus:ring-2 focus:ring-blue-600 focus:outline-none"
                />
                <input
                  type="email"
                  placeholder="Your Email"
                  className="border border-gray-300 rounded-lg px-4 py-3 focus:ring-2 focus:ring-blue-600 focus:outline-none"
                />
              </div>

              <input
                type="text"
                placeholder="Subject"
                className="border border-gray-300 rounded-lg w-full px-4 py-3 focus:ring-2 focus:ring-blue-600 focus:outline-none"
              />

              <textarea
                rows="5"
                placeholder="Your Message"
                className="border border-gray-300 rounded-lg w-full px-4 py-3 focus:ring-2 focus:ring-blue-600 focus:outline-none"
              ></textarea>

              <button
                type="submit"
                className="w-full bg-blue-700 text-white font-semibold py-3 rounded-lg hover:bg-blue-800 transition-all duration-300"
              >
                Send Message
              </button>
            </form>
          </div>

          {/* Map */}
          <div
            className="overflow-hidden rounded-2xl shadow-lg animate-fadeInUp"
            style={{ animationDelay: "0.4s" }}
          >
            <iframe
              className="w-full h-[400px] rounded-2xl"
              src="https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d3456.123456!2d35.295556!3d32.221111!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x1502f123456789ab%3A0xabcdef1234567890!2sNablus%2C%20Palestine!5e0!3m2!1sen!2s!4v1603794290143!5m2!1sen!2s"
              allowFullScreen=""
              loading="lazy"
              title="Our Location"
            ></iframe>
          </div>
        </div>
      </div>
    </section>
  );
};

export default Contact;
