import from ".ui.card" { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ".ui.badge" { Badge }
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
        return <div className="p-6">
            <div className="mb-6">
                <h1 className="text-2xl font-semibold tracking-tight">Neighbors</h1>
                <p className="text-muted-foreground text-sm mt-1">Community members in the mobility program</p>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                {for _ in [0, 1, 2, 3] {
                    <Card key={str(_)}>
                        <CardHeader>
                            <Skeleton className="h-5 w-24" />
                            <Skeleton className="h-4 w-16 mt-1" />
                        </CardHeader>
                        <CardContent>
                            <Skeleton className="h-8 w-20 mb-3" />
                            <Skeleton className="h-4 w-32" />
                        </CardContent>
                    </Card>
                }}
            </div>
        </div>;
    }

    if error != "" {
        return <div className="p-6">
            <div className="rounded-lg border border-destructive/50 bg-destructive/10 p-4 text-destructive text-sm">
                Failed to load neighbors: {error}
            </div>
        </div>;
    }

    return <div className="p-6">
        <div className="mb-6">
            <h1 className="text-2xl font-semibold tracking-tight">Neighbors</h1>
            <p className="text-muted-foreground text-sm mt-1">Community members in the mobility program</p>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            {for n in neighbors {
                bal = n["points_balance"] as int;
                earned = n["points_earned"] as int;
                spent = n["points_spent"] as int;
                zone_str = n["home_zone"] as str;
                name_str = n["name"] as str;
                id_str = n["id"] as str;
                <Card key={id_str} className="hover:shadow-md transition-shadow">
                    <CardHeader>
                        <CardTitle className="text-lg">{name_str}</CardTitle>
                        <CardDescription>
                            <Badge variant="outline" className="text-xs capitalize">{zone_str} zone</Badge>
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="mb-3">
                            <span className="text-3xl font-bold text-primary">{str(bal)}</span>
                            <span className="text-muted-foreground text-sm ml-1">pts balance</span>
                        </div>
                        <div className="flex gap-4 text-sm">
                            <div>
                                <span className="text-emerald-600 font-medium">+{str(earned)}</span>
                                <span className="text-muted-foreground ml-1">earned</span>
                            </div>
                            <div>
                                <span className="text-rose-500 font-medium">-{str(spent)}</span>
                                <span className="text-muted-foreground ml-1">spent</span>
                            </div>
                        </div>
                    </CardContent>
                </Card>
            }}
        </div>
    </div>;
}
