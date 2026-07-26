import from ".ui.card" { Card, CardHeader, CardTitle, CardContent }
import from ".ui.badge" { Badge }
import from ".ui.table" { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
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

    def badge_color(stop_type: str) -> str {
        if stop_type == "pantry" { return "secondary"; }
        elif stop_type == "coaching" { return "default"; }
        elif stop_type == "counseling" { return "outline"; }
        elif stop_type == "health" { return "destructive"; }
        else { return "outline"; }
    }

    if loading {
        return <div className="p-6">
            <div className="mb-6">
                <h1 className="text-2xl font-semibold tracking-tight">Service Stops</h1>
                <p className="text-muted-foreground text-sm mt-1">Available social service destinations</p>
            </div>
            <Card>
                <CardContent className="pt-6">
                    <div className="flex flex-col gap-3">
                        {for _ in [0, 1, 2, 3, 4] {
                            <Skeleton key={str(_)} className="h-12 w-full" />
                        }}
                    </div>
                </CardContent>
            </Card>
        </div>;
    }

    if error != "" {
        return <div className="p-6">
            <div className="rounded-lg border border-destructive/50 bg-destructive/10 p-4 text-destructive text-sm">
                Failed to load service stops: {error}
            </div>
        </div>;
    }

    return <div className="p-6">
        <div className="mb-6">
            <h1 className="text-2xl font-semibold tracking-tight">Service Stops</h1>
            <p className="text-muted-foreground text-sm mt-1">Available social service destinations</p>
        </div>
        <Card>
            <CardHeader>
                <CardTitle>All Stops ({str(len(stops))})</CardTitle>
            </CardHeader>
            <CardContent>
                <Table>
                    <TableHeader>
                        <TableRow>
                            <TableHead>Name</TableHead>
                            <TableHead>Type</TableHead>
                            <TableHead>Zone</TableHead>
                            <TableHead className="text-right">Cost (pts)</TableHead>
                            <TableHead className="text-right">Bonus (pts)</TableHead>
                            <TableHead className="text-right">Net</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {for s in stops {
                            s_name = s["name"] as str;
                            s_type = s["stop_type"] as str;
                            s_zone = s["zone"] as str;
                            s_cost = s["base_cost"] as int;
                            s_bonus = s["bonus_on_visit"] as int;
                            s_id = s["id"] as str;
                            net = s_bonus - s_cost;
                            net_str = ("+" if net >= 0 else "") + str(net);
                            net_cls = "text-right font-medium " + ("text-emerald-600" if net >= 0 else "text-rose-500");
                            <TableRow key={s_id}>
                                <TableCell className="font-medium">{s_name}</TableCell>
                                <TableCell>
                                    <Badge variant={badge_color(s_type)} className="capitalize text-xs">{s_type}</Badge>
                                </TableCell>
                                <TableCell>
                                    <span className="capitalize text-muted-foreground text-sm">{s_zone}</span>
                                </TableCell>
                                <TableCell className="text-right text-rose-500 font-medium">{str(s_cost)}</TableCell>
                                <TableCell className="text-right text-emerald-600 font-medium">
                                    {("+" if s_bonus > 0 else "") + str(s_bonus)}
                                </TableCell>
                                <TableCell className={net_cls}>{net_str}</TableCell>
                            </TableRow>
                        }}
                    </TableBody>
                </Table>
            </CardContent>
        </Card>
    </div>;
}
