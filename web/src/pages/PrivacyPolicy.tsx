import { ArrowLeft } from "lucide-react";
import { Link } from "react-router-dom";

const sections = [
  {
    title: "1. Data Controller",
    content: `Alain Michael Muhirwa, who may be reached at a.muhirwa@alustudent.com, is the data controller for the FinGuide application. Article 26 of Rwanda's Law No. 058/2021 mandates this identification so that users are aware of who is in charge of their data.`,
  },
  {
    title: "2. Data We Collect",
    content: `FinGuide gathers and handles the following types of personal information:

(a) Registration data: phone number, full name, Ubudehe socioeconomic category, and frequency of income;
(b) Transaction data: structured records taken from MoMo SMS messages, including transaction amounts, dates, categories, and anonymized counterparty identifiers;
(c) Usage data: financial health score history, savings goal progress, and interaction records with nudges (viewed, acted upon, dismissed);
(d) Device data: device type and operating system version for technical support.

Contact lists, location information, biometric information, raw SMS message content, and any information from non-MoMo SMS communications are not collected by us.`,
  },
  {
    title: "3. Purpose of Data Processing",
    content: `Your data is processed for the following specific purposes:

(a) to use our BiLSTM machine learning model to create personalized cash-flow forecasts;
(b) to determine your Financial Health Score and safe-to-spend amounts;
(c) to provide context-aware financial nudges and recommendations;
(d) to monitor the progress of your savings goals and the performance of your investment portfolio; and
(e) to enhance the accuracy and relevance of the AI model through anonymized, aggregated analysis.

In accordance with Article 26 of Law No. 058/2021's legitimate purpose requirement, every processing purpose is linked to the fundamental function of offering financial advice.`,
  },
  {
    title: "4. Legal Basis for Processing",
    content: `We process your data based on two factors:

(a) your express consent, which is gained through account registration and the SMS consent flow; and
(b) the legitimate purpose of offering the financial advisory service you have requested.

In accordance with your rights under Article 28 of Law No. 058/2021, you may revoke consent at any time by requesting account deletion or by removing SMS access in your device's settings.`,
  },
  {
    title: "5. Data Security Measures",
    content: `The following organizational and technical safeguards are put in place to protect your data:

(a) all data transmission between the App and our servers is encrypted using TLS 1.3 (HTTPS);
(b) passwords are hashed using bcrypt through the passlib library and are never stored in plain text;
(c) all personally identifiable information (names, phone numbers) is hashed before being stored in our database;
(d) JSON Web Tokens (JWT) with HS256 signing is used to manage authentication;
(e) SMS messages are parsed locally on your device, leaving only structured transaction records;
(f) the backend infrastructure is containerized (Docker) and configured with access controls.

Article 37 of Law No. 058/2021, which mandates suitable security measures for processing personal data, is complied with by these measures.`,
  },
  {
    title: "6. Data Retention",
    content: `Your personal information is only kept for as long as is required to deliver the financial advising service. For the duration of your account, transaction data is kept on file to facilitate forecasting and historical analysis. Except in cases where retention is mandated by law, all personal information will be deleted from our servers within 30 days of your account being deleted.`,
  },
  {
    title: "7. Data Sharing and Third Parties",
    content: `Your personal information is not traded, sold, or rented by us. The following third-party services receive our data only for the reasons listed:

(a) Anthropic Claude API: personalized nudges and financial advisor responses are generated using anonymized financial context (no PII);
(b) Twilio: your phone number is shared for OTP verification during authentication;
(c) RNIT: publicly accessible investment tracking uses Net Asset Value data (no user data is shared with RNIT).

Except as required for the aforementioned API services, no personal data is sent outside of Rwanda; all transfers are encrypted.`,
  },
  {
    title: "8. Your Rights",
    content: `You have the following rights under Rwanda's Law No. 058/2021:

(a) access your personal data that we hold;
(b) request that inaccurate data be corrected;
(c) request that your data be deleted;
(d) withdraw consent for data processing; and
(e) object to automated decision-making.

Contact us at a.muhirwa@alustudent.com to exercise any of these rights. Within 30 days, we will reply.`,
  },
  {
    title: "9. Children's Data",
    content: `FinGuide is intended for users who are at least 16 years old. With parental or guardian permission, users between the ages of 16 and 17 may utilize the app. We do not intentionally gather information from minors younger than 16. We will quickly remove any information we learn we have obtained from a child under the age of sixteen without their consent.`,
  },
  {
    title: "10. Changes to This Policy",
    content: `This privacy statement may be updated from time to time. An in-app notification will be sent out for any significant updates. Acceptance of the revised policy is shown by continued usage of the app upon notification of changes.`,
  },
  {
    title: "11. Contact Information",
    content: `Please email Alain Michael Muhirwa at a.muhirwa@alustudent.com if you have any questions, issues, or grievances regarding our Privacy Policy or our data practices.`,
  },
];

export default function PrivacyPolicy() {
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
            Privacy Policy
          </h1>
          <p className="text-gray-500 font-medium">
            Governed by Rwanda's Law No. 058/2021 on Protection of Personal Data and Privacy.{" "}
            <span className="text-gray-400">Last updated: March 2025.</span>
          </p>
        </div>

        <div className="space-y-10">
          {sections.map((section) => (
            <section key={section.title} className="group">
              <div className="flex items-start gap-4 mb-3">
                <div className="w-1 h-full min-h-[24px] bg-[var(--color-primary)] rounded-full mt-1 shrink-0" />
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
            <Link to="/eula" className="hover:text-[var(--color-primary)] transition-colors">EULA</Link>
            <Link to="/" className="hover:text-[var(--color-primary)] transition-colors">Home</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
