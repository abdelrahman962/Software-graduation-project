import React, { useState, useEffect } from "react";

const features = [
  { icon: "bi-award", title: "Award Winning", text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur tellus augue." },
  { icon: "bi-people", title: "Expert Doctors", text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur tellus augue." },
  { icon: "bi-cash-coin", title: "Fair Prices", text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur tellus augue." },
  { icon: "bi-headphones", title: "24/7 Support", text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur tellus augue." },
];

const Features = () => {
  const [activeCard, setActiveCard] = useState(null);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    setIsLoaded(true);

    const style = document.createElement("style");
    style.innerHTML = `
      @keyframes pulse-once {
        0% { transform: scale(1); }
        50% { transform: scale(1.05); }
        100% { transform: scale(1); }
      }
      .animate-pulse-once {
        animation: pulse-once 0.3s ease-in-out;
      }
    `;
    document.head.appendChild(style);

    return () => {
      document.head.removeChild(style);
    };
  }, []);

  const handleCardClick = (index) => {
    setActiveCard(activeCard === index ? null : index);
    console.log(`Clicked on ${features[index].title} card`);
  };

  return (
    <div className="w-full py-12 bg-white">
      <div className="w-full px-6 sm:px-10 md:px-16 lg:px-24 xl:px-32">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          {features.map((feature, index) => (
            <div
              key={index}
              className={`feature-item border border-gray-200 rounded-lg p-8 shadow-md cursor-pointer transition-all duration-300 m-4 ${
                isLoaded ? "opacity-100 translate-y-0" : "opacity-0 translate-y-10"
              } ${
                activeCard === index
                  ? "bg-blue-50 shadow-lg animate-pulse-once"
                  : "hover:shadow-xl hover:scale-105 hover:-rotate-2"
              }`}
              style={{ transitionDelay: `${index * 0.1}s` }}
              onClick={() => handleCardClick(index)}
            >
              <div className="icon-box-primary mb-4">
                <i
                  className={`${feature.icon} text-blue-700 text-2xl transition-transform duration-300 hover:rotate-12`}
                ></i>
              </div>
              <h5 className="mb-3 text-lg font-semibold text-gray-800">{feature.title}</h5>
              <p className="mb-0 text-gray-600 text-sm">{feature.text}</p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

export default Features;










// import React, { useState, useEffect } from "react";

// const features = [
//   {
//     icon: "bi-award",
//     title: "Award Winning",
//     text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur tellus augue.",
//   },
//   {
//     icon: "bi-people",
//     title: "Expert Doctors",
//     text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur tellus augue.",
//   },
//   {
//     icon: "bi-cash-coin",
//     title: "Fair Prices",
//     text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur tellus augue.",
//   },
//   {
//     icon: "bi-headphones",
//     title: "24/7 Support",
//     text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Curabitur tellus augue.",
//   },
// ];

// const Features = () => {
//   const [activeCard, setActiveCard] = useState(null);
//   const [isLoaded, setIsLoaded] = useState(false);

//   useEffect(() => {
//     setIsLoaded(true);

//     // Inject custom CSS for pulse animation directly into document head
//     const style = document.createElement("style");
//     style.innerHTML = `
//       @keyframes pulse-once {
//         0% { transform: scale(1); }
//         50% { transform: scale(1.05); }
//         100% { transform: scale(1); }
//       }
//       .animate-pulse-once {
//         animation: pulse-once 0.3s ease-in-out;
//       }
//     `;
//     document.head.appendChild(style);

//     return () => {
//       document.head.removeChild(style);
//     };
//   }, []);

//   const handleCardClick = (index) => {
//     setActiveCard(activeCard === index ? null : index);
//     console.log(`Clicked on ${features[index].title} card`);
//   };

//   return (
//     <div className="w-full py-12 bg-white">
//       <div className="max-w-screen-xl mx-auto px-6 lg:px-20">
//         <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
//           {features.map((feature, index) => (
//             <div
//               key={index}
//               className={`feature-item border border-gray-200 rounded-lg p-8 shadow-md cursor-pointer transition-all duration-300 m-4 ${
//                 isLoaded ? "opacity-100 translate-y-0" : "opacity-0 translate-y-10"
//               } ${
//                 activeCard === index
//                   ? "bg-blue-50 shadow-lg animate-pulse-once"
//                   : "hover:shadow-xl hover:scale-105 hover:-rotate-2"
//               }`}
//               style={{
//                 transitionDelay: `${index * 0.1}s`,
//               }}
//               onClick={() => handleCardClick(index)}
//             >
//               <div className="icon-box-primary mb-4">
//                 <i
//                   className={`${feature.icon} text-blue-700 text-2xl transition-transform duration-300 hover:rotate-12`}
//                 ></i>
//               </div>
//               <h5 className="mb-3 text-lg font-semibold text-gray-800">
//                 {feature.title}
//               </h5>
//               <p className="mb-0 text-gray-600 text-sm">{feature.text}</p>
//             </div>
//           ))}
//         </div>
//       </div>
//     </div>
//   );
// };

// export default Features;
