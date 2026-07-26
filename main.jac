import from services.goodmiles {
    api_neighbors, api_stops, api_optimize, api_execute, api_trips,
    Neighbor, ServiceStop, Trip, Seeded
}
import from services.pathway {
    api_pickup_points, api_destinations, api_fleet_state, api_request_ride, api_reset_fleet,
    AV, RideRequest, FleetSeeded
}

cl import ".styles.global.css";
cl import "leaflet/dist/leaflet.css";
cl import from ".components.NeighborsView" { NeighborsView }
cl import from ".components.ServiceStopsView" { ServiceStopsView }
cl import from ".components.OptimizeView" { OptimizeView }
cl import from ".components.PathwayView" { PathwayView }
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
            return "flex items-center gap-2 px-3 py-2 rounded-[10px] text-[13px] font-medium bg-[#121212] text-[#fbfaf9] transition-colors";
        }
        return "flex items-center gap-2 px-3 py-2 rounded-[10px] text-[13px] font-medium text-[#474645] hover:bg-[#f2f0ed] hover:text-[#343433] transition-colors";
    }

    return <div className="flex h-screen" style={{"backgroundColor": "#fbfaf9"}}>
        <aside className="w-52 flex flex-col shrink-0" style={{"backgroundColor": "#fbfaf9", "borderRight": "1px solid #f2f0ed"}}>
            <div className="px-4 py-5" style={{"borderBottom": "1px solid #f2f0ed"}}>
                <div className="flex items-center gap-2.5">
                    <div className="size-8 rounded-[10px] flex items-center justify-center font-semibold text-[13px]" style={{"backgroundColor": "#121212", "color": "#fbfaf9"}}>
                        GM
                    </div>
                    <div>
                        <p className="text-[14px] font-semibold leading-none" style={{"color": "#343433"}}>GoodMiles</p>
                        <p className="text-[12px] mt-0.5" style={{"color": "#7e7e7d"}}>Mobility for Good</p>
                    </div>
                </div>
            </div>
            <nav className="flex flex-col gap-0.5 p-3 flex-1">
                <NavLink to="/neighbors" className={lambda (s: any) { return nav_cls("/neighbors"); }}>
                    Neighbors
                </NavLink>
                <NavLink to="/stops" className={lambda (s: any) { return nav_cls("/stops"); }}>
                    Service Stops
                </NavLink>
                <NavLink to="/optimize" className={lambda (s: any) { return nav_cls("/optimize"); }}>
                    Optimize
                </NavLink>
                <NavLink to="/pathway" className={lambda (s: any) { return nav_cls("/pathway"); }}>
                    Pathway
                </NavLink>
            </nav>
            <div className="px-4 py-3" style={{"borderTop": "1px solid #f2f0ed"}}>
                <p className="text-[11px] text-center" style={{"color": "#7e7e7d"}}>JacHacks SF 2026</p>
            </div>
        </aside>
        <main className="flex-1 overflow-auto" style={{"backgroundColor": "#fbfaf9"}}>
            <Routes>
                <Route path="/" element={<Navigate to="/neighbors" replace={True} />} />
                <Route path="/neighbors" element={<NeighborsView />} />
                <Route path="/stops" element={<ServiceStopsView />} />
                <Route path="/optimize" element={<OptimizeView />} />
                <Route path="/pathway" element={<PathwayView />} />
            </Routes>
        </main>
    </div>;
}
