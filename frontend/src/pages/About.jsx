import TopBar from "../components/TopBar";
import Brand from "../components/Brand";
import Navbar from "../components/Navbar";
import Features2 from "../components/Features2";
import Spinner from "../components/Spinner";
import PageHeader from "../components/PageHeader";
import MissionSection from "../components/MissionSection";
import Footer from "../components/Footer";
import BackToTop from "../components/BackToTop";
const About = () => {
  return (
    <>
      <Spinner />
      <TopBar />
      <Brand />
      <Navbar />
    <PageHeader title="About"/>
         <MissionSection/>

    <Features2/>
    <Footer/>
          <BackToTop />

    </>
  );
};

export default About;