import from ".ui.card" { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from ".ui.button" { Button }
import from ".ui.badge" { Badge }
import from ".ui.select" { Select, SelectTrigger, SelectContent, SelectGroup, SelectItem, SelectValue }
import from ".ui.table" { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
import from ".ui.input" { Input }
import from ".ui.textarea" { Textarea }
import from ".ui.field" { Field, FieldLabel }
import from ".ui.skeleton" { Skeleton }
import from ".ui.spinner" { Spinner }
sv import from "..services.jobmatch" {
    api_service_stops, api_suggest_category, api_create_job_seeker, api_find_best_jobs
}

glob _CATEGORY_OPTIONS: list[dict] = [
    {"value": "kitchen", "label": "Kitchen & Food Prep"},
    {"value": "cleaning", "label": "Cleaning & Custodial"},
    {"value": "warehouse", "label": "Warehouse & Logistics"},
    {"value": "hospitality", "label": "Hotel & Hospitality"},
    {"value": "retail", "label": "Retail & Grocery"},
    {"value": "admin", "label": "Office & Reception"},
];

def category_label(value: str) -> str {
    for opt in _CATEGORY_OPTIONS {
        if (opt["value"] as str) == value {
            return opt["label"] as str;
        }
    }
    return value;
}

def cap(value: str) -> str {
    if value == "" {
        return value;
    }
    return value.capitalize();
}

def miles_label(miles: float) -> str {
    return f"{miles:.1f} mi away";
}

def:pub JobMatchView() -> JsxElement {
    has stops: list[dict] = [];
    has loading_stops: bool = True;
    has selected_stop: str = "";

    has seeker_name: str = "";
    has notes: str = "";

    has suggesting: bool = False;
    has has_suggestion: bool = False;
    has category_source: str = "";
    has confirmed_category: str = "";

    has finding: bool = False;
    has origin: dict = {};
    has recommended: dict = {};
    has matches: list[dict] = [];
    has total_open_spots: int = 0;
    has open_positions: int = 0;
    has has_results: bool = False;

    has error: str = "";

    async can with entry {
        try {
            data: any = await api_service_stops();
            stops = data as list[dict];
        } except Exception as e {
            error = str(e);
        }
        loading_stops = False;
    }

    def handle_name_change(e: ChangeEvent) {
        seeker_name = e.target.value;
    }

    def handle_notes_change(e: ChangeEvent) {
        notes = e.target.value;
        has_suggestion = False;
        has_results = False;
    }

    async def handle_suggest() -> None {
        if notes == "" {
            return;
        }
        suggesting = True;
        error = "";
        try {
            data: any = await api_suggest_category(notes);
            res = data as dict;
            confirmed_category = res["category"] as str;
            category_source = res["source"] as str;
            has_suggestion = True;
        } except Exception as e {
            error = str(e);
        }
        suggesting = False;
    }

    async def handle_find_jobs() -> None {
        if seeker_name == "" or selected_stop == "" or confirmed_category == "" {
            return;
        }
        finding = True;
        error = "";
        has_results = False;
        try {
            created: any = await api_create_job_seeker(seeker_name, notes, confirmed_category, selected_stop);
            seeker = created as dict;
            if "error" in seeker {
                error = seeker["error"] as str;
            } else {
                seeker_id = seeker["id"] as str;
                data: any = await api_find_best_jobs(seeker_id);
                res = data as dict;
                origin = res["origin"] as dict;
                recommended = res["recommended"] as dict;
                matches = res["matches"] as list[dict];
                total_open_spots = res["total_open_spots"] as int;
                open_positions = res["open_positions"] as int;
                has_results = True;
            }
        } except Exception as e {
            error = str(e);
        }
        finding = False;
    }

    if loading_stops {
        return <div className="p-6">
            <div className="mb-6">
                <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">On-Demand AV as a Social Service</p>
                <h1 className="text-2xl font-semibold tracking-tight mt-1">Job Match</h1>
                <p className="text-muted-foreground text-sm mt-1">Coordinating a neighbor's next step from the ride to real work</p>
            </div>
            <Skeleton className="h-10 w-64" />
        </div>;
    }

    can_suggest = notes != "" and not suggesting;
    can_find = seeker_name != "" and selected_stop != "" and confirmed_category != "" and not finding;

    has_recommendation = has_results and ("title" in recommended);
    origin_name = (origin["name"] as str) if "name" in origin else "";
    origin_zone = (origin["zone"] as str) if "zone" in origin else "";
    origin_type = (origin["stop_type"] as str) if "stop_type" in origin else "";

    return <div className="p-6 flex flex-col gap-6">
        <div>
            <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">On-Demand AV as a Social Service</p>
            <h1 className="text-2xl font-semibold tracking-tight mt-1">Job Match</h1>
            <p className="text-muted-foreground text-sm mt-1 max-w-3xl">
                The ride is only the start. When a neighbor like Maya reaches a community center, the
                service coordinates the next step — connecting her to the best-fit open job nearby.
                It reaches people the current system misses and automates the logistics, while a
                caseworker keeps the human decision.
            </p>
        </div>

        <Card>
            <CardHeader>
                <CardTitle>Walk-in Intake</CardTitle>
                <CardDescription>A caseworker fills this in at their community center with the neighbor present.</CardDescription>
            </CardHeader>
            <CardContent className="flex flex-col gap-4">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <Field>
                        <FieldLabel htmlFor="seeker-name">Name</FieldLabel>
                        <Input id="seeker-name" value={seeker_name} onChange={handle_name_change} placeholder="e.g. Maya" />
                    </Field>
                    <Field>
                        <FieldLabel htmlFor="center-select">Community Center</FieldLabel>
                        <Select onValueChange={lambda (v: str) { selected_stop = v; }}>
                            <SelectTrigger id="center-select">
                                <SelectValue placeholder="Where is the neighbor now?" />
                            </SelectTrigger>
                            <SelectContent>
                                <SelectGroup>
                                    {for s in stops {
                                        s_id = s["id"] as str;
                                        s_name = s["name"] as str;
                                        s_zone = s["zone"] as str;
                                        s_type = s["stop_type"] as str;
                                        <SelectItem key={s_id} value={s_id}>
                                            {s_name + " — " + cap(s_type) + " · " + cap(s_zone)}
                                        </SelectItem>
                                    }}
                                </SelectGroup>
                            </SelectContent>
                        </Select>
                    </Field>
                </div>

                <Field>
                    <FieldLabel htmlFor="notes">Notes</FieldLabel>
                    <Textarea
                        id="notes"
                        value={notes}
                        onChange={handle_notes_change}
                        placeholder="e.g. Restaurant and cleaning experience, mornings only, no car, needs income soon"
                    />
                </Field>

                <div>
                    <Button variant="outline" onClick={lambda { handle_suggest(); }} disabled={not can_suggest}>
                        {suggesting and <Spinner className="size-4 mr-2" /> or <span></span>}
                        {suggesting and "Thinking..." or "Suggest Category"}
                    </Button>
                </div>

                {has_suggestion and
                    <div className="rounded-lg border border-border bg-muted/30 p-4 flex flex-col gap-3">
                        <div className="flex items-center gap-2 text-sm">
                            <span className="text-muted-foreground">Suggested category</span>
                            <Badge variant="outline" className="text-xs capitalize">{category_source}</Badge>
                        </div>
                        <Field>
                            <FieldLabel htmlFor="category-select">Confirm or change the category</FieldLabel>
                            <Select value={confirmed_category} onValueChange={lambda (v: str) { confirmed_category = v; }}>
                                <SelectTrigger id="category-select" className="w-72">
                                    <SelectValue placeholder="Select a category..." />
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectGroup>
                                        {for opt in _CATEGORY_OPTIONS {
                                            o_val = opt["value"] as str;
                                            o_label = opt["label"] as str;
                                            <SelectItem key={o_val} value={o_val}>{o_label}</SelectItem>
                                        }}
                                    </SelectGroup>
                                </SelectContent>
                            </Select>
                        </Field>
                        <p className="text-muted-foreground text-xs">
                            A caseworker always confirms this before it's saved — the suggestion never applies on its own.
                        </p>
                    </div>
                }

                <div>
                    <Button onClick={lambda { handle_find_jobs(); }} disabled={not can_find}>
                        {finding and <Spinner className="size-4 mr-2" /> or <span></span>}
                        {finding and "Finding jobs..." or "Find Jobs"}
                    </Button>
                </div>
            </CardContent>
        </Card>

        {error != "" and
            <div className="rounded-lg border border-destructive/50 bg-destructive/10 p-4 text-destructive text-sm">
                {error}
            </div>
        }

        {has_recommendation and
            <Card className="border-primary/40">
                <CardHeader>
                    <CardTitle>Next best job for {seeker_name}</CardTitle>
                    <CardDescription>
                        {"From " + origin_name + " (" + cap(origin_type) + " · " + cap(origin_zone) + "), the agent found "
                            + str(total_open_spots) + " open spots across " + str(open_positions)
                            + " employers — here's the single best assignment."}
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <div className="flex flex-col gap-3">
                        <div className="flex items-start justify-between gap-4">
                            <div>
                                <p className="text-lg font-semibold">{recommended["title"] as str}</p>
                                <p className="text-muted-foreground text-sm">{recommended["employer_name"] as str}</p>
                            </div>
                            {(recommended["category_match"] as bool) and <Badge>Best fit</Badge> or <span></span>}
                        </div>
                        <div className="flex flex-wrap items-center gap-2">
                            <Badge variant="outline" className="text-xs">{category_label(recommended["category"] as str)}</Badge>
                            <Badge variant="secondary" className="text-xs">{miles_label(recommended["distance_miles"] as float)}</Badge>
                            <Badge variant="secondary" className="text-xs">{str(recommended["open_spots"] as int) + " open spots"}</Badge>
                            {(recommended["wage_hint"] as str) != "" and
                                <Badge variant="secondary" className="text-xs">{recommended["wage_hint"] as str}</Badge>
                            }
                        </div>
                        {(recommended["address"] as str) != "" and
                            <p className="text-muted-foreground text-xs">📍 {recommended["address"] as str}</p>
                        }
                    </div>
                </CardContent>
            </Card>
        }

        {has_results and len(matches) > 1 and
            <Card>
                <CardHeader>
                    <CardTitle>Other open jobs</CardTitle>
                    <CardDescription>Ranked by category fit, then distance from {origin_name}.</CardDescription>
                </CardHeader>
                <CardContent>
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead>Job</TableHead>
                                <TableHead>Place</TableHead>
                                <TableHead>Category</TableHead>
                                <TableHead className="text-right">Distance</TableHead>
                                <TableHead className="text-right">Open spots</TableHead>
                                <TableHead className="text-right">Wage</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {for m in matches[1:] {
                                m_id = m["job_id"] as str;
                                m_title = m["title"] as str;
                                m_employer = m["employer_name"] as str;
                                m_category = m["category"] as str;
                                m_address = m["address"] as str;
                                m_dist = m["distance_miles"] as float;
                                m_spots = m["open_spots"] as int;
                                m_wage = m["wage_hint"] as str;
                                m_match = m["category_match"] as bool;
                                <TableRow key={m_id}>
                                    <TableCell>
                                        <p className="font-medium">{m_title}</p>
                                        <p className="text-muted-foreground text-xs">{m_employer}</p>
                                    </TableCell>
                                    <TableCell className="text-muted-foreground text-xs max-w-48">{m_address}</TableCell>
                                    <TableCell>
                                        <Badge variant="outline" className="text-xs">{category_label(m_category)}</Badge>
                                    </TableCell>
                                    <TableCell className="text-right text-sm">{miles_label(m_dist)}</TableCell>
                                    <TableCell className="text-right text-sm">{str(m_spots)}</TableCell>
                                    <TableCell className="text-right text-muted-foreground text-sm">
                                        {m_wage if m_wage != "" else "—"}
                                    </TableCell>
                                </TableRow>
                            }}
                        </TableBody>
                    </Table>
                </CardContent>
            </Card>
        }

        {has_results and len(matches) == 0 and
            <div className="rounded-lg border border-border p-4 text-muted-foreground text-sm text-center">
                No open jobs found.
            </div>
        }
    </div>;
}
