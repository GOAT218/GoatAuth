import Link from "next/link";
import {
  KeyRound,
  Fingerprint,
  CalendarClock,
  Users,
  ShieldBan,
  Code2,
  ArrowRight,
  Check,
} from "lucide-react";
import { Nav } from "@/components/marketing/Nav";
import { Footer } from "@/components/marketing/Footer";
import { Button } from "@/components/ui/Button";
import { Card, CardBody } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { CodeBlock } from "@/components/ui/CodeBlock";

const demoCode = `import requests

resp = requests.post("https://goatauth.dev/api/v1/login", json={
    "app_id": "app_9f3c...",
    "secret": "sk_live_...",
    "username": "jane_doe",
    "password": "hunter2",
    "hwid": "A1B2-C3D4-E5F6",
})

data = resp.json()
if data["success"]:
    print("Welcome,", data["user"]["username"])
else:
    print("Auth failed:", data["error"])`;

const demoHighlights = [
  {
    title: "HWID locking",
    description:
      "Bind each user to a single machine fingerprint and block sharing automatically.",
  },
  {
    title: "Subscription expiry",
    description:
      "Time-limited or lifetime access, enforced on every request with zero extra code.",
  },
  {
    title: "Instant key generation",
    description:
      "Mint license keys in bulk with custom formats, levels, and usage limits.",
  },
];

const features = [
  {
    icon: KeyRound,
    title: "License key management",
    description:
      "Generate, format, and revoke keys in bulk. Set duration, level, and max uses per key.",
  },
  {
    icon: Fingerprint,
    title: "HWID locking",
    description:
      "Tie licenses to hardware fingerprints so credentials can't be shared across machines.",
  },
  {
    icon: CalendarClock,
    title: "Subscriptions & expiry",
    description:
      "Sell recurring or lifetime access. Extend, upgrade, or expire users on your terms.",
  },
  {
    icon: Users,
    title: "User & session control",
    description:
      "Ban, unban, and reset users. Watch active sessions live and kill them instantly.",
  },
  {
    icon: ShieldBan,
    title: "Blacklist & rate limiting",
    description:
      "Block abusive IPs, HWIDs, and usernames. Built-in rate limits stop brute-force attempts.",
  },
  {
    icon: Code2,
    title: "Simple REST API & SDKs",
    description:
      "A clean, predictable JSON API you can call from any language in just a few lines.",
  },
];

const steps = [
  {
    title: "Create an app",
    description:
      "Register your software in the dashboard and get an app ID and secret to authenticate requests.",
  },
  {
    title: "Generate license keys",
    description:
      "Mint keys in bulk with the durations, levels, and formats that fit how you sell.",
  },
  {
    title: "Authenticate from your software",
    description:
      "Drop a few lines of code into your client and let GoatAuth verify every user on launch.",
  },
];

const plans = [
  {
    name: "Starter",
    price: "$0",
    period: "forever",
    description: "Everything you need to ship your first protected app.",
    features: [
      "1 application",
      "Up to 100 users",
      "License key generation",
      "HWID locking",
      "Community support",
    ],
    cta: "Start for free",
    highlight: false,
  },
  {
    name: "Pro",
    price: "$19",
    period: "/mo",
    description: "For growing products that need more scale and control.",
    features: [
      "10 applications",
      "Up to 10,000 users",
      "Subscriptions & expiry",
      "Blacklist & rate limiting",
      "Priority email support",
    ],
    cta: "Start Pro trial",
    highlight: true,
  },
  {
    name: "Business",
    price: "$49",
    period: "/mo",
    description: "For teams running mission-critical licensing at scale.",
    features: [
      "Unlimited applications",
      "Unlimited users",
      "Advanced session control",
      "Custom key formats",
      "Dedicated support",
    ],
    cta: "Start Business trial",
    highlight: false,
  },
];

