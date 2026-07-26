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
    api_community_centers, api_suggest_category, api_create_job_seeker, api_find_best_jobs
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

def:pub JobMatchView() -> JsxElement {
    has centers: list[dict] = [];
    has loading_centers: bool = True;
    has selected_center: str = "";

    has seeker_name: str = "";
    has notes: str = "";

    has suggesting: bool = False;
    has has_suggestion: bool = False;
    has category_source: str = "";
    has confirmed_category: str = "";

    has finding: bool = False;
    has matches: list[dict] = [];
    has has_results: bool = False;

    has error: str = "";

    async can with entry {
        try {
            data: any = await api_community_centers();
            centers = data as list[dict];
        } except Exception as e {
            error = str(e);
        }
        loading_centers = False;
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
        if seeker_name == "" or selected_center == "" or confirmed_category == "" {
            return;
        }
        finding = True;
        error = "";
        has_results = False;
        try {
            created: any = await api_create_job_seeker(seeker_name, notes, confirmed_category, selected_center);
            seeker = created as dict;
            if "error" in seeker {
                error = seeker["error"] as str;
            } else {
                seeker_id = seeker["id"] as str;
                data: any = await api_find_best_jobs(seeker_id);
                matches = data as list[dict];
                has_results = True;
            }
        } except Exception as e {
            error = str(e);
        }
        finding = False;
    }

    if loading_centers {
        return <div className="p-6">
            <div className="mb-6">
                <h1 className="text-2xl font-semibold tracking-tight">Job Match</h1>
                <p className="text-muted-foreground text-sm mt-1">Find the best-fit job for a walk-in neighbor</p>
            </div>
            <Skeleton className="h-10 w-64" />
        </div>;
    }

    can_suggest = notes != "" and not suggesting;
    can_find = seeker_name != "" and selected_center != "" and confirmed_category != "" and not finding;

    return <div className="p-6 flex flex-col gap-6">
        <div>
            <h1 className="text-2xl font-semibold tracking-tight">Job Match</h1>
            <p className="text-muted-foreground text-sm mt-1">
                For community-center and food-bank staff: enter a few notes about a walk-in neighbor
                and get back the best-fit jobs nearby.
            </p>
        </div>

        <Card>
            <CardHeader>
                <CardTitle>Walk-in Intake</CardTitle>
                <CardDescription>A caseworker fills this in with the neighbor present.</CardDescription>
            </CardHeader>
            <CardContent className="flex flex-col gap-4">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <Field>
                        <FieldLabel htmlFor="seeker-name">Name</FieldLabel>
                        <Input id="seeker-name" value={seeker_name} onChange={handle_name_change} placeholder="e.g. Maya" />
                    </Field>
                    <Field>
                        <FieldLabel htmlFor="center-select">Community Center</FieldLabel>
                        <Select onValueChange={lambda (v: str) { selected_center = v; }}>
                            <SelectTrigger id="center-select">
                                <SelectValue placeholder="Select a center..." />
                            </SelectTrigger>
                            <SelectContent>
                                <SelectGroup>
                                    {for c in centers {
                                        c_id = c["id"] as str;
                                        c_name = c["name"] as str;
                                        <SelectItem key={c_id} value={c_id}>{c_name}</SelectItem>
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

        {has_results and
            <Card>
                <CardHeader>
                    <CardTitle>Best-fit Jobs for {seeker_name}</CardTitle>
                    <CardDescription>Ranked by category fit, then distance from the community center.</CardDescription>
                </CardHeader>
                <CardContent>
                    {len(matches) == 0 and
                        <p className="text-muted-foreground text-sm py-4 text-center">No jobs found.</p>
                    }
                    {len(matches) > 0 and
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>Job</TableHead>
                                    <TableHead>Category</TableHead>
                                    <TableHead className="text-right">Distance</TableHead>
                                    <TableHead className="text-right">Wage</TableHead>
                                    <TableHead className="text-right">Fit</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {for m in matches {
                                    m_id = m["job_id"] as str;
                                    m_title = m["title"] as str;
                                    m_employer = m["employer_name"] as str;
                                    m_category = m["category"] as str;
                                    m_dist = m["distance_km"] as float;
                                    m_wage = m["wage_hint"] as str;
                                    m_match = m["category_match"] as bool;
                                    <TableRow key={m_id}>
                                        <TableCell>
                                            <p className="font-medium">{m_title}</p>
                                            <p className="text-muted-foreground text-xs">{m_employer}</p>
                                        </TableCell>
                                        <TableCell>
                                            <Badge variant="outline" className="text-xs">{category_label(m_category)}</Badge>
                                        </TableCell>
                                        <TableCell className="text-right text-sm">{f"{m_dist:.1f} km"}</TableCell>
                                        <TableCell className="text-right text-muted-foreground text-sm">
                                            {m_wage if m_wage != "" else "—"}
                                        </TableCell>
                                        <TableCell className="text-right">
                                            {m_match and <Badge className="text-xs">Best fit</Badge> or <span></span>}
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
