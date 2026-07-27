cl import from "react-router-dom" { NavLink }

def:pub LandingView() -> JsxElement {
    return <div className="min-h-full overflow-hidden bg-[#f7f7f2] text-[#17362a]">
        <section className="relative px-6 py-8 lg:px-12 lg:py-12">
            <div className="pointer-events-none absolute -right-24 -top-28 size-96 rounded-full bg-[#c9f36b]/35 blur-3xl" />
            <div className="pointer-events-none absolute -left-24 top-80 size-72 rounded-full bg-[#9edbc0]/30 blur-3xl" />

            <nav className="relative mx-auto flex max-w-7xl items-center justify-between">
                <div className="flex items-center gap-3">
                    <div className="flex size-10 items-center justify-center rounded-2xl bg-[#17362a] text-sm font-bold text-white">GM</div>
                    <div>
                        <p className="text-sm font-bold leading-none">GoodMiles</p>
                        <p className="mt-1 text-[11px] text-[#547064]">Mobility for good</p>
                    </div>
                </div>
                <NavLink
                    to="/pathway"
                    className="rounded-full border border-[#17362a]/15 bg-white/80 px-5 py-2.5 text-sm font-semibold shadow-sm backdrop-blur transition-transform hover:-translate-y-0.5"
                >
                    Open dashboard
                </NavLink>
            </nav>

            <div className="relative mx-auto grid max-w-7xl grid-cols-1 items-center gap-14 py-20 lg:grid-cols-[1.05fr_0.95fr] lg:py-28">
                <div>
                    <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-[#17362a]/10 bg-white/75 px-3 py-1.5 text-xs font-semibold shadow-sm backdrop-blur">
                        <span className="size-2 animate-pulse rounded-full bg-[#47a36d]" />
                        Private, consent-led support in motion
                    </div>
                    <h1 className="max-w-3xl text-5xl font-semibold leading-[0.98] tracking-[-0.055em] sm:text-6xl lg:text-7xl">
                        A safe ride can become a pathway forward.
                    </h1>
                    <p className="mt-7 max-w-2xl text-lg leading-relaxed text-[#547064]">
                        GoodMiles turns private conversations with an in-car avatar into coordinated access
                        to food, health, counseling, coaching, and employment support.
                    </p>
                    <div className="mt-9 flex flex-wrap items-center gap-4">
                        <NavLink
                            to="/pathway"
                            className="group inline-flex items-center gap-3 rounded-full bg-[#17362a] px-7 py-4 text-base font-semibold text-white shadow-[0_18px_45px_rgba(23,54,42,0.22)] transition-all hover:-translate-y-1 hover:bg-[#214c3b]"
                        >
                            Start here
                            <span className="transition-transform group-hover:translate-x-1">→</span>
                        </NavLink>
                        <p className="text-sm text-[#6d8279]">From conversation to a coordinated ride in one flow.</p>
                    </div>
                </div>

                <div className="gm-motion-stage relative mx-auto h-[470px] w-full max-w-[560px]">
                    <div className="absolute inset-8 rounded-[42px] border border-white/70 bg-white/55 shadow-[0_30px_90px_rgba(23,54,42,0.14)] backdrop-blur-xl" />
                    <div className="gm-float-card gm-float-one absolute left-0 top-12 w-64 rounded-3xl border border-white bg-white/90 p-5 shadow-xl">
                        <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-[#799084]">Private consultation</p>
                        <p className="mt-3 text-sm font-semibold leading-snug">“I’m ready to get support, but I need a calm place to start.”</p>
                        <div className="mt-4 flex gap-2">
                            <span className="rounded-full bg-[#e9f6df] px-2.5 py-1 text-[10px] font-bold text-[#3e704f]">Consent-led</span>
                            <span className="rounded-full bg-[#eef0e9] px-2.5 py-1 text-[10px] font-bold text-[#62746b]">Private</span>
                        </div>
                    </div>
                    <div className="gm-float-card gm-float-two absolute right-0 top-48 w-64 rounded-3xl bg-[#17362a] p-5 text-white shadow-2xl">
                        <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-[#add0bd]">Agent interpretation</p>
                        <div className="mt-4 space-y-3">
                            <div className="flex items-center justify-between text-xs"><span className="text-[#bcd1c7]">Need</span><span className="font-semibold">Counseling</span></div>
                            <div className="flex items-center justify-between text-xs"><span className="text-[#bcd1c7]">Urgency</span><span className="font-semibold text-[#d5f27c]">High</span></div>
                            <div className="flex items-center justify-between text-xs"><span className="text-[#bcd1c7]">Wellbeing</span><span className="font-semibold">Overwhelmed</span></div>
                        </div>
                    </div>
                    <div className="gm-float-card gm-float-three absolute bottom-5 left-12 w-72 rounded-3xl border border-[#d5e4db] bg-[#edf7f0] p-5 shadow-xl">
                        <div className="flex items-center justify-between">
                            <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-[#668071]">Safe pathway allocated</p>
                            <span className="size-2 rounded-full bg-[#47a36d]" />
                        </div>
                        <div className="relative mt-5 h-12">
                            <div className="absolute left-3 right-3 top-1/2 h-1 -translate-y-1/2 rounded-full bg-[#c8d9ce]" />
                            <div className="absolute left-3 top-1/2 size-4 -translate-y-1/2 rounded-full border-4 border-white bg-[#17362a] shadow" />
                            <div className="absolute right-3 top-1/2 size-4 -translate-y-1/2 rounded-full border-4 border-white bg-[#8fcf66] shadow" />
                            <div className="gm-route-dot absolute left-3 top-1/2 size-3 -translate-y-1/2 rounded-full bg-[#f4b942] shadow-[0_0_0_6px_rgba(244,185,66,0.18)]" />
                        </div>
                        <div className="flex justify-between text-[10px] font-semibold text-[#60776b]"><span>Pickup</span><span>Wellness Center</span></div>
                    </div>
                </div>
            </div>
        </section>

        <section className="border-y border-[#17362a]/10 bg-white/70 px-6 py-8 backdrop-blur lg:px-12">
            <div className="mx-auto grid max-w-7xl grid-cols-2 gap-6 text-center sm:grid-cols-5">
                {for service in ["Food access", "Healthcare", "Counseling", "Job coaching", "Employment"] {
                    <p key={service} className="text-sm font-semibold text-[#547064]">{service}</p>
                }}
            </div>
        </section>

        <section className="px-6 py-20 lg:px-12 lg:py-28">
            <div className="mx-auto max-w-7xl">
                <div className="max-w-2xl">
                    <p className="text-xs font-bold uppercase tracking-[0.2em] text-[#4f8c66]">How Pathway works</p>
                    <h2 className="mt-4 text-4xl font-semibold tracking-[-0.04em] sm:text-5xl">Listen privately. Interpret carefully. Move with purpose.</h2>
                </div>
                <div className="mt-14 grid grid-cols-1 gap-5 md:grid-cols-3">
                    {for item in [
                        {"number": "01", "title": "A private conversation", "copy": "The in-car avatar creates a calm space where participants choose what they are comfortable sharing."},
                        {"number": "02", "title": "A consent-scoped interpretation", "copy": "The Pathway agent separates raw words from extracted needs, wellbeing signals, timing, and safety considerations."},
                        {"number": "03", "title": "A coordinated next step", "copy": "Live services, route fit, and fleet capacity become one clear allocation—without another intake form."}
                    ] {
                        <article key={item["number"] as str} className="rounded-[28px] border border-[#17362a]/10 bg-white p-7 shadow-[0_16px_45px_rgba(23,54,42,0.06)]">
                            <p className="text-xs font-bold text-[#84a091]">{item["number"] as str}</p>
                            <h3 className="mt-8 text-xl font-semibold">{item["title"] as str}</h3>
                            <p className="mt-3 text-sm leading-relaxed text-[#687d72]">{item["copy"] as str}</p>
                        </article>
                    }}
                </div>
            </div>
        </section>

        <section className="px-6 pb-20 lg:px-12 lg:pb-28">
            <div className="mx-auto flex max-w-7xl flex-col items-start justify-between gap-8 rounded-[36px] bg-[#d8f083] p-8 sm:p-12 lg:flex-row lg:items-center">
                <div>
                    <p className="text-xs font-bold uppercase tracking-[0.2em] text-[#49633e]">One conversation. One pathway.</p>
                    <h2 className="mt-3 max-w-2xl text-3xl font-semibold tracking-[-0.035em] sm:text-4xl">See how private consultation becomes coordinated care.</h2>
                </div>
                <NavLink to="/pathway" className="shrink-0 rounded-full bg-[#17362a] px-7 py-4 font-semibold text-white shadow-xl transition-transform hover:-translate-y-1">
                    Start here →
                </NavLink>
            </div>
        </section>
    </div>;
}
