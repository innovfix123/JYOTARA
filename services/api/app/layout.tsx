import type { Metadata } from 'next';
import { DM_Sans, Manrope } from 'next/font/google';
import './globals.css';

const bodyFont = DM_Sans({ variable: '--font-body', subsets: ['latin'] });
const headingFont = Manrope({ variable: '--font-heading-face', subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'Jyotara — Your Personal Vedic Astrology',
  description: 'உங்கள் ஜாதகம். உங்கள் நேரம். தமிழில் தனிப்பட்ட பாரம்பரிய வேத ஜோதிட வழிகாட்டல்.',
  openGraph: {
    title: 'Jyotara — Your Personal Vedic Astrology',
    description: 'உங்கள் ஜாதகம். உங்கள் நேரம். தமிழில் பாரம்பரிய வேத ஜோதிட வழிகாட்டல்.',
    type: 'website',
  },
  twitter: {
    card: 'summary',
    title: 'Jyotara — Your Personal Vedic Astrology',
    description: 'உங்கள் ஜாதகம். உங்கள் நேரம்.',
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ta" className="dark">
      <body className={`${bodyFont.variable} ${headingFont.variable} antialiased`}>{children}</body>
    </html>
  );
}
