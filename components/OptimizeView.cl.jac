import from ".ui.card" { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ".ui.button" { Button }
import from ".ui.badge" { Badge }
import from ".ui.select" { Select, SelectTrigger, SelectContent, SelectGroup, SelectItem, SelectValue }
import from ".ui.table" { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
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

    async def handle_execute(stop_name: str) -> None {
        executing = stop_name;
        exec_result = "";
        exec_error = "";
        try {
            data: any = await api_execute(neighbor_name=selected_neighbor, stop_name=stop_name);
            res = data as dict;
            if "error" in res {
                exec_error = res["error"] as str;
            } else {
                new_bal = res["new_balance"] as int;
                cost_val = res["cost"] as int;
                bonus_val = res["bonus"] as int;
                exec_result = "Trip to " + stop_name + " complete. Cost: " + str(cost_val) + " pts, Bonus: +" + str(bonus_val) + " pts. New balance: " + str(new_bal) + " pts.";
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
        return <div className="p-6">
            <div className="mb-6">
                <h1 className="text-2xl font-semibold tracking-tight">Optimize Route</h1>
                <p className="text-muted-foreground text-sm mt-1">Find the best route for a neighbor</p>
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

    return <div className="p-6 flex flex-col gap-6">
        <div>
            <h1 className="text-2xl font-semibold tracking-tight">Optimize Route</h1>
            <p className="text-muted-foreground text-sm mt-1">Find the best route for a neighbor and execute trips</p>
        </div>

        <Card>
            <CardHeader>
                <CardTitle>Select Neighbor</CardTitle>
                <CardDescription>Choose a neighbor to optimize their mobility route</CardDescription>
            </CardHeader>
            <CardContent>
                <div className="flex flex-wrap gap-3 items-end">
                    <div className="w-64">
                        <Select onValueChange={lambda (v: str) { selected_neighbor = v; route = {}; exec_result = ""; exec_error = ""; }}>
                            <SelectTrigger>
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
                    <Button
                        onClick={lambda { handle_optimize(); }}
                        disabled={selected_neighbor == "" or optimizing}
                    >
                        {optimizing and <Spinner className="size-4 mr-2" /> or <span></span>}
                        {optimizing and "Optimizing..." or "Optimize Route"}
                    </Button>
                </div>
            </CardContent>
        </Card>

        {exec_result != "" and
            <div className="rounded-lg border border-emerald-200 bg-emerald-50 p-4 text-emerald-800 text-sm">
                {exec_result}
            </div>
        }
        {exec_error != "" and
            <div className="rounded-lg border border-destructive/50 bg-destructive/10 p-4 text-destructive text-sm">
                {exec_error}
            </div>
        }

        {has_route and
            <Card>
                <CardHeader>
                    <CardTitle>Route Plan for {route["neighbor"] as str}</CardTitle>
                    <CardDescription>
                        {"Balance: " + str(route["balance"] as int) + " pts | Zone: " + (route["home_zone"] as str) + " | Stops: " + str(len(plan)) + " | Total cost: " + str(route["total_cost"] as int) + " pts | Total bonus: +" + str(route["total_bonus"] as int) + " pts | Projected balance: " + str(route["remaining"] as int) + " pts"}
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    {len(plan) == 0 and
                        <p className="text-muted-foreground text-sm py-4 text-center">No affordable stops found for this neighbor.</p>
                    }
                    {len(plan) > 0 and
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>Stop</TableHead>
                                    <TableHead>Type</TableHead>
                                    <TableHead>Zone</TableHead>
                                    <TableHead className="text-right">Cost</TableHead>
                                    <TableHead className="text-right">Bonus</TableHead>
                                    <TableHead className="text-right">Action</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {for p in plan {
                                    p_stop = p["stop"] as str;
                                    p_type = p["stop_type"] as str;
                                    p_zone = p["zone"] as str;
                                    p_cost = p["cost"] as int;
                                    p_bonus = p["bonus"] as int;
                                    is_executing = executing == p_stop;
                                    <TableRow key={p_stop}>
                                        <TableCell className="font-medium">{p_stop}</TableCell>
                                        <TableCell>
                                            <Badge variant="outline" className="capitalize text-xs">{p_type}</Badge>
                                        </TableCell>
                                        <TableCell className="text-muted-foreground text-sm capitalize">{p_zone}</TableCell>
                                        <TableCell className="text-right text-rose-500 font-medium">{str(p_cost)} pts</TableCell>
                                        <TableCell className="text-right text-emerald-600 font-medium">
                                            {("+" if p_bonus > 0 else "") + str(p_bonus) + " pts"}
                                        </TableCell>
                                        <TableCell className="text-right">
                                            <Button
                                                size="sm"
                                                variant="outline"
                                                disabled={is_executing or executing != ""}
                                                onClick={lambda { handle_execute(p_stop); }}
                                            >
                                                {is_executing and <Spinner className="size-3 mr-1" /> or <span></span>}
                                                {is_executing and "Going..." or "Go"}
                                            </Button>
                                        </TableCell>
                                    </TableRow>
                                }}
                            </TableBody>
                        </Table>
                    }
                </CardContent>
            </Card>
        }
    </div>;
}
