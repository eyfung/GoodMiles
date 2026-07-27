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
cl import from "react-leaflet" { MapContainer, TileLayer, CircleMarker, Polyline, Popup }
sv import from "..services.pathway" {
    api_fleet_state, api_ingest_consultation, api_complete_pathway_visit, api_reset_fleet
}

def av_color(status: str) -> str {
    if status == "enroute" {
        return "#3b82f6";
    }
    return "#10b981";
}

def route_color(status: str) -> str {
    if status == "dispatched" {
        return "#3b82f6";
    }
    if status == "queued" {
        return "#ef4444";
    }
    return "#94a3b8";
}

def status_badge(status: str) -> JsxElement {
    if status == "dispatched" {
        return <Badge className="text-xs">Dispatched</Badge>;
    }
    if status == "self_transport" {
        return <Badge variant="secondary" className="text-xs">Self-transport</Badge>;
    }
    if status == "queued" {
        return <Badge variant="destructive" className="text-xs">Queued</Badge>;
    }
    if status == "completed" {
        return <Badge className="bg-emerald-600 text-xs text-white">Completed</Badge>;
    }
    return <Badge variant="outline" className="text-xs">{status}</Badge>;
}

def:pub PathwayView() -> JsxElement {
    has pickups: list[dict] = [];
    has destinations: list[dict] = [];
    has fleet: list[dict] = [];
    has requests: list[dict] = [];
    has capacity: dict = {};
    has scenarios: list[dict] = [];
    has loading: bool = True;

    has scenario_id: str = "";
    has transcript: str = "";
    has interpretation: dict = {};
    has has_interpretation: bool = False;

    has requesting: bool = False;
    has completing: bool = False;
    has completion: dict = {};
    has has_completion: bool = False;
    has current: dict = {};
    has has_current: bool = False;
    has error: str = "";

    async can with entry {
        try {
            data: any = await api_fleet_state();
            st = data as dict;
            fleet = st["fleet"] as list[dict];
            requests = st["requests"] as list[dict];
            capacity = st["capacity"] as dict;
            pickups = st["pickups"] as list[dict];
            destinations = st["destinations"] as list[dict];
            scenarios = st["scenarios"] as list[dict];
        } except Exception as e {
            error = str(e);
        }
        loading = False;
    }

    def _apply_state(st: dict) {
        fleet = st["fleet"] as list[dict];
        requests = st["requests"] as list[dict];
        capacity = st["capacity"] as dict;
        pickups = st["pickups"] as list[dict];
        destinations = st["destinations"] as list[dict];
        scenarios = st["scenarios"] as list[dict];
    }

    def handle_scenario(selected_id: str) {
        scenario_id = selected_id;
        transcript = "";
        interpretation = {};
        has_interpretation = False;
        has_current = False;
        completion = {};
        has_completion = False;
        for scenario in scenarios {
            if (scenario["id"] as str) == selected_id {
                transcript = scenario["transcript"] as str;
            }
        }
    }

    async def handle_ingest() -> None {
        if scenario_id == "" or transcript.strip() == "" {
            return;
        }
        requesting = True;
        error = "";
        try {
            data: any = await api_ingest_consultation(scenario_id, transcript);
            st = data as dict;
            if "error" in st {
                error = st["error"] as str;
            } else {
                _apply_state(st);
                current = st["current"] as dict;
                has_current = True;
                interpretation = st["interpretation"] as dict;
                has_interpretation = True;
            }
        } except Exception as e {
            error = str(e);
        }
        requesting = False;
    }

    async def handle_reset() -> None {
        requesting = True;
        error = "";
        try {
            data: any = await api_reset_fleet();
            st = data as dict;
            _apply_state(st);
            has_current = False;
            current = {};
            interpretation = {};
            has_interpretation = False;
            completion = {};
            has_completion = False;
        } except Exception as e {
            error = str(e);
        }
        requesting = False;
    }

    async def handle_complete_visit() -> None {
        if not has_current {
            return;
        }
        completing = True;
        error = "";
        try {
            data: any = await api_complete_pathway_visit(current["id"] as str);
            result = data as dict;
            if "error" in result {
                error = result["error"] as str;
            } else {
                completion = result;
                has_completion = True;
                state = result["state"] as dict;
                _apply_state(state);
                current = state["current"] as dict;
            }
        } except Exception as e {
            error = str(e);
        }
        completing = False;
    }

    if loading {
        return <div className="p-6">
            <div className="mb-6">
                <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">On-Demand AV as a Social Service</p>
                <h1 className="text-2xl font-semibold tracking-tight mt-1">Pathway</h1>
                <p className="text-muted-foreground text-sm mt-1">Private in-car consultations interpreted into safe service pathways</p>
            </div>
            <Skeleton className="h-96 w-full" />
        </div>;
    }

    can_request = scenario_id != "" and transcript.strip() != "" and not requesting;
    cap_total = (capacity["total"] as int) if "total" in capacity else 0;
    cap_used = (capacity["used"] as int) if "used" in capacity else 0;
    cap_free = (capacity["free"] as int) if "free" in capacity else 0;
    rec: dict = {};
    if has_current and ("next_service" in current) {
        rec = current["next_service"] as dict;
    }

    return <div className="p-6 flex flex-col gap-6">
        <div className="flex items-end justify-between gap-4 flex-wrap">
            <div>
                <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">On-Demand AV as a Social Service</p>
                <h1 className="text-2xl font-semibold tracking-tight mt-1">Pathway</h1>
                <p className="text-muted-foreground text-sm mt-1 max-w-3xl">
                    A private consultation with the in-car avatar becomes structured, consent-scoped information.
                    The interpretation agent identifies needs and wellbeing signals, then allocates a safe route
                    using live service and fleet capacity.
                </p>
            </div>
            <div className="flex items-center gap-2">
                <Badge variant="secondary" className="text-xs">{str(cap_free) + " / " + str(cap_total) + " seats free"}</Badge>
                <Button variant="outline" onClick={lambda { handle_reset(); }} disabled={requesting}>Reset fleet</Button>
            </div>
        </div>

        <Card>
            <CardHeader>
                <div className="flex items-start justify-between gap-4">
                    <div>
                        <CardTitle>Location catalogue</CardTitle>
                        <CardDescription>Approved destinations where points fund access and participation builds transition readiness.</CardDescription>
                    </div>
                    <Badge variant="secondary" className="text-xs">50 start · 150 final review</Badge>
                </div>
            </CardHeader>
            <CardContent>
                <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
                    {for destination in destinations {
                        destination_id = destination["id"] as str;
                        destination_name = destination["name"] as str;
                        destination_category = destination["category"] as str;
                        destination_cost = destination["visit_cost"] as int;
                        destination_reward = destination["points_reward"] as int;
                        destination_free = destination["capacity_free"] as int;
                        destination_total = destination["capacity_total"] as int;
                        <div key={destination_id} className="rounded-xl border border-border bg-background p-4">
                            <div className="flex items-start justify-between gap-3">
                                <div>
                                    <p className="font-semibold">{destination_name}</p>
                                    <p className="mt-1 text-xs text-muted-foreground">{destination_category}</p>
                                </div>
                                <Badge variant="outline" className="text-[10px]">{str(destination_free) + "/" + str(destination_total)}</Badge>
                            </div>
                            <div className="mt-4 flex items-center gap-2 text-xs">
                                <span className="rounded-full bg-rose-50 px-2.5 py-1 font-semibold text-rose-700">{"−" + str(destination_cost) + " cost"}</span>
                                <span className="rounded-full bg-emerald-50 px-2.5 py-1 font-semibold text-emerald-700">{"+" + str(destination_reward) + " earned"}</span>
                            </div>
                        </div>
                    }}
                </div>
            </CardContent>
        </Card>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <Card className="lg:col-span-1">
                <CardHeader>
                    <CardTitle>In-car consultation</CardTitle>
                    <CardDescription>Choose an avatar scenario or edit its raw transcript before ingestion.</CardDescription>
                </CardHeader>
                <CardContent className="flex flex-col gap-4">
                    <div className="rounded-lg border border-emerald-200 bg-emerald-50 p-3 text-xs leading-relaxed text-emerald-900">
                        <span className="font-semibold">Private by design.</span>
                        {" The participant controls what they share. Extracted details are used only for consented service coordination and safe transportation."}
                    </div>
                    <Field>
                        <FieldLabel htmlFor="scenario">Avatar scenario</FieldLabel>
                        <Select value={scenario_id} onValueChange={handle_scenario}>
                            <SelectTrigger id="scenario"><SelectValue placeholder="Choose one of five consultations..." /></SelectTrigger>
                            <SelectContent>
                                <SelectGroup>
                                    {for scenario in scenarios {
                                        scenario_value = scenario["id"] as str;
                                        scenario_title = scenario["title"] as str;
                                        <SelectItem key={scenario_value} value={scenario_value}>{scenario_title}</SelectItem>
                                    }}
                                </SelectGroup>
                            </SelectContent>
                        </Select>
                    </Field>
                    <Field>
                        <div className="flex items-center justify-between gap-2">
                            <FieldLabel htmlFor="transcript">Raw avatar transcript</FieldLabel>
                            <Badge variant="outline" className="text-[10px]">MVP demo · retained</Badge>
                        </div>
                        <Textarea
                            id="transcript"
                            value={transcript}
                            onChange={lambda (e: any) { transcript = e.target.value; }}
                            placeholder="Select a scenario to load its private consultation transcript."
                            className="min-h-72 text-xs leading-relaxed"
                        />
                    </Field>
                    <Button onClick={lambda { handle_ingest(); }} disabled={not can_request}>
                        {requesting and <Spinner className="size-4 mr-2" /> or <span></span>}
                        {requesting and "Interpreting & allocating..." or "Interpret & allocate pathway"}
                    </Button>
                </CardContent>
            </Card>

            <Card className="lg:col-span-2 overflow-hidden">
                <CardHeader>
                    <CardTitle>Interpretation layer</CardTitle>
                    <CardDescription>The agent separates extracted signals from the raw transcript before any allocation decision.</CardDescription>
                </CardHeader>
                <CardContent>
                    {not has_interpretation and
                        <div className="h-[440px] rounded-lg border border-dashed border-border flex items-center justify-center p-8 text-center">
                            <div className="max-w-md">
                                <p className="font-medium">No transcript interpreted yet</p>
                                <p className="mt-1 text-sm text-muted-foreground">Choose a consultation scenario, review the raw transcript, and let the Pathway agent extract only the information needed for coordination.</p>
                            </div>
                        </div>
                    }
                    {has_interpretation and
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                            <div className="rounded-lg border border-border p-4">
                                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Participant & need</p>
                                <p className="mt-2 text-lg font-semibold">{interpretation["participant"] as str}</p>
                                <div className="mt-2 flex flex-wrap gap-2">
                                    <Badge>{interpretation["primary_need"] as str}</Badge>
                                    <Badge variant="secondary">{(interpretation["urgency"] as str) + " urgency"}</Badge>
                                    <Badge variant="outline">{interpretation["availability"] as str}</Badge>
                                    <Badge variant="outline">{interpretation["agent"] as str}</Badge>
                                </div>
                            </div>
                            <div className="rounded-lg border border-border p-4">
                                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Wellbeing signal</p>
                                <p className="mt-2 text-sm font-medium">{interpretation["wellbeing_signal"] as str}</p>
                                <p className="mt-2 text-xs text-muted-foreground">{interpretation["transportation_barrier"] as str}</p>
                            </div>
                            <div className="rounded-lg border border-border p-4 md:col-span-2">
                                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Agent summary</p>
                                <p className="mt-2 text-sm leading-relaxed">{interpretation["summary"] as str}</p>
                            </div>
                            <div className="rounded-lg border border-border p-4">
                                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Extracted evidence</p>
                                <ul className="mt-2 space-y-1.5 text-sm">
                                    {for evidence in interpretation["evidence"] as list {
                                        <li key={evidence as str}>{"• " + (evidence as str)}</li>
                                    }}
                                </ul>
                            </div>
                            <div className="rounded-lg border border-border p-4">
                                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Safety & consent</p>
                                <div className="mt-2 flex flex-wrap gap-2">
                                    {for flag in interpretation["safety_flags"] as list {
                                        <Badge key={flag as str} variant="destructive">{flag as str}</Badge>
                                    }}
                                    {len(interpretation["safety_flags"] as list) == 0 and <Badge variant="secondary">No immediate flags</Badge>}
                                </div>
                                <p className="mt-3 text-xs leading-relaxed text-muted-foreground">{interpretation["consent_scope"] as str}</p>
                            </div>
                            <div className="rounded-lg border border-primary/30 bg-primary/5 p-4 md:col-span-2">
                                <p className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">Allocation output</p>
                                <p className="mt-2 text-sm font-medium">{(interpretation["pickup_name"] as str) + " → " + (interpretation["recommended_service"] as str)}</p>
                                <p className="mt-1 text-xs text-muted-foreground">{interpretation["allocation_reason"] as str}</p>
                                <div className="mt-3 flex flex-wrap gap-2">
                                    <Badge variant="secondary">{(interpretation["recommended_location_category"] as str)}</Badge>
                                    <Badge variant="outline">{"−" + str(interpretation["visit_cost"] as int) + " cost"}</Badge>
                                    <Badge className="bg-emerald-600 text-white">{"+" + str(interpretation["points_reward"] as int) + " earned"}</Badge>
                                </div>
                            </div>
                        </div>
                    }
                </CardContent>
            </Card>
        </div>

        <Card className="overflow-hidden">
            <CardHeader>
                <CardTitle>Pathway route & fleet map</CardTitle>
                <CardDescription>Interpretation outputs feed the combined optimization and dispatch layer using live capacity and proximity.</CardDescription>
            </CardHeader>
            <CardContent>
                    <div className="h-[440px] w-full rounded-lg overflow-hidden border border-border">
                        <MapContainer center={[37.762, -122.42]} zoom={12} style={{"height": "100%", "width": "100%"}} scrollWheelZoom={False}>
                            <TileLayer
                                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                                attribution="&copy; OpenStreetMap contributors"
                            />
                            {for r in requests {
                                r_id = r["id"] as str;
                                r_route = r["route"] as list;
                                r_status = r["status"] as str;
                                <Polyline key={"route-" + r_id} positions={r_route} pathOptions={{"color": route_color(r_status), "weight": 4, "opacity": 0.7}} />
                            }}
                            {for d in destinations {
                                d_id = d["id"] as str;
                                d_lat = d["lat"] as float;
                                d_lng = d["lng"] as float;
                                d_service = d["service"] as str;
                                d_name = d["name"] as str;
                                <CircleMarker key={"dest-" + d_id} center={[d_lat, d_lng]} radius={8} pathOptions={{"color": "#f59e0b", "fillColor": "#f59e0b", "fillOpacity": 0.85}}>
                                    <Popup>{d_service + " — " + d_name}</Popup>
                                </CircleMarker>
                            }}
                            {for pp in pickups {
                                pp_name = pp["name"] as str;
                                pp_lat = pp["lat"] as float;
                                pp_lng = pp["lng"] as float;
                                <CircleMarker key={"pick-" + pp_name} center={[pp_lat, pp_lng]} radius={6} pathOptions={{"color": "#64748b", "fillColor": "#94a3b8", "fillOpacity": 0.8}}>
                                    <Popup>{"Pickup — " + pp_name}</Popup>
                                </CircleMarker>
                            }}
                            {for v in fleet {
                                v_name = v["name"] as str;
                                v_lat = v["lat"] as float;
                                v_lng = v["lng"] as float;
                                v_status = v["status"] as str;
                                v_free = v["seats_free"] as int;
                                v_total = v["seats_total"] as int;
                                <CircleMarker key={"av-" + v_name} center={[v_lat, v_lng]} radius={10} pathOptions={{"color": av_color(v_status), "fillColor": av_color(v_status), "fillOpacity": 0.9}}>
                                    <Popup>{v_name + " · " + str(v_free) + "/" + str(v_total) + " seats free · " + v_status}</Popup>
                                </CircleMarker>
                            }}
                        </MapContainer>
                    </div>
            </CardContent>
        </Card>

        {error != "" and
            <div className="rounded-lg border border-destructive/50 bg-destructive/10 p-4 text-destructive text-sm">
                {error}
            </div>
        }

        {has_current and
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <Card className="border-primary/40">
                    <CardHeader>
                        <div className="flex items-center justify-between gap-4">
                            <CardTitle>Dispatch for {current["participant"] as str}</CardTitle>
                            {status_badge(current["status"] as str)}
                        </div>
                        <CardDescription>{current["decision"] as str}</CardDescription>
                    </CardHeader>
                    <CardContent className="flex flex-col gap-2">
                        <p className="text-sm">
                            <span className="text-muted-foreground">Trip: </span>
                            {(current["pickup_name"] as str) + "  →  " + (current["dest_service"] as str) + " (" + (current["dest_name"] as str) + ")"}
                        </p>
                        <div className="flex flex-wrap items-center gap-2">
                            {(current["av_name"] as str) != "" and <Badge className="text-xs">{current["av_name"] as str}</Badge>}
                            <Badge variant="secondary" className="text-xs">{f"{current['distance_miles'] as float:.1f} mi"}</Badge>
                            <Badge variant="secondary" className="text-xs">{str(current["eta_min"] as int) + " min ETA"}</Badge>
                            <Badge variant="outline" className="text-xs">{current["upskill_category"] as str}</Badge>
                        </div>
                        <div className="mt-2 flex items-center justify-between gap-3 rounded-lg bg-muted/50 p-3">
                            <div className="text-xs">
                                <span className="font-semibold text-rose-700">{"−" + str(current["visit_cost"] as int) + " cost"}</span>
                                <span className="mx-2 text-muted-foreground">·</span>
                                <span className="font-semibold text-emerald-700">{"+" + str(current["points_reward"] as int) + " earned"}</span>
                            </div>
                            {not (current["completed"] as bool) and
                                <Button size="sm" onClick={lambda { handle_complete_visit(); }} disabled={completing}>
                                    {completing and "Completing..." or "Complete visit"}
                                </Button>
                            }
                        </div>
                    </CardContent>
                </Card>

                {len(rec) > 0 and
                    <Card>
                        <CardHeader>
                            <CardTitle>Recommended next ride</CardTitle>
                            <CardDescription>Based on what {current["participant"] as str} needs next.</CardDescription>
                        </CardHeader>
                        <CardContent className="flex flex-col gap-2">
                            <p className="text-lg font-semibold">{(rec["service"] as str) + " — " + (rec["name"] as str)}</p>
                            <p className="text-sm text-muted-foreground">{rec["reason"] as str}</p>
                            <Badge variant="secondary" className="text-xs w-fit">{f"{rec['distance_miles'] as float:.1f} mi from destination"}</Badge>
                        </CardContent>
                    </Card>
                }
            </div>
        }

        {has_completion and
            <Card className="border-emerald-300 bg-emerald-50">
                <CardContent className="flex flex-col gap-2 p-5 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <p className="font-semibold text-emerald-900">Visit completed and points applied</p>
                        <p className="mt-1 text-sm text-emerald-800">
                            {(completion["participant"] as str) + " now has " + str(completion["new_balance"] as int) + " points (" + ("+" if (completion["net_points"] as int) > 0 else "") + str(completion["net_points"] as int) + " net)."}
                        </p>
                    </div>
                    {(completion["transition_status"] as str) == "ready_for_review" and
                        <Badge className="w-fit bg-amber-500 text-white">Ready for human review</Badge>
                    }
                </CardContent>
            </Card>
        }

        <Card>
            <CardHeader>
                <CardTitle>Fleet status</CardTitle>
                <CardDescription>{str(cap_used) + " of " + str(cap_total) + " seats in use across " + str(len(fleet)) + " vehicles."}</CardDescription>
            </CardHeader>
            <CardContent>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                    {for v in fleet {
                        v_name = v["name"] as str;
                        v_status = v["status"] as str;
                        v_used = v["seats_used"] as int;
                        v_total = v["seats_total"] as int;
                        v_zone = v["zone"] as str;
                        <div key={v_name} className="rounded-lg border border-border p-3 flex flex-col gap-1.5">
                            <div className="flex items-center justify-between">
                                <span className="font-medium text-sm">{v_name}</span>
                                {v_status == "enroute" and <Badge className="text-xs">En route</Badge> or <Badge variant="secondary" className="text-xs">Idle</Badge>}
                            </div>
                            <span className="text-muted-foreground text-xs capitalize">{v_zone + " zone"}</span>
                            <span className="text-sm">{str(v_used) + " / " + str(v_total) + " seats used"}</span>
                        </div>
                    }}
                </div>
            </CardContent>
        </Card>

        {len(requests) > 0 and
            <Card>
                <CardHeader>
                    <CardTitle>All ride requests</CardTitle>
                    <CardDescription>Every pathway the agent is currently coordinating.</CardDescription>
                </CardHeader>
                <CardContent>
                    <Table>
                        <TableHeader>
                            <TableRow>
                                <TableHead>Participant</TableHead>
                                <TableHead>Trip</TableHead>
                                <TableHead>AV</TableHead>
                                <TableHead className="text-right">Distance</TableHead>
                                <TableHead className="text-right">ETA</TableHead>
                                <TableHead className="text-right">Status</TableHead>
                            </TableRow>
                        </TableHeader>
                        <TableBody>
                            {for r in requests {
                                r_id = r["id"] as str;
                                r_part = r["participant"] as str;
                                r_pick = r["pickup_name"] as str;
                                r_dest = r["dest_service"] as str;
                                r_av = r["av_name"] as str;
                                r_dist = r["distance_miles"] as float;
                                r_eta = r["eta_min"] as int;
                                r_status = r["status"] as str;
                                <TableRow key={r_id}>
                                    <TableCell className="font-medium">{r_part}</TableCell>
                                    <TableCell className="text-sm text-muted-foreground">{r_pick + " → " + r_dest}</TableCell>
                                    <TableCell className="text-sm">{r_av if r_av != "" else "—"}</TableCell>
                                    <TableCell className="text-right text-sm">{f"{r_dist:.1f} mi"}</TableCell>
                                    <TableCell className="text-right text-sm">{str(r_eta) + " min"}</TableCell>
                                    <TableCell className="text-right">{status_badge(r_status)}</TableCell>
                                </TableRow>
                            }}
                        </TableBody>
                    </Table>
                </CardContent>
            </Card>
        }
    </div>;
}
