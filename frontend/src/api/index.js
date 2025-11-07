import axios from "axios";

const API = axios.create({
  baseURL: "http://localhost:5000/api", // adjust to your backend
  headers: {
    "Content-Type": "application/json",
  },
});

// Optionally add token if using auth
API.interceptors.request.use((config) => {
  const token = localStorage.getItem("token");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export default API;
