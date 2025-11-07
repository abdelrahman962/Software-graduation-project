import { BrowserRouter as Router, Routes, Route } from "react-router-dom";

// Import all pages
import Home from "../pages/LandingPages/LandingHome";
import About from "../pages/LandingPages/LandingAbout";
import Services from "../pages/LandingPages/LandingServices";
import Contact from "../pages/LandingPages/LandingContact";

export default function LandingRoutes() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/about" element={<About />} />
        <Route path="/services" element={<Services />} />
        <Route path="/case-studies" element={<CaseStudies />} />
        <Route path="/contact" element={<Contact />} />
        <Route path="/apply" element={<ApplyDemo />} />
      </Routes>
    </Router>
  );
}
