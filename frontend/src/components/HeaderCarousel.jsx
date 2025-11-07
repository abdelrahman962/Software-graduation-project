// src/components/HeaderCarousel.jsx
import { useState, useEffect } from "react";
import carousel1 from "../assets/carousel-1.jpg";
import carousel2 from "../assets/carousel-2.jpg";
import "../styles/animation.css";

const slides = [
  {
    id: 1,
    image: carousel1,
    title: "Award Winning Laboratory Center",
    text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla facilisi.",
    align: "left",
  },
  {
    id: 2,
    image: carousel2,
    title: "Expert Doctors & Lab Assistants",
    text: "Donec vel justo eget felis tincidunt tempor. Proin at lacus vel justo aliquam feugiat.",
    align: "right",
  },
];

export default function HeaderCarousel() {
  const [current, setCurrent] = useState(0);
  const [isSwiping, setIsSwiping] = useState(false);
  const [touchStart, setTouchStart] = useState(null);
  const [touchMove, setTouchMove] = useState(null);

  // Auto-slide effect
  useEffect(() => {
    const timer = setInterval(() => {
      if (!isSwiping)
        setCurrent((prev) => (prev === slides.length - 1 ? 0 : prev + 1));
    }, 6000);
    return () => clearInterval(timer);
  }, [isSwiping]);

  const nextSlide = () =>
    setCurrent((prev) => (prev === slides.length - 1 ? 0 : prev + 1));
  const prevSlide = () =>
    setCurrent((prev) => (prev === 0 ? slides.length - 1 : prev - 1));

  // Touch swipe handlers
  const handleTouchStart = (e) => {
    setTouchStart(e.touches[0].clientX);
    setIsSwiping(true);
  };

  const handleTouchMove = (e) => {
    setTouchMove(e.touches[0].clientX);
  };

  const handleTouchEnd = () => {
    if (touchStart && touchMove) {
      const deltaX = touchMove - touchStart;
      if (deltaX > 50) prevSlide();
      else if (deltaX < -50) nextSlide();
    }
    setIsSwiping(false);
    setTouchStart(null);
    setTouchMove(null);
  };

  return (
    <div
      className="relative w-full overflow-hidden lg:mt-[50px] mt-[0px]"
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
    >
      {/* Slide Container */}
      <div
        className="carousel-slides flex transition-transform duration-500 ease-out"
        style={{ transform: `translateX(-${current * 100}%)` }}
      >
        {slides.map((slide, index) => (
          <div
            key={slide.id}
            className="relative w-full flex-shrink-0 flex items-center justify-center"
          >
            <img
              src={slide.image}
              alt={slide.title}
              className="w-full h-[700px] object-cover object-center"
            />

            {/* Text Overlay */}
            {index === current && (
              <div className="absolute inset-0 bg-black bg-opacity-50 flex items-center">
                <div
                  className={`container px-4 mx-auto flex ${
                    slide.align === "right" ? "justify-end" : "justify-start"
                  }`}
                >
                  <div
                    className={`text-white max-w-xl ${
                      slide.align === "right"
                        ? "text-right ml-auto"
                        : "text-left mr-auto"
                    } px-4 fade-in-up ${
                      slide.align === "right" ? "slide-left" : "slide-right"
                    }`}
                  >
                    <h1 className="text-2xl sm:text-3xl md:text-4xl lg:text-5xl font-bold mb-4">
                      {slide.title}
                    </h1>
                    <p className="text-sm sm:text-base md:text-lg mb-6">
                      {slide.text}
                    </p>
                    <a
                      href="#"
                      className="inline-block bg-blue-700 hover:bg-blue-800 text-white font-semibold py-2 px-4 sm:py-3 sm:px-6 rounded-lg transition-colors duration-300"
                    >
                      Explore More
                    </a>
                  </div>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Navigation Buttons */}
      <button
        onClick={prevSlide}
        className="absolute left-4 top-1/2 transform -translate-y-1/2 bg-blue-700 text-white p-3 rounded-full hover:bg-blue-800 transition-colors duration-300"
      >
        <svg
          className="w-6 h-6"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="2"
            d="M15 19l-7-7 7-7"
          />
        </svg>
      </button>
      <button
        onClick={nextSlide}
        className="absolute right-4 top-1/2 transform -translate-y-1/2 bg-blue-700 text-white p-3 rounded-full hover:bg-blue-800 transition-colors duration-300"
      >
        <svg
          className="w-6 h-6"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="2"
            d="M9 5l7 7-7 7"
          />
        </svg>
      </button>

      {/* Carousel Indicators */}
      <div className="absolute bottom-4 left-1/2 transform -translate-x-1/2 flex space-x-2">
        {slides.map((_, index) => (
          <button
            key={index}
            onClick={() => setCurrent(index)}
            className={`w-3 h-3 rounded-full ${
              index === current ? "bg-blue-700" : "bg-gray-300"
            }`}
          />
        ))}
      </div>
    </div>
  );
}
