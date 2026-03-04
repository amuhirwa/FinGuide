import { motion, useScroll, useTransform } from "framer-motion";
import {
  Download,
  Smartphone,
  ShieldCheck,
  TrendingUp,
  Target,
  Activity,
  Zap,
  Github,
  CheckCircle2,
  Menu,
  X,
  ArrowRight,
  PieChart,
  BrainCircuit,
} from "lucide-react";
import { useState, useEffect } from "react";

const APK_URL = "https://github.com/amuhirwa/FinGuide/releases/latest/download/finguide.apk";
const GITHUB_URL = "https://github.com/amuhirwa/FinGuide";

export default function App() {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const { scrollY } = useScroll();
  const y1 = useTransform(scrollY, [0, 1000], [0, 200]);
  const y2 = useTransform(scrollY, [0, 1000], [0, -200]);

  // Handle navbar background on scroll
  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 50);
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const navLinks = [
    { name: "Features", href: "#features" },
    { name: "How it works", href: "#how-it-works" },
    { name: "Tech", href: "#tech" },
  ];

  return (
    <div className="min-h-screen relative overflow-hidden bg-white text-gray-900 font-sans selection:bg-[var(--color-primary)] selection:text-white">
      {/* Dynamic Background inspired by Cube's floating elements - Light version */}
      <div className="fixed inset-0 pointer-events-none -z-10 overflow-hidden bg-white">
        <motion.div 
          animate={{ rotate: 360 }} 
          transition={{ duration: 150, repeat: Infinity, ease: "linear" }}
          className="absolute top-[-20%] right-[-10%] w-[80vw] h-[80vw] bg-[var(--color-primary)]/10 rounded-full blur-[120px] mix-blend-multiply" 
        />
        <motion.div 
          animate={{ rotate: -360 }} 
          transition={{ duration: 200, repeat: Infinity, ease: "linear" }}
          className="absolute bottom-[-20%] left-[-10%] w-[60vw] h-[60vw] bg-[var(--color-secondary)]/15 rounded-full blur-[120px] mix-blend-multiply" 
        />
      </div>

      {/* Navigation */}
      <nav className={`fixed w-full z-50 transition-all duration-500 ${scrolled ? "bg-white/90 backdrop-blur-xl border-b border-gray-200 py-4 shadow-sm" : "bg-transparent py-6"}`}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center">
            <div className="flex items-center group cursor-pointer">
              <span className="flex items-center gap-2 font-display font-black tracking-tight text-2xl uppercase text-black">
                <div className="w-3 h-3 bg-gradient-to-tr from-[var(--color-primary)] to-[var(--color-secondary)] group-hover:scale-150 transition-transform duration-500" />
                FinGuide
              </span>
            </div>

            {/* Desktop Menu */}
            <div className="hidden md:flex items-center space-x-10">
              {navLinks.map((link) => (
                <a
                  key={link.name}
                  href={link.href}
                  className="text-xs uppercase tracking-widest font-bold text-gray-500 hover:text-black transition-colors relative group"
                >
                  {link.name}
                  <span className="absolute -bottom-2 left-0 w-0 h-0.5 bg-[var(--color-primary)] transition-all duration-300 group-hover:w-full" />
                </a>
              ))}
              <a
                href={APK_URL}
                className="group relative inline-flex items-center gap-2 px-6 py-3 bg-black text-white text-sm font-bold uppercase tracking-wide overflow-hidden"
              >
                <span className="absolute inset-0 w-full h-full bg-gradient-to-r from-[var(--color-primary)] to-[var(--color-secondary)] -translate-x-full group-hover:translate-x-0 transition-transform duration-500 ease-out" />
                <span className="relative flex items-center gap-2 transition-colors duration-300">
                  <Download size={16} />
                  Download
                </span>
              </a>
            </div>

            {/* Mobile Menu Button */}
            <div className="md:hidden flex items-center">
              <button
                onClick={() => setIsMenuOpen(!isMenuOpen)}
                className="text-black p-2 hover:text-[var(--color-primary)] transition-colors"
              >
                {isMenuOpen ? <X size={28} /> : <Menu size={28} />}
              </button>
            </div>
          </div>
        </div>

        {/* Mobile Menu - Kept Dark for High Contrast Edge */}
        {isMenuOpen && (
          <motion.div 
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            className="md:hidden absolute top-full left-0 w-full bg-gray-900/95 backdrop-blur-3xl border-b border-gray-800 px-4 py-8 shadow-2xl"
          >
            <div className="flex flex-col space-y-6">
              {navLinks.map((link) => (
                <a
                  key={link.name}
                  href={link.href}
                  onClick={() => setIsMenuOpen(false)}
                  className="text-xl font-black uppercase tracking-wider text-gray-400 hover:text-white"
                >
                  {link.name}
                </a>
              ))}
              <a
                href={APK_URL}
                className="flex items-center justify-center gap-2 w-full px-5 py-4 bg-[var(--color-primary)] text-white font-bold uppercase tracking-wide mt-4"
              >
                <Download size={18} />
                Download APK
              </a>
            </div>
          </motion.div>
        )}
      </nav>

      {/* Hero Section */}
      <section className="relative pt-40 pb-20 lg:pt-38 lg:pb-32 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto flex flex-col items-center text-center z-10">
        
        {/* Floating elements */}
        <motion.div style={{ y: y1 }} className="absolute left-[10%] top-[20%] hidden lg:block">
          <div className="w-24 h-24 border border-gray-200 rounded-full flex items-center justify-center bg-white/50 backdrop-blur-sm shadow-sm">
             <div className="w-2 h-2 bg-[var(--color-secondary)] rounded-full animate-pulse" />
          </div>
        </motion.div>
        
        <motion.div style={{ y: y2 }} className="absolute right-[15%] top-[40%] hidden lg:block">
           <div className="w-16 h-16 border border-[var(--color-primary)]/30 rotate-45 bg-white/50 backdrop-blur-sm shadow-sm" />
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, ease: "easeOut" }}
          className="max-w-4xl mx-auto"
        >
          <div className="inline-flex items-center gap-3 px-4 py-2 bg-gray-50 border border-gray-200 rounded-full text-sm font-bold tracking-widest uppercase mb-8 shadow-sm">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[var(--color-primary)] opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-[var(--color-primary)]"></span>
            </span>
            <span className="text-gray-700">v1.0 Live for Android</span>
          </div>

          <h1 className="font-display text-5xl sm:text-6xl lg:text-6xl font-black leading-[1.1] mb-8 uppercase tracking-tight text-black">
            Smart Money <br className="hidden sm:block" />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-[var(--color-primary)] to-[var(--color-secondary)]">
              For The Rwandan Youth.
            </span>
          </h1>

          <p className="text-xl text-gray-600 mb-12 max-w-2xl mx-auto leading-relaxed font-medium">
            FinGuide transforms your raw MoMo SMS history into a powerful financial compass. Forecast expenses, track goals, and build wealth—designed exclusively for irregular income earners.
          </p>

          <div className="flex flex-col sm:flex-row gap-6 justify-center items-center">
            <a
              href={APK_URL}
              className="group relative flex items-center justify-center gap-3 px-10 py-5 bg-[var(--color-primary)] text-white font-black uppercase tracking-widest overflow-hidden w-full sm:w-auto hover:shadow-xl hover:shadow-[var(--color-primary)]/20 transition-all duration-300 hover:-translate-y-1"
            >
              <span className="absolute inset-0 w-full h-full bg-white/20 -translate-x-full group-hover:translate-x-0 transition-transform duration-500 ease-out" />
              <Download className="w-5 h-5" />
              <span>Get FinGuide</span>
            </a>
            <a
              href={GITHUB_URL}
              target="_blank"
              rel="noreferrer"
              className="flex items-center justify-center gap-3 px-10 py-5 bg-white border-2 border-gray-200 text-black font-bold uppercase tracking-widest hover:border-black hover:bg-black hover:text-white transition-all duration-300 w-full sm:w-auto"
            >
              <Github className="w-5 h-5" />
              <span>Source Code</span>
            </a>
          </div>
        </motion.div>
      </section>

      {/* Stats/Ticker Section */}
      <section className="border-y border-gray-200 bg-gray-50/80 backdrop-blur-sm py-10 overflow-hidden flex">
         <div className="max-w-7xl mx-auto px-4 flex flex-wrap justify-center gap-12 md:gap-24 uppercase font-bold tracking-widest text-sm text-gray-500">
            <div className="flex items-center gap-3">
               <span className="text-3xl text-black font-black">100%</span>
               Offline First
            </div>
            <div className="flex items-center gap-3">
               <span className="text-3xl text-black font-black">0</span>
               Manual Entry required
            </div>
            <div className="flex items-center gap-3">
               <span className="text-3xl text-[var(--color-primary)] font-black">24/7</span>
               AI Forecasting
            </div>
         </div>
      </section>

      {/* Features Grid */}
      <section id="features" className="py-32 relative z-10 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col md:flex-row md:items-end justify-between mb-16 gap-8">
            <div className="max-w-2xl">
              <div className="flex items-center gap-4 mb-4">
                <div className="h-px w-12 bg-[var(--color-primary)]" />
                <h2 className="text-[var(--color-primary)] font-bold tracking-widest uppercase text-sm">
                  The Arsenal
                </h2>
              </div>
              <h3 className="font-display text-4xl md:text-5xl font-black uppercase tracking-tight text-black">
                Total Financial <br/> Dominance.
              </h3>
            </div>
            <p className="text-gray-600 text-lg max-w-sm font-medium">
              We intercept the noise and give you clear, actionable intelligence on your spending habits.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            <FeatureCard
              icon={<Smartphone />}
              title="SMS Parsing"
              desc="Automatically converts MoMo notification SMS into structured transaction data. No manual entry required."
            />
            <FeatureCard
              icon={<BrainCircuit />}
              title="AI Forecasting"
              desc="BiLSTM neural network predicts your spending for the next 7 days based on your unique history."
            />
            <FeatureCard
              icon={<ShieldCheck />}
              title="Safe-to-Spend"
              desc="Real-time budget calculation that protects your savings goals and upcoming bills."
            />
            <FeatureCard
              icon={<Target />}
              title="Smart Goals"
              desc="Set targets and let the app calculate exactly how much to save daily to reach them on time."
            />
            <FeatureCard
              icon={<Activity />}
              title="Health Score"
              desc="A single metric for your financial stability, combining volatility, liquidity, and savings."
            />
            <FeatureCard
              icon={<PieChart />}
              title="Investment Sim"
              desc="Simulate potential returns for local RNIT investments before committing any funds."
            />
          </div>
        </div>
      </section>

      {/* CTA Section - Inverted to Dark for High Impact */}
      <section className="py-32 px-4 relative z-10">
        <div className="max-w-7xl mx-auto">
          <div className="relative bg-gray-900 border border-gray-800 p-12 md:p-24 text-center overflow-hidden group shadow-2xl">
            {/* Dynamic hover gradient background */}
            <div className="absolute inset-0 bg-gradient-to-r from-[var(--color-primary)]/20 to-[var(--color-secondary)]/20 opacity-0 group-hover:opacity-100 transition-opacity duration-700 pointer-events-none" />
            
            <div className="relative z-10">
              <h2 className="font-display text-4xl md:text-6xl font-black uppercase tracking-tight mb-6 text-white">
                Ready to take control?
              </h2>
              <p className="text-xl text-gray-400 mb-12 max-w-2xl mx-auto font-medium">
                Join the financial revolution. Download FinGuide today and start making your irregular income work for you.
              </p>
              
              <a
                href={APK_URL}
                className="inline-flex items-center justify-center gap-3 px-12 py-6 bg-[var(--color-primary)] text-white font-black uppercase tracking-widest hover:scale-105 hover:shadow-xl hover:shadow-[var(--color-primary)]/30 transition-all duration-300"
              >
                <Download className="w-6 h-6" />
                Download For Android
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-200 bg-gray-50 py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 grid md:grid-cols-4 gap-12">
          <div className="col-span-1 md:col-span-2">
            <span className="flex items-center gap-2 font-display font-black text-2xl uppercase tracking-tighter mb-6 text-black">
              <div className="w-3 h-3 bg-[var(--color-primary)]" />
              FinGuide
            </span>
            <p className="text-gray-600 max-w-sm leading-relaxed font-medium">
              AI-driven financial advisor for Rwandan youth. Built with Flutter,
              Python, and local context in mind.
            </p>
          </div>

          <div>
            <h4 className="font-bold uppercase tracking-widest text-sm mb-6 text-black">Project</h4>
            <ul className="space-y-4 text-gray-600 font-medium">
              <li>
                <a href={GITHUB_URL} className="hover:text-[var(--color-primary)] transition-colors flex items-center gap-2">
                  <ArrowRight size={14} /> Source Code
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-[var(--color-primary)] transition-colors flex items-center gap-2">
                  <ArrowRight size={14} /> Documentation
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h4 className="font-bold uppercase tracking-widest text-sm mb-6 text-black">Legal</h4>
            <ul className="space-y-4 text-gray-600 font-medium">
              <li>
                <a href="#" className="hover:text-[var(--color-primary)] transition-colors flex items-center gap-2">
                  <ArrowRight size={14} /> Privacy Policy
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-[var(--color-primary)] transition-colors flex items-center gap-2">
                  <ArrowRight size={14} /> Terms of Use
                </a>
              </li>
            </ul>
          </div>
        </div>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-16 pt-8 border-t border-gray-200 flex flex-col md:flex-row justify-between items-center text-gray-500 text-sm font-bold uppercase tracking-widest">
          <p>© {new Date().getFullYear()} FinGuide</p>
          <p className="mt-2 md:mt-0 text-[var(--color-primary)]">Open Source Academic Project</p>
        </div>
      </footer>
    </div>
  );
}

