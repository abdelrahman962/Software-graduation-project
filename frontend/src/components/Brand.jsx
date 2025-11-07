import useScrollHide from "../hooks/useScrollHide";

export default function Brand() {
  const hidden = useScrollHide(100);

  return (
    <div
      className={`hidden lg:flex fixed top-[40px] w-full bg-[#3368C6] text-white py-5 z-[950] shadow-md transition-transform duration-500 ease-in-out ${
        hidden ? "-translate-y-full" : "translate-y-0"
      }`}
    >
      <div className="max-w-screen-xl w-full flex justify-between items-center px-10 mx-auto">
        {/* Left - Call */}
        <div className="flex items-center gap-4 font-semibold">
          <i className="bi bi-telephone-inbound text-3xl"></i>
          <div>
            <h5 className="mb-0 text-lg">Call Now</h5>
            <span>+012 345 6789</span>
          </div>
        </div>

        {/* Center - Logo */}
        <a href="/" className="text-4xl font-extrabold">
          Lab<span className="text-gray-200">sky</span>
        </a>

        {/* Right - Mail */}
        <div className="flex items-center gap-4 font-semibold">
          <i className="bi bi-envelope text-3xl"></i>
          <div>
            <h5 className="mb-0 text-lg">Mail Now</h5>
            <span>info@example.com</span>
          </div>
        </div>
      </div>
    </div>
  );
}
