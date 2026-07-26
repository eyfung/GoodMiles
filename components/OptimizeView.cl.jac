import from ".ui.select" { Select, SelectTrigger, SelectContent, SelectGroup, SelectItem, SelectValue }
import from ".ui.skeleton" { Skeleton }
import from ".ui.spinner" { Spinner }
sv import from "..services.goodmiles" { api_neighbors, api_optimize, api_execute }

def:pub OptimizeView() -> JsxElement {
    has neighbors: list[dict] = [];
    has selected_neighbor: str = "";
    has route: dict = {};
    has loading_neighbors: bool = True;
    has optimizing: bool = False;
    has executing: str = "";
    has pending_stop: str = "";
    has exec_result: str = "";
    has exec_error: str = "";
    has error: str = "";

    async can with entry {
        try {
            data: any = await api_neighbors();
            neighbors = data as list[dict];
        } except Exception as e {
            error = str(e);
        }
        loading_neighbors = False;
    }

    async def handle_optimize() -> None {
        if selected_neighbor == "" { return; }
        optimizing = True;
        exec_result = "";
        exec_error = "";
        try {
            data: any = await api_optimize(neighbor_name=selected_neighbor);
            route = data as dict;
        } except Exception as e {
            exec_error = str(e);
        }
        optimizing = False;
    }

    async def handle_execute(stop_name: str, feeling: str) -> None {
        pending_stop = "";
        executing = stop_name;
        exec_result = "";
        exec_error = "";
        try {
            data: any = await api_execute(selected_neighbor, stop_name, feeling);
            res = data as dict;
            if "error" in res {
                exec_error = res["error"] as str;
            } else {
                new_bal = res["new_balance"] as int;
                cost_val = res["cost"] as int;
                bonus_val = res["bonus"] as int;
                feeling_val = res["feeling"] as str;
                exec_result = "Trip to " + stop_name + " complete. Feeling: " + feeling_val + ". Cost: " + str(cost_val) + " pts, Bonus: +" + str(bonus_val) + " pts. New balance: " + str(new_bal) + " pts.";
                ndata: any = await api_neighbors();
                neighbors = ndata as list[dict];
                rdata: any = await api_optimize(neighbor_name=selected_neighbor);
                route = rdata as dict;
            }
        } except Exception as e {
            exec_error = str(e);
        }
        executing = "";
    }

    if loading_neighbors {
        return <div className="p-8">
            <div className="mb-8">
                <h1 className="text-[23px] font-semibold tracking-[-0.44px] leading-[25px]" style={{"color": "#343433"}}>Optimize Route</h1>
                <p className="text-[15px] mt-1" style={{"color": "#7e7e7d"}}>Find the best route for a neighbor</p>
            </div>
            <Skeleton className="h-10 w-64" />
        </div>;
    }

    has_route = "neighbor" in route;
    plan: list[dict] = [];
    if has_route {
        plan_raw: any = route["route_plan"];
        plan = plan_raw as list[dict];
    }

    return <div className="p-8 flex flex-col gap-6">
        <div>
            <h1 className="text-[23px] font-semibold tracking-[-0.44px] leading-[25px]" style={{"color": "#343433"}}>Optimize Route</h1>
            <p className="text-[15px] mt-1" style={{"color": "#7e7e7d"}}>Find the best route for a neighbor and execute trips</p>
        </div>

        <div className="rounded-[10px] p-6" style={{"backgroundColor": "#ffffff", "boxShadow": "inset 0 0 0 1px #f2f0ed"}}>
            <p className="text-[15px] font-semibold mb-1" style={{"color": "#343433"}}>Select Neighbor</p>
            <p className="text-[13px] mb-4" style={{"color": "#7e7e7d"}}>Choose a neighbor to optimize their mobility route</p>
            <div className="flex flex-wrap gap-3 items-center">
                <div className="w-64">
                    <Select onValueChange={lambda (v: str) { selected_neighbor = v; route = {}; exec_result = ""; exec_error = ""; }}>
                        <SelectTrigger className="rounded-[9999px] text-[13px]" style={{"backgroundColor": "#f6f4ef", "border": "none", "color": "#343433"}}>
                            <SelectValue placeholder="Select a neighbor..." />
                        </SelectTrigger>
                        <SelectContent>
                            <SelectGroup>
                                {for n in neighbors {
                                    n_name = n["name"] as str;
                                    n_bal = n["points_balance"] as int;
                                    n_zone = n["home_zone"] as str;
                                    <SelectItem key={n_name} value={n_name}>
                                        {n_name + " — " + str(n_bal) + " pts (" + n_zone + ")"}
                                    </SelectItem>
                                }}
                            </SelectGroup>
                        </SelectContent>
                    </Select>
                </div>
                <button
                    onClick={lambda { handle_optimize(); }}
                    disabled={selected_neighbor == "" or optimizing}
                    className="flex items-center gap-2 px-5 py-2 text-[13px] font-semibold transition-opacity disabled:opacity-40"
                    style={{"backgroundColor": "#121212", "color": "#fbfaf9", "borderRadius": "9999px", "border": "none", "cursor": "pointer"}}
                >
                    {optimizing and <Spinner className="size-3" /> or <span></span>}
                    {optimizing and "Optimizing..." or "Optimize Route"}
                </button>
            </div>
        </div>

        {exec_result != "" and
            <div className="rounded-[10px] px-5 py-3.5 text-[14px]" style={{"backgroundColor": "#e6fff5", "color": "#00c978", "boxShadow": "inset 0 0 0 1px #b3f0d8"}}>
                {exec_result}
            </div>
        }
        {exec_error != "" and
            <div className="rounded-[10px] px-5 py-3.5 text-[14px]" style={{"backgroundColor": "#fff0f0", "color": "#ff2b3a", "boxShadow": "inset 0 0 0 1px #ffd0d0"}}>
                {exec_error}
            </div>
        }

        {has_route and
            <div className="rounded-[10px] overflow-hidden" style={{"backgroundColor": "#ffffff", "boxShadow": "inset 0 0 0 1px #f2f0ed"}}>
                <div className="px-6 py-4" style={{"borderBottom": "1px solid #f2f0ed"}}>
                    <p className="text-[15px] font-semibold" style={{"color": "#343433"}}>Route Plan for {route["neighbor"] as str}</p>
                    <p className="text-[13px] mt-0.5" style={{"color": "#7e7e7d"}}>
                        {"Balance: " + str(route["balance"] as int) + " pts  ·  Zone: " + (route["home_zone"] as str) + "  ·  " + str(len(plan)) + " stops  ·  Cost: " + str(route["total_cost"] as int) + " pts  ·  Bonus: +" + str(route["total_bonus"] as int) + " pts  ·  Projected: " + str(route["remaining"] as int) + " pts"}
                    </p>
                </div>
                {len(plan) == 0 and
                    <p className="px-6 py-8 text-[14px] text-center" style={{"color": "#7e7e7d"}}>No affordable stops found for this neighbor.</p>
                }
                {len(plan) > 0 and
                    <table className="w-full">
                        <thead>
                            <tr style={{"borderBottom": "1px solid #f2f0ed"}}>
                                <th className="text-left px-6 py-3 text-[12px] font-medium" style={{"color": "#7e7e7d"}}>Stop</th>
                                <th className="text-left px-4 py-3 text-[12px] font-medium" style={{"color": "#7e7e7d"}}>Type</th>
                                <th className="text-left px-4 py-3 text-[12px] font-medium" style={{"color": "#7e7e7d"}}>Zone</th>
                                <th className="text-right px-4 py-3 text-[12px] font-medium" style={{"color": "#7e7e7d"}}>Cost</th>
                                <th className="text-right px-4 py-3 text-[12px] font-medium" style={{"color": "#7e7e7d"}}>Bonus</th>
                                <th className="text-right px-6 py-3 text-[12px] font-medium" style={{"color": "#7e7e7d"}}>Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            {for p in plan {
                                p_stop = p["stop"] as str;
                                p_type = p["stop_type"] as str;
                                p_zone = p["zone"] as str;
                                p_cost = p["cost"] as int;
                                p_bonus = p["bonus"] as int;
                                is_executing = executing == p_stop;
                                <tr key={p_stop} style={{"borderBottom": "1px solid #f2f0ed"}}>
                                    <td className="px-6 py-3.5 text-[14px] font-medium" style={{"color": "#343433"}}>{p_stop}</td>
                                    <td className="px-4 py-3.5">
                                        <span className="inline-block px-2 py-0.5 rounded-[6px] text-[11px] font-medium capitalize" style={{"backgroundColor": "#f2f0ed", "color": "#474645"}}>{p_type}</span>
                                    </td>
                                    <td className="px-4 py-3.5 text-[13px] capitalize" style={{"color": "#7e7e7d"}}>{p_zone}</td>
                                    <td className="px-4 py-3.5 text-right text-[13px] font-medium" style={{"color": "#ff3e00"}}>{str(p_cost)} pts</td>
                                    <td className="px-4 py-3.5 text-right text-[13px] font-medium" style={{"color": "#00c978"}}>
                                        {("+" if p_bonus > 0 else "") + str(p_bonus) + " pts"}
                                    </td>
                                    <td className="px-6 py-3.5 text-right">
                                        <button
                                            disabled={is_executing or executing != ""}
                                            onClick={lambda { pending_stop = p_stop; }}
                                            className="flex items-center gap-1.5 px-4 py-1.5 text-[12px] font-semibold ml-auto transition-opacity disabled:opacity-40"
                                            style={{"backgroundColor": "#121212", "color": "#fbfaf9", "borderRadius": "9999px", "border": "none", "cursor": "pointer"}}
                                        >
                                            {is_executing and <Spinner className="size-3" /> or <span></span>}
                                            {is_executing and "Going..." or "Go"}
                                        </button>
                                    </td>
                                </tr>
                            }}
                        </tbody>
                    </table>
                }
            </div>
        }

        {pending_stop != "" and
            <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/35 p-4">
                <div className="w-full max-w-md rounded-[14px] bg-white p-6 shadow-xl">
                    <h2 className="text-[20px] font-semibold" style={{"color": "#343433"}}>Session check-in</h2>
                    <p className="text-[14px] mt-1 mb-5" style={{"color": "#7e7e7d"}}>
                        {"How was " + selected_neighbor + " feeling during the session at " + pending_stop + "?"}
                    </p>
                    <div className="grid grid-cols-1 gap-2">
                        {for feeling_option in ["Great", "Good", "Okay", "Struggling", "Distressed"] {
                            <button
                                key={feeling_option}
                                onClick={lambda { handle_execute(pending_stop, feeling_option); }}
                                className="w-full rounded-[10px] border px-4 py-2.5 text-left text-[14px] font-medium hover:bg-[#f6f4ef]"
                                style={{"borderColor": "#e5e2dd", "color": "#343433"}}
                            >
                                {feeling_option}
                            </button>
                        }}
                    </div>
                    <button
                        onClick={lambda { pending_stop = ""; }}
                        className="mt-4 w-full text-[13px] font-medium"
                        style={{"color": "#7e7e7d"}}
                    >
                        Cancel
                    </button>
                </div>
            </div>
        }
    </div>;
}