// Light Theme Cube-inspired Feature Card
function FeatureCard({
  icon,
  title,
  desc,
}: {
  icon: React.ReactNode;
  title: string;
  desc: string;
}) {
  return (
    <div className="group relative bg-white border border-gray-200 p-8 overflow-hidden transition-all duration-500 hover:-translate-y-2 hover:shadow-2xl hover:shadow-gray-200/50">
      {/* Subtle Background Tint on Hover */}
      <div className="absolute inset-0 bg-gradient-to-br from-[var(--color-primary)] to-[var(--color-secondary)] opacity-0 group-hover:opacity-[0.03] transition-opacity duration-500 pointer-events-none" />
      
      {/* Decorative top border reveal */}
      <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-[var(--color-primary)] to-[var(--color-secondary)] scale-x-0 group-hover:scale-x-100 transform origin-left transition-transform duration-500" />

      <div className="relative z-10">
        <div className="w-14 h-14 bg-gray-50 border border-gray-100 flex items-center justify-center mb-8 text-[var(--color-primary)] group-hover:scale-110 group-hover:bg-[var(--color-primary)] group-hover:text-white group-hover:border-transparent transition-all duration-500 shadow-sm">
          {icon}
        </div>
        <h3 className="font-display font-black text-2xl uppercase tracking-wide text-black mb-4 group-hover:text-[var(--color-primary)] transition-colors">
          {title}
        </h3>
        <p className="text-gray-600 leading-relaxed font-medium">
          {desc}
        </p>
      </div>
    </div>
  );
}