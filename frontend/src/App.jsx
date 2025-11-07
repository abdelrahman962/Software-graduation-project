// App.jsx
import { BrowserRouter as Router, Routes, Route, Link } from "react-router-dom";
import AppRoutes from "./routes";
import LandingRoutes from "./routes/LandingRoutes";

function App() {
  return <LandingRoutes />;
}

export default App;
