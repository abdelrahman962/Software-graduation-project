import TopBar from "../components/TopBar";
import Brand from "../components/Brand";
import Navbar from "../components/Navbar";
import HeaderCarousel from "../components/HeaderCarousel";
import Features from "../components/Features";
import Service from "../components/Service";
import Footer from "../components/Footer";
import BackToTop from "../components/BackToTop";
import Spinner from "../components/Spinner";

const Home = () => {
  return (
    <>
      <Spinner />
      <TopBar />
      <Brand />
      <Navbar />
      <HeaderCarousel />
      <Features />
      <Service />
      <Footer />
      <BackToTop />
    </>
  );
};

export default Home;