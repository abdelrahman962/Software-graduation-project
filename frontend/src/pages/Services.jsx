import TopBar from "../components/TopBar";
import Brand from "../components/Brand";
import Navbar from "../components/Navbar";
import Spinner from "../components/Spinner";
import PageHeader from "../components/PageHeader";
import Service  from "../components/Service"
import Footer from "../components/Footer";
import BackToTop from "../components/BackToTop";
const About = () => {
  return (
    <>
      <Spinner />
      <TopBar />
      <Brand />
      <Navbar />
    <PageHeader title="Services"/>
    <Service/>
    <Footer/>
    <BackToTop/>

    </>
  );
};

export default About;