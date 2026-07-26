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
sv import from "..services.pathway" {
    api_service_stops, api_suggest_category, api_create_participant,
    api_build_pathway, api_grant_consent, api_replan
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

def step_badge(status: str) -> JsxElement {
    if status == "completed" {
        return <Badge className="text-xs">Completed</Badge>;
    }
    if status == "awaiting_consent" {
        return <Badge variant="outline" className="text-xs">Awaiting consent</Badge>;
    }
    if status == "blocked" {
        return <Badge variant="destructive" className="text-xs">Blocked</Badge>;
    }
    if status == "failed" {
        return <Badge variant="destructive" className="text-xs">Failed</Badge>;
    }
    return <Badge variant="secondary" className="text-xs">Pending</Badge>;
}

def:pub PathwayView() -> JsxElement {
    has stops: list[dict] = [];
    has loading_stops: bool = True;
    has selected_stop: str = "";

    has seeker_name: str = "";
    has notes: str = "";
    has availability: str = "morning";
    has car_val: str = "no";
    has resume_val: str = "no";
    has income_val: str = "yes";

    has suggesting: bool = False;
    has has_suggestion: bool = False;
    has category_source: str = "";
    has confirmed_category: str = "";

    has building: bool = False;
    has acting: bool = False;
    has pathway: dict = {};
    has has_pathway: bool = False;

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
        has_pathway = False;
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

    async def handle_build() -> None {
        if seeker_name == "" or selected_stop == "" or confirmed_category == "" {
            return;
        }
        building = True;
        error = "";
        has_pathway = False;
        try {
            created: any = await api_create_participant(
                seeker_name, notes, confirmed_category, selected_stop,
                availability, car_val == "yes", resume_val == "yes", income_val == "yes"
            );
            pdata = created as dict;
            if "error" in pdata {
                error = pdata["error"] as str;
            } else {
                pid = pdata["id"] as str;
                built: any = await api_build_pathway(pid);
                pw = built as dict;
                if "error" in pw {
                    error = pw["error"] as str;
                } else {
                    pathway = pw;
                    has_pathway = True;
                }
            }
        } except Exception as e {
            error = str(e);
        }
        building = False;
    }

    async def handle_consent() -> None {
        if not has_pathway {
            return;
        }
        acting = True;
        error = "";
        try {
            pid = pathway["pathway_id"] as str;
            updated: any = await api_grant_consent(pid);
            pathway = updated as dict;
        } except Exception as e {
            error = str(e);
        }
        acting = False;
    }

    async def handle_replan() -> None {
        if not has_pathway {
            return;
        }
        acting = True;
        error = "";
        try {
            pid = pathway["pathway_id"] as str;
            updated: any = await api_replan(pid);
            pathway = updated as dict;
        } except Exception as e {
            error = str(e);
        }
        acting = False;
    }

    if loading_stops {
        return <div className="p-6">
            <div className="mb-6">
                <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">On-Demand AV as a Social Service</p>
                <h1 className="text-2xl font-semibold tracking-tight mt-1">Pathway</h1>
                <p className="text-muted-foreground text-sm mt-1">Coordinating a participant's full route from intake to a real job</p>
            </div>
            <Skeleton className="h-10 w-64" />
        </div>;
    }

    can_suggest = notes != "" and not suggesting;
    can_build = seeker_name != "" and selected_stop != "" and confirmed_category != "" and not building;

    pw_status: str = "";
    sel: dict = {};
    counts: dict = {};
    consent_needed: int = 0;
    if has_pathway {
        pw_status = pathway["status"] as str;
        sel = pathway["selected"] as dict;
        counts = pathway["counts"] as dict;
        consent_needed = counts["awaiting_consent"] as int;
    }
    has_selected = has_pathway and ("title" in sel);
    sel_dist: float = 0.0;
    if has_selected {
        sel_dist = sel["distance_miles"] as float;
    }

    return <div className="p-6 flex flex-col gap-6">
        <div>
            <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">On-Demand AV as a Social Service</p>
            <h1 className="text-2xl font-semibold tracking-tight mt-1">Pathway</h1>
            <p className="text-muted-foreground text-sm mt-1 max-w-3xl">
                The agent builds, executes, and continuously re-plans each participant's route to work —
                matching feasible jobs, rejecting the ones that aren't, clearing barriers with community
                resources, and holding for human consent. It coordinates; it doesn't just recommend.
            </p>
        </div>

        <Card>
            <CardHeader>
                <CardTitle>Participant Intake</CardTitle>
                <CardDescription>A caseworker fills this in at their community center with the participant present.</CardDescription>
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
                                <SelectValue placeholder="Where is the participant now?" />
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
                    <FieldLabel htmlFor="notes">Experience notes</FieldLabel>
                    <Textarea
                        id="notes"
                        value={notes}
                        onChange={handle_notes_change}
                        placeholder="e.g. Restaurant and cleaning experience, mornings only, no car, needs income soon"
                    />
                </Field>

                <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                    <Field>
                        <FieldLabel htmlFor="availability">Availability</FieldLabel>
                        <Select value={availability} onValueChange={lambda (v: str) { availability = v; }}>
                            <SelectTrigger id="availability"><SelectValue /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="morning">Morning</SelectItem>
                                <SelectItem value="afternoon">Afternoon</SelectItem>
                                <SelectItem value="evening">Evening</SelectItem>
                                <SelectItem value="any">Any time</SelectItem>
                            </SelectContent>
                        </Select>
                    </Field>
                    <Field>
                        <FieldLabel htmlFor="car">Has a car?</FieldLabel>
                        <Select value={car_val} onValueChange={lambda (v: str) { car_val = v; }}>
                            <SelectTrigger id="car"><SelectValue /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="no">No</SelectItem>
                                <SelectItem value="yes">Yes</SelectItem>
                            </SelectContent>
                        </Select>
                    </Field>
                    <Field>
                        <FieldLabel htmlFor="resume">Has a résumé?</FieldLabel>
                        <Select value={resume_val} onValueChange={lambda (v: str) { resume_val = v; }}>
                            <SelectTrigger id="resume"><SelectValue /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="no">No</SelectItem>
                                <SelectItem value="yes">Yes</SelectItem>
                            </SelectContent>
                        </Select>
                    </Field>
                    <Field>
                        <FieldLabel htmlFor="income">Needs income soon?</FieldLabel>
                        <Select value={income_val} onValueChange={lambda (v: str) { income_val = v; }}>
                            <SelectTrigger id="income"><SelectValue /></SelectTrigger>
                            <SelectContent>
                                <SelectItem value="yes">Yes</SelectItem>
                                <SelectItem value="no">No</SelectItem>
                            </SelectContent>
                        </Select>
                    </Field>
                </div>

                <div className="flex flex-wrap items-center gap-3">
                    <Button variant="outline" onClick={lambda { handle_suggest(); }} disabled={not can_suggest}>
                        {suggesting and <Spinner className="size-4 mr-2" /> or <span></span>}
                        {suggesting and "Thinking..." or "Suggest Category"}
                    </Button>
                    {has_suggestion and
                        <div className="flex items-center gap-2">
                            <Select value={confirmed_category} onValueChange={lambda (v: str) { confirmed_category = v; }}>
                                <SelectTrigger className="w-64"><SelectValue placeholder="Confirm category..." /></SelectTrigger>
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
                            <Badge variant="outline" className="text-xs capitalize">{category_source}</Badge>
                        </div>
                    }
                </div>

                <div>
                    <Button onClick={lambda { handle_build(); }} disabled={not can_build}>
                        {building and <Spinner className="size-4 mr-2" /> or <span></span>}
                        {building and "Building pathway..." or "Build Pathway"}
                    </Button>
                </div>
            </CardContent>
        </Card>

        {error != "" and
            <div className="rounded-lg border border-destructive/50 bg-destructive/10 p-4 text-destructive text-sm">
                {error}
            </div>
        }

        {has_pathway and
            <Card className={pw_status == "escalated" and "border-destructive/50" or "border-primary/40"}>
                <CardHeader>
                    <div className="flex items-start justify-between gap-4">
                        <div>
                            <CardTitle>Employment goal</CardTitle>
                            <CardDescription>{pathway["goal"] as str}</CardDescription>
                        </div>
                        {pw_status == "escalated" and <Badge variant="destructive">Needs caseworker</Badge> or <Badge>Active pathway</Badge>}
                    </div>
                </CardHeader>
                <CardContent className="flex flex-col gap-4">
                    {has_selected and
                        <div className="rounded-lg border border-border bg-muted/30 p-4 flex flex-col gap-2">
                            <div className="flex items-start justify-between gap-4">
                                <div>
                                    <p className="text-lg font-semibold">{sel["title"] as str}</p>
                                    <p className="text-muted-foreground text-sm">{sel["employer_name"] as str}</p>
                                </div>
                                <Badge>Recommended</Badge>
                            </div>
                            <p className="text-sm text-muted-foreground">✓ {pathway["feasibility_reason"] as str}</p>
                            <div className="flex flex-wrap items-center gap-2">
                                <Badge variant="outline" className="text-xs">{category_label(sel["category"] as str)}</Badge>
                                <Badge variant="secondary" className="text-xs">{sel["shift_label"] as str}</Badge>
                                <Badge variant="secondary" className="text-xs">{f"{sel_dist:.1f} mi away"}</Badge>
                                <Badge variant="secondary" className="text-xs">{str(sel["open_spots"] as int) + " open spots"}</Badge>
                                {(sel["wage_hint"] as str) != "" and <Badge variant="secondary" className="text-xs">{sel["wage_hint"] as str}</Badge>}
                            </div>
                            <p className="text-muted-foreground text-xs">📍 {sel["address"] as str}</p>
                        </div>
                    }

                    <div className="flex flex-wrap items-center gap-3">
                        {consent_needed > 0 and
                            <Button onClick={lambda { handle_consent(); }} disabled={acting}>
                                {acting and <Spinner className="size-4 mr-2" /> or <span></span>}
                                Approve & submit application
                            </Button>
                        }
                        {has_selected and
                            <Button variant="outline" onClick={lambda { handle_replan(); }} disabled={acting}>
                                {acting and <Spinner className="size-4 mr-2" /> or <span></span>}
                                Simulate: selected job fills → replan
                            </Button>
                        }
                    </div>
                </CardContent>
            </Card>
        }

        {has_pathway and len(pathway["barriers"] as list) > 0 and
            <Card>
                <CardHeader>
                    <CardTitle>Barriers & matched resources</CardTitle>
                    <CardDescription>What's blocking the participant, and the community resource that resolves each.</CardDescription>
                </CardHeader>
                <CardContent className="flex flex-col gap-2">
                    {for b in (pathway["barriers"] as list) {
                        b_label = b["label"] as str;
                        b_resolved = b["resolved"] as bool;
                        b_res = b["resource"] as dict;
                        r_name = (b_res["name"] as str) if "name" in b_res else "No resource found";
                        r_prov = (b_res["provider"] as str) if "provider" in b_res else "";
                        r_line = r_name;
                        if r_prov != "" {
                            r_line = r_name + " · " + r_prov;
                        }
                        <div key={b_label} className="flex items-center justify-between gap-4 rounded-lg border border-border p-3">
                            <div className="flex items-center gap-2">
                                {b_resolved and <Badge className="text-xs">Resolved</Badge> or <Badge variant="destructive" className="text-xs">Blocked</Badge>}
                                <span className="text-sm font-medium">{b_label}</span>
                            </div>
                            <span className="text-muted-foreground text-xs text-right">{r_line}</span>
                        </div>
                    }}
                </CardContent>
            </Card>
        }

        {has_pathway and
            <Card>
                <CardHeader>
                    <div className="flex items-center justify-between gap-4">
                        <CardTitle>Pathway actions</CardTitle>
                        <div className="flex items-center gap-2 text-xs text-muted-foreground">
                            <Badge className="text-xs">{str(counts["completed"] as int) + " done"}</Badge>
                            <Badge variant="secondary" className="text-xs">{str(counts["pending"] as int) + " pending"}</Badge>
                            <Badge variant="outline" className="text-xs">{str(counts["awaiting_consent"] as int) + " consent"}</Badge>
                            {(counts["blocked"] as int) > 0 and <Badge variant="destructive" className="text-xs">{str(counts["blocked"] as int) + " blocked"}</Badge>}
                            {(counts["failed"] as int) > 0 and <Badge variant="destructive" className="text-xs">{str(counts["failed"] as int) + " failed"}</Badge>}
                        </div>
                    </div>
                </CardHeader>
                <CardContent className="flex flex-col gap-2">
                    {for st in (pathway["steps"] as list) {
                        st_order = st["order"] as int;
                        st_label = st["label"] as str;
                        st_detail = st["detail"] as str;
                        st_status = st["status"] as str;
                        <div key={str(st_order) + st_label} className="flex items-start justify-between gap-4 rounded-lg border border-border p-3">
                            <div className="flex items-start gap-3">
                                <span className="text-muted-foreground text-xs font-mono mt-0.5">{str(st_order)}</span>
                                <div>
                                    <p className="text-sm font-medium">{st_label}</p>
                                    {st_detail != "" and <p className="text-muted-foreground text-xs">{st_detail}</p>}
                                </div>
                            </div>
                            {step_badge(st_status)}
                        </div>
                    }}
                </CardContent>
            </Card>
        }

        {has_pathway and len(pathway["caseworker_tasks"] as list) > 0 and
            <Card className="border-amber-400/50">
                <CardHeader>
                    <CardTitle>Cases requiring human intervention</CardTitle>
                    <CardDescription>Escalated to a caseworker — the agent will not act on these alone.</CardDescription>
                </CardHeader>
                <CardContent className="flex flex-col gap-2">
                    {for t in (pathway["caseworker_tasks"] as list) {
                        t_label = t["label"] as str;
                        t_reason = t["reason"] as str;
                        <div key={t_label} className="flex items-start justify-between gap-4 rounded-lg border border-border p-3">
                            <div>
                                <p className="text-sm font-medium">{t_label}</p>
                                <p className="text-muted-foreground text-xs">{t_reason}</p>
                            </div>
                            <Badge variant="outline" className="text-xs">Pending</Badge>
                        </div>
                    }}
                </CardContent>
            </Card>
        }

        {has_pathway and len(pathway["replan_history"] as list) > 0 and
            <Card>
                <CardHeader>
                    <CardTitle>Replanning history</CardTitle>
                    <CardDescription>What changed, and which completed progress was preserved.</CardDescription>
                </CardHeader>
                <CardContent className="flex flex-col gap-3">
                    {for h in (pathway["replan_history"] as list) {
                        h_from = h["from"] as str;
                        h_to = h["to"] as str;
                        h_reason = h["reason"] as str;
                        h_preserved = h["preserved"] as list;
                        <div key={h_from + h_to} className="rounded-lg border border-border p-3 flex flex-col gap-1">
                            <p className="text-sm font-medium">{h_from + "  →  " + h_to}</p>
                            <p className="text-muted-foreground text-xs">{h_reason}</p>
                            {len(h_preserved) > 0 and <p className="text-muted-foreground text-xs">Preserved: {str(len(h_preserved)) + " completed step(s)"}</p>}
                        </div>
                    }}
                </CardContent>
            </Card>
        }

        {has_pathway and len(pathway["rejected"] as list) > 0 and
            <Card>
                <CardHeader>
                    <CardTitle>Jobs rejected</CardTitle>
                    <CardDescription>Positions the agent evaluated and ruled out, with the reason.</CardDescription>
                </CardHeader>
                <CardContent>
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead>Job</TableHead>
                                <TableHead>Reason rejected</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {for r in (pathway["rejected"] as list) {
                                r_title = r["title"] as str;
                                r_emp = r["employer_name"] as str;
                                r_reason = r["reason"] as str;
                                <TableRow key={r_title}>
                                    <TableCell>
                                        <p className="font-medium">{r_title}</p>
                                        <p className="text-muted-foreground text-xs">{r_emp}</p>
                                    </TableCell>
                                    <TableCell className="text-sm text-muted-foreground">{r_reason}</TableCell>
                                </TableRow>
                            }}
                        </TableBody>
                    </Table>
                </CardContent>
            </Card>
        }

        {has_pathway and
            <Card>
                <CardHeader>
                    <CardTitle>Agent activity log</CardTitle>
                    <CardDescription>Observable actions the agent took — not hidden reasoning.</CardDescription>
                </CardHeader>
                <CardContent>
                    <div className="flex flex-col gap-1.5">
                        {for entry in (pathway["activity_log"] as list) {
                            e_seq = entry["seq"] as int;
                            e_msg = entry["message"] as str;
                            <div key={str(e_seq)} className="flex items-start gap-3 text-sm">
                                <span className="text-muted-foreground text-xs font-mono mt-0.5">{str(e_seq)}</span>
                                <span>{e_msg}</span>
                            </div>
                        }}
                    </div>
                </CardContent>
            </Card>
        }
    </div>;
}
