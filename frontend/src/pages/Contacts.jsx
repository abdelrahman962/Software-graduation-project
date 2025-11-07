import TopBar from "../components/TopBar";
import Brand from "../components/Brand";
import Navbar from "../components/Navbar";
import Features2 from "../components/Features2";
import Spinner from "../components/Spinner";
import PageHeader from "../components/PageHeader";
import Service  from "../components/Service"
import Footer from "../components/Footer";
import BackToTop from "../components/BackToTop";
import Contact from "../components/Contact";
const Contacts = () => {
  return (
    <>
      <Spinner />
      <TopBar />
      <Brand />
      <Navbar />
    <PageHeader title="Contacts"/>
    <Contact/>
    <Footer/>
    <BackToTop/>

    </>
  );
};

export default Contacts;