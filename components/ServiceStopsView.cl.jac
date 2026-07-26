import from ".ui.skeleton" { Skeleton }
sv import from "..services.goodmiles" { api_stops }

def:pub ServiceStopsView() -> JsxElement {
    has stops: list[dict] = [];
    has loading: bool = True;
    has error: str = "";

    async can with entry {
        try {
            data: any = await api_stops();
            stops = data as list[dict];
        } except Exception as e {
            error = str(e);
        }
        loading = False;
    }

    def type_badge(stop_type: str) -> JsxElement {
        if stop_type == "pantry" {
            return <span className="inline-block px-2 py-0.5 rounded-[6px] text-[11px] font-medium capitalize" style={{"backgroundColor": "#fff8e6", "color": "#d48f00"}}>{stop_type}</span>;
        }
        elif stop_type == "coaching" {
            return <span className="inline-block px-2 py-0.5 rounded-[6px] text-[11px] font-medium capitalize" style={{"backgroundColor": "#e8f4ff", "color": "#0086fc"}}>{stop_type}</span>;
        }
        elif stop_type == "counseling" {
            return <span className="inline-block px-2 py-0.5 rounded-[6px] text-[11px] font-medium capitalize" style={{"backgroundColor": "#f3ecff", "color": "#9f4fff"}}>{stop_type}</span>;
        }
        elif stop_type == "health" {
            return <span className="inline-block px-2 py-0.5 rounded-[6px] text-[11px] font-medium capitalize" style={{"backgroundColor": "#e6fff5", "color": "#00c978"}}>{stop_type}</span>;
        }
        else {
            return <span className="inline-block px-2 py-0.5 rounded-[6px] text-[11px] font-medium capitalize" style={{"backgroundColor": "#f2f0ed", "color": "#474645"}}>{stop_type}</span>;
        }
    }

    if loading {
        return <div className="p-8">
            <div className="mb-8">
                <h1 className="text-[23px] font-semibold tracking-[-0.44px] leading-[25px]" style={{"color": "#343433"}}>Service Stops</h1>
                <p className="text-[15px] mt-1" style={{"color": "#7e7e7d"}}>Available social service destinations</p>
            </div>
            <div className="rounded-[10px] overflow-hidden" style={{"backgroundColor": "#ffffff", "boxShadow": "inset 0 0 0 1px #f2f0ed"}}>
                <div className="p-6 flex flex-col gap-3">
                    {for _ in [0, 1, 2, 3, 4] {
                        <Skeleton key={str(_)} className="h-10 w-full" />
                    }}
                </div>
            </div>
        </div>;
    }

    if error != "" {
        return <div className="p-8">
            <div className="rounded-[10px] p-4 text-[14px]" style={{"backgroundColor": "#fff0f0", "color": "#ff2b3a", "boxShadow": "inset 0 0 0 1px #ffd0d0"}}>
                Failed to load service stops: {error}
            </div>
        </div>;
    }

    return <div className="p-8">
        <div className="mb-8">
            <h1 className="text-[23px] font-semibold tracking-[-0.44px] leading-[25px]" style={{"color": "#343433"}}>Service Stops</h1>
            <p className="text-[15px] mt-1" style={{"color": "#7e7e7d"}}>Available social service destinations</p>
        </div>
        <div className="rounded-[10px] overflow-hidden" style={{"backgroundColor": "#ffffff", "boxShadow": "inset 0 0 0 1px #f2f0ed"}}>
            <div className="px-6 py-4" style={{"borderBottom": "1px solid #f2f0ed"}}>
                <p className="text-[13px] font-medium" style={{"color": "#343433"}}>All Stops ({str(len(stops))})</p>
            </div>
            <table className="w-full">
                <thead>
                    <tr style={{"borderBottom": "1px solid #f2f0ed"}}>
                        <th className="text-left px-6 py-3 text-[12px] font-medium" style={{"color": "#7e7e7d"}}>Name</th>
                        <th className="text-left px-4 py-3 text-[12px] font-medium" style={{"color": "#7e7e7d"}}>Type</th>
                        <th className="text-left px-4 py-3 text-[12px] font-medium" style={{"color": "#7e7e7d"}}>Zone</th>
                        <th className="text-right px-4 py-3 text-[12px] font-medium" style={{"color": "#7e7e7d"}}>Cost</th>
                        <th className="text-right px-4 py-3 text-[12px] font-medium" style={{"color": "#7e7e7d"}}>Bonus</th>
                        <th className="text-right px-6 py-3 text-[12px] font-medium" style={{"color": "#7e7e7d"}}>Net</th>
                    </tr>
                </thead>
                <tbody>
                    {for s in stops {
                        s_name = s["name"] as str;
                        s_type = s["stop_type"] as str;
                        s_zone = s["zone"] as str;
                        s_cost = s["base_cost"] as int;
                        s_bonus = s["bonus_on_visit"] as int;
                        s_id = s["id"] as str;
                        net = s_bonus - s_cost;
                        net_str = ("+" if net >= 0 else "") + str(net);
                        net_color = "#00c978" if net >= 0 else "#ff3e00";
                        <tr key={s_id} style={{"borderBottom": "1px solid #f2f0ed"}}>
                            <td className="px-6 py-3.5 text-[14px] font-medium" style={{"color": "#343433"}}>{s_name}</td>
                            <td className="px-4 py-3.5">{type_badge(s_type)}</td>
                            <td className="px-4 py-3.5 text-[13px] capitalize" style={{"color": "#7e7e7d"}}>{s_zone}</td>
                            <td className="px-4 py-3.5 text-right text-[13px] font-medium" style={{"color": "#ff3e00"}}>{str(s_cost)} pts</td>
                            <td className="px-4 py-3.5 text-right text-[13px] font-medium" style={{"color": "#00c978"}}>
                                {("+" if s_bonus > 0 else "") + str(s_bonus) + " pts"}
                            </td>
                            <td className="px-6 py-3.5 text-right text-[13px] font-semibold" style={{"color": net_color}}>{net_str}</td>
                        </tr>
                    }}
                </tbody>
            </table>
        </div>
    </div>;
}
