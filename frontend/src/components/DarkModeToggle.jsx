import { useContext } from "react";
import { ThemeContext } from "../context/ThemeContext";

export default function DarkModeToggle() {
  const { darkMode, toggleTheme } = useContext(ThemeContext);

  return (
    <button
      onClick={toggleTheme}
      className="px-3 py-1 bg-gray-200 dark:bg-gray-700 rounded-lg transition-colors"
    >
      {darkMode ? "🌙 Dark" : "☀️ Light"}
    </button>
  );
}
