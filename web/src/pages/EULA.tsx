import { ArrowLeft } from "lucide-react";
import { Link } from "react-router-dom";

const sections = [
  {
    title: "1. Acceptance of Terms",
    content: `You accept the terms of this End-User Licence Agreement by downloading, installing, or using the FinGuide mobile application ("the App"). You are not permitted to use the app if you disagree with these terms. Because it establishes the notion of informed consent, users must affirmatively agree to the conditions before accessing the system, ensuring they are aware of their rights and obligations.`,
  },
  {
    title: "2. Licence Grant",
    content: `You are granted a limited, non-exclusive, non-transferable, revocable license by FinGuide to use the app on a personal Android device for non-commercial, personal financial management. The App may not be copied, altered, distributed, reverse-engineered, or used as the basis for derivative works. This provision defines the extent of acceptable use while safeguarding the system's intellectual property.`,
  },
  {
    title: "3. Nature of Financial Guidance",
    content: `FinGuide offers forecasts, suggestions, and financial insights produced by AI (collectively, "Guidance"). This advice is not intended to be professional financial advice, investment advice, or a suggestion to purchase or sell any financial instrument; rather, it is informational and educational in nature. You understand that:

(a) the App does not carry out any financial transactions on your behalf;
(b) AI-generated forecasts are based on past trends and may not properly reflect future financial results; and
(c) any financial decisions are made at your own discretion and risk.

This provision guarantees that users have complete control over their financial decisions and discourages excessive dependence on algorithmic recommendations.`,
  },
  {
    title: "4. SMS Data Access and Processing",
    content: `In order to recognize and analyze Mobile Money transaction notifications, the app asks for permission to read SMS messages on your device. By giving us this permission, you agree that:

(a) SMS messages are processed locally on your device;
(b) only structured transaction data (amounts, dates, and categories) is sent to our servers;
(c) raw SMS content, including message bodies and sender information, is never stored on or sent to our servers; and
(d) you can cancel SMS access at any time using the settings on your device or the app.

This section guarantees openness regarding the data that leaves the device and deals with the system's most sensitive data processing component.`,
  },
  {
    title: "5. AI-Generated Content Disclosure",
    content: `FinGuide generates suggestions, conversational financial guidance, and personalized financial nudges using artificial intelligence, including the Anthropic Claude API. Within the app, any information produced by AI is clearly marked as such. You understand that information produced by AI could be inaccurate and should not be the only factor used to make financial decisions. This provision guarantees transparency on the use of AI.`,
  },
  {
    title: "6. User Responsibilities",
    content: `You commit to:

(a) giving truthful information when registering;
(b) keeping your account credentials private;
(c) using the app solely for legitimate purposes; and
(d) not trying to get around security measures or access the data of other users.

Mutual accountability for system security is established by this provision.`,
  },
  {
    title: "7. Limitation of Liability",
    content: `FinGuide and its developers disclaim all liability for any direct, indirect, incidental, special, or consequential damages resulting from:

(a) your use of or incapacity to use the App;
(b) any financial decisions made based on the App's guidance;
(c) any errors in AI-generated forecasts or recommendations; and
(d) any unauthorized access to your account due to your failure to protect your credentials.

This provision ensures accountability within reasonable constraints while limiting developer liability.`,
  },
  {
    title: "8. Termination",
    content: `By removing the app and requesting account deletion via the profile settings, you may end this agreement at any time. In accordance with data retention requirements under relevant law, your account data will be removed from our servers within 30 days of termination. This article guarantees the right to data erasure in accordance with data protection principles.`,
  },
  {
    title: "9. Governing Law",
    content: `The Republic of Rwanda's laws, including but not limited to Law No. 058/2021 concerning the Protection of Personal Data and Privacy, govern this agreement. Any disagreements resulting from this agreement will be settled by Rwanda's appropriate courts.`,
  },
];

export default function EULA() {
  return (
    <div className="min-h-screen bg-white text-gray-900 font-sans">
      {/* Header */}
      <header className="border-b border-gray-200 bg-white/90 backdrop-blur-xl sticky top-0 z-50 py-4 shadow-sm">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2 text-gray-500 hover:text-black transition-colors text-sm font-bold uppercase tracking-widest group">
            <ArrowLeft size={16} className="group-hover:-translate-x-1 transition-transform" />
            Back
          </Link>
          <span className="flex items-center gap-2 font-display font-black tracking-tight text-xl uppercase text-black">
            <div className="w-2.5 h-2.5 bg-gradient-to-tr from-[var(--color-primary)] to-[var(--color-secondary)]" />
            FinGuide
          </span>
        </div>
      </header>

      {/* Content */}
      <main className="max-w-4xl mx-auto px-4 sm:px-6 py-16">
        <div className="mb-12">
          <div className="flex items-center gap-4 mb-4">
            <div className="h-px w-12 bg-[var(--color-primary)]" />
            <span className="text-[var(--color-primary)] font-bold tracking-widest uppercase text-sm">Legal</span>
          </div>
          <h1 className="font-display text-4xl md:text-5xl font-black uppercase tracking-tight text-black mb-4">
            End-User Licence Agreement
          </h1>
          <p className="text-gray-500 font-medium">
            Please read this agreement carefully before using the FinGuide application.{" "}
            <span className="text-gray-400">Last updated: March 2025.</span>
          </p>
        </div>

        <div className="space-y-10">
          {sections.map((section) => (
            <section key={section.title} className="group">
              <div className="flex items-start gap-4 mb-3">
                <div className="w-1 h-full min-h-[24px] bg-[var(--color-secondary)] rounded-full mt-1 shrink-0" />
                <h2 className="font-display font-black text-xl uppercase tracking-wide text-black">
                  {section.title}
                </h2>
              </div>
              <p className="text-gray-600 leading-relaxed font-medium whitespace-pre-line pl-5">
                {section.content}
              </p>
            </section>
          ))}
        </div>

        <div className="mt-16 pt-8 border-t border-gray-200">
          <p className="text-gray-500 text-sm font-medium">
            Questions? Contact{" "}
            <a href="mailto:a.muhirwa@alustudent.com" className="text-[var(--color-primary)] hover:underline">
              a.muhirwa@alustudent.com
            </a>
          </p>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-gray-200 bg-gray-50 py-8 mt-16">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 flex flex-col md:flex-row justify-between items-center text-gray-500 text-sm font-bold uppercase tracking-widest gap-4">
          <p>© {new Date().getFullYear()} FinGuide</p>
          <div className="flex gap-6">
            <Link to="/privacy" className="hover:text-[var(--color-primary)] transition-colors">Privacy Policy</Link>
            <Link to="/" className="hover:text-[var(--color-primary)] transition-colors">Home</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
