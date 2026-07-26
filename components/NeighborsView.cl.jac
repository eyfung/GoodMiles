import from ".ui.skeleton" { Skeleton }
sv import from "..services.goodmiles" { api_neighbors }

def:pub NeighborsView() -> JsxElement {
    has neighbors: list[dict] = [];
    has loading: bool = True;
    has error: str = "";

    async can with entry {
        try {
            data: any = await api_neighbors();
            neighbors = data as list[dict];
        } except Exception as e {
            error = str(e);
        }
        loading = False;
    }

    if loading {
        return <div className="p-8">
            <div className="mb-8">
                <h1 className="text-[23px] font-semibold tracking-[-0.44px] leading-[25px]" style={{"color": "#343433"}}>Neighbors</h1>
                <p className="text-[15px] mt-1" style={{"color": "#7e7e7d"}}>Community members in the mobility program</p>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                {for _ in [0, 1, 2, 3] {
                    <div key={str(_)} className="rounded-[10px] p-8" style={{"backgroundColor": "#ffffff", "boxShadow": "inset 0 0 0 1px #f2f0ed"}}>
                        <Skeleton className="h-4 w-20 mb-1" />
                        <Skeleton className="h-3 w-16 mb-6" />
                        <Skeleton className="h-8 w-24 mb-4" />
                        <Skeleton className="h-3 w-32" />
                    </div>
                }}
            </div>
        </div>;
    }

    if error != "" {
        return <div className="p-8">
            <div className="rounded-[10px] p-4 text-[14px]" style={{"backgroundColor": "#fff0f0", "color": "#ff2b3a", "boxShadow": "inset 0 0 0 1px #ffd0d0"}}>
                Failed to load neighbors: {error}
            </div>
        </div>;
    }

    return <div className="p-8">
        <div className="mb-8">
            <h1 className="text-[23px] font-semibold tracking-[-0.44px] leading-[25px]" style={{"color": "#343433"}}>Neighbors</h1>
            <p className="text-[15px] mt-1" style={{"color": "#7e7e7d"}}>Community members in the mobility program</p>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            {for n in neighbors {
                bal = n["points_balance"] as int;
                earned = n["points_earned"] as int;
                spent = n["points_spent"] as int;
                zone_str = n["home_zone"] as str;
                name_str = n["name"] as str;
                id_str = n["id"] as str;
                <div key={id_str} className="rounded-[10px] p-6" style={{"backgroundColor": "#ffffff", "boxShadow": "inset 0 0 0 1px #f2f0ed"}}>
                    <div className="mb-4">
                        <p className="text-[15px] font-semibold" style={{"color": "#343433"}}>{name_str}</p>
                        <span className="inline-block mt-1 px-2 py-0.5 rounded-[6px] text-[11px] font-medium capitalize" style={{"backgroundColor": "#f2f0ed", "color": "#474645"}}>
                            {zone_str} zone
                        </span>
                    </div>
                    <div className="mb-4">
                        <span className="text-[32px] font-semibold tracking-[-0.5px]" style={{"color": "#121212"}}>{str(bal)}</span>
                        <span className="text-[13px] ml-1.5" style={{"color": "#7e7e7d"}}>pts</span>
                    </div>
                    <div className="flex gap-4 text-[13px]">
                        <div>
                            <span className="font-medium" style={{"color": "#00c978"}}>+{str(earned)}</span>
                            <span className="ml-1" style={{"color": "#7e7e7d"}}>earned</span>
                        </div>
                        <div>
                            <span className="font-medium" style={{"color": "#ff3e00"}}>-{str(spent)}</span>
                            <span className="ml-1" style={{"color": "#7e7e7d"}}>spent</span>
                        </div>
                    </div>
                </div>
            }}
        </div>
    </div>;
}