export default function HomePage() {
  return (
    <div className="flex min-h-screen flex-col">
      <Nav />

      <main className="flex-1">
        {/* HERO */}
        <section className="relative overflow-hidden">
          <div className="grid-bg pointer-events-none absolute inset-0 [mask-image:radial-gradient(60rem_40rem_at_50%_-10%,black,transparent)]" />
          <div className="relative mx-auto max-w-6xl px-4 py-24 sm:px-6 sm:py-32">
            <div className="mx-auto max-w-3xl text-center">
              <Badge tone="brand" className="mb-6">
                Auth &amp; licensing, built for developers
              </Badge>
              <h1 className="text-4xl font-bold leading-tight tracking-tight sm:text-5xl md:text-6xl">
                <span className="text-gradient">
                  Authentication &amp; licensing for the software you build.
                </span>
              </h1>
              <p className="mx-auto mt-6 max-w-2xl text-lg text-white/60">
                Protect your apps, sell license keys, and manage users &amp; sessions — all through
                a simple REST API. Ship licensing in an afternoon, not a sprint.
              </p>
              <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
                <Link href="/register">
                  <Button size="lg" className="w-full sm:w-auto">
                    Start for free
                  </Button>
                </Link>
                <Link href="/docs">
                  <Button size="lg" variant="outline" className="w-full sm:w-auto">
                    Read the docs
                  </Button>
                </Link>
              </div>
              <p className="mt-5 text-sm text-white/40">
                No credit card. Built for indie devs and teams.
              </p>
            </div>
          </div>
        </section>

        {/* CODE DEMO */}
        <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6">
          <div className="grid items-center gap-8 md:grid-cols-2">
            <div>
              <h2 className="text-2xl font-semibold text-white sm:text-3xl">
                Authenticate in a few lines
              </h2>
              <p className="mt-3 text-white/60">
                Call the API from any language. Send the credentials, check{" "}
                <code className="rounded bg-bg-elevated px-1.5 py-0.5 font-mono text-[13px] text-brand-300">
                  success
                </code>
                , and you&apos;re done.
              </p>
              <ul className="mt-8 space-y-5">
                {demoHighlights.map((item) => (
                  <li key={item.title} className="flex gap-3">
                    <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full border border-brand-500/30 bg-brand-500/15 text-brand-300">
                      <Check className="h-3.5 w-3.5" />
                    </span>
                    <div>
                      <p className="font-medium text-white">{item.title}</p>
                      <p className="mt-0.5 text-sm text-white/55">{item.description}</p>
                    </div>
                  </li>
                ))}
              </ul>
            </div>
            <CodeBlock language="python" code={demoCode} />
          </div>
        </section>

        {/* FEATURES */}
        <section id="features" className="mx-auto max-w-6xl px-4 py-16 sm:px-6">
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-2xl font-semibold text-white sm:text-3xl">
              Everything you need to protect and sell software
            </h2>
            <p className="mt-3 text-white/60">
              A complete licensing toolkit — from key generation to live session control.
            </p>
          </div>
          <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {features.map((feature) => {
              const Icon = feature.icon;
              return (
                <Card key={feature.title} className="transition-colors hover:border-brand-500/40">
                  <CardBody>
                    <span className="inline-flex h-11 w-11 items-center justify-center rounded-xl border border-brand-500/25 bg-brand-500/10 text-brand-300">
                      <Icon className="h-5 w-5" />
                    </span>
                    <h3 className="mt-4 text-base font-semibold text-white">{feature.title}</h3>
                    <p className="mt-2 text-sm text-white/55">{feature.description}</p>
                  </CardBody>
                </Card>
              );
            })}
          </div>
        </section>

        {/* HOW IT WORKS */}
        <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6">
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-2xl font-semibold text-white sm:text-3xl">How it works</h2>
            <p className="mt-3 text-white/60">
              From zero to a fully licensed application in three steps.
            </p>
          </div>
          <div className="mt-12 grid gap-4 md:grid-cols-3">
            {steps.map((step, i) => (
              <Card key={step.title}>
                <CardBody>
                  <div className="flex items-center gap-3">
                    <span className="flex h-10 w-10 items-center justify-center rounded-full border border-brand-500/30 bg-brand-500/15 font-mono text-sm font-semibold text-brand-300">
                      {i + 1}
                    </span>
                    <h3 className="text-base font-semibold text-white">{step.title}</h3>
                  </div>
                  <p className="mt-4 text-sm text-white/55">{step.description}</p>
                </CardBody>
              </Card>
            ))}
          </div>
        </section>

        {/* PRICING */}
        <section id="pricing" className="mx-auto max-w-6xl px-4 py-16 sm:px-6">
          <div className="mx-auto max-w-2xl text-center">
            <h2 className="text-2xl font-semibold text-white sm:text-3xl">
              Simple, predictable pricing
            </h2>
            <p className="mt-3 text-white/60">
              Start free and upgrade as you grow. No hidden fees.
            </p>
          </div>
          <div className="mt-12 grid items-start gap-4 lg:grid-cols-3">
            {plans.map((plan) => (
              <Card
                key={plan.name}
                className={
                  plan.highlight
                    ? "relative border-brand-500/50 shadow-glow lg:-translate-y-2"
                    : "relative"
                }
              >
                <CardBody>
                  <div className="flex items-center justify-between">
                    <h3 className="text-lg font-semibold text-white">{plan.name}</h3>
                    {plan.highlight && <Badge tone="brand">Popular</Badge>}
                  </div>
                  <p className="mt-2 text-sm text-white/55">{plan.description}</p>
                  <div className="mt-6 flex items-baseline gap-1">
                    <span className="text-4xl font-bold text-white">{plan.price}</span>
                    <span className="text-sm text-white/45">{plan.period}</span>
                  </div>
                  <Link href="/register" className="mt-6 block">
                    <Button
                      variant={plan.highlight ? "primary" : "outline"}
                      className="w-full"
                    >
                      {plan.cta}
                    </Button>
                  </Link>
                  <ul className="mt-6 space-y-3 border-t border-border pt-6">
                    {plan.features.map((feat) => (
                      <li key={feat} className="flex items-start gap-2 text-sm text-white/70">
                        <Check className="mt-0.5 h-4 w-4 shrink-0 text-brand-400" />
                        <span>{feat}</span>
                      </li>
                    ))}
                  </ul>
                </CardBody>
              </Card>
            ))}
          </div>
        </section>

        {/* FINAL CTA */}
        <section className="mx-auto max-w-6xl px-4 py-16 sm:px-6">
          <div className="relative overflow-hidden rounded-2xl border border-border bg-bg-card px-6 py-14 text-center shadow-card sm:px-12">
            <div className="grid-bg pointer-events-none absolute inset-0 [mask-image:radial-gradient(40rem_20rem_at_50%_50%,black,transparent)]" />
            <div className="relative">
              <h2 className="mx-auto max-w-2xl text-3xl font-bold tracking-tight text-white sm:text-4xl">
                Ship licensing for your software today.
              </h2>
              <p className="mx-auto mt-4 max-w-xl text-white/60">
                Create your first app, generate keys, and authenticate users in minutes. Free to
                start, no credit card required.
              </p>
              <div className="mt-8 flex justify-center">
                <Link href="/register">
                  <Button size="lg">
                    Start for free
                    <ArrowRight className="h-4 w-4" />
                  </Button>
                </Link>
              </div>
            </div>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  );
}
