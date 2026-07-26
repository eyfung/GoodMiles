import from services.goodmiles {
    api_neighbors, api_add_neighbor, api_delete_neighbor, api_stops, api_optimize, api_execute, api_trips,
    Neighbor, ServiceStop, Trip, Seeded
}
import from services.jobmatch {
    api_community_centers, api_jobs, api_suggest_category, api_create_job_seeker, api_find_best_jobs,
    CommunityCenter, Job, JobSeeker, JobMatchSeeded
}

cl import ".styles.global.css";
cl import from ".components.NeighborsView" { NeighborsView }
cl import from ".components.ServiceStopsView" { ServiceStopsView }
cl import from ".components.OptimizeView" { OptimizeView }
cl import from ".components.JobMatchView" { JobMatchView }
cl import from "@jac/runtime" { Router, Routes, Route, Navigate }
cl import from "react-router-dom" { NavLink, useLocation }

def:pub app() -> JsxElement {
    return <Router>
        <AppShell />
    </Router>;
}

def:pub AppShell() -> JsxElement {
    has loc: any = useLocation();

    def nav_cls(path: str) -> str {
        active = loc.pathname == path or (path != "/" and loc.pathname.startsWith(path));
        if active {
            return "flex items-center gap-3 px-3 py-2 rounded-md text-sm font-medium bg-primary text-primary-foreground transition-colors";
        }
        return "flex items-center gap-3 px-3 py-2 rounded-md text-sm font-medium text-muted-foreground hover:bg-accent hover:text-accent-foreground transition-colors";
    }

    return <div className="flex h-screen bg-background">
        <aside className="w-56 border-r border-border bg-card flex flex-col shrink-0">
            <div className="p-4 border-b border-border">
                <div className="flex items-center gap-2">
                    <div className="size-8 rounded-md bg-primary flex items-center justify-center">
                        <span className="text-primary-foreground text-sm font-bold">GM</span>
                    </div>
                    <div>
                        <p className="text-sm font-semibold leading-none">GoodMiles</p>
                        <p className="text-xs text-muted-foreground mt-0.5">Mobility for Good</p>
                    </div>
                </div>
            </div>
            <nav className="flex flex-col gap-1 p-3 flex-1">
                <NavLink to="/neighbors" className={lambda (s: any) { return nav_cls("/neighbors"); }}>
                    <span className="text-base">People</span>
                    Neighbors
                </NavLink>
                <NavLink to="/stops" className={lambda (s: any) { return nav_cls("/stops"); }}>
                    <span className="text-base">Map</span>
                    Service Stops
                </NavLink>
                <NavLink to="/optimize" className={lambda (s: any) { return nav_cls("/optimize"); }}>
                    <span className="text-base">Route</span>
                    Optimize
                </NavLink>
                <NavLink to="/jobmatch" className={lambda (s: any) { return nav_cls("/jobmatch"); }}>
                    <span className="text-base">Match</span>
                    Job Match
                </NavLink>
            </nav>
            <div className="p-3 border-t border-border">
                <p className="text-xs text-muted-foreground text-center">JacHacks SF 2026</p>
            </div>
        </aside>
        <main className="flex-1 overflow-auto">
            <Routes>
                <Route path="/" element={<Navigate to="/neighbors" replace={True} />} />
                <Route path="/neighbors" element={<NeighborsView />} />
                <Route path="/stops" element={<ServiceStopsView />} />
                <Route path="/optimize" element={<OptimizeView />} />
                <Route path="/jobmatch" element={<JobMatchView />} />
            </Routes>
        </main>
    </div>;
}
