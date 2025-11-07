export default function Footer() {
  return (
    <footer className="bg-gray-900 text-white text-center py-6 mt-10">
      <p className="text-sm">
        © {new Date().getFullYear()} Medical Lab System. All rights reserved.
      </p>
    </footer>
  );
}
