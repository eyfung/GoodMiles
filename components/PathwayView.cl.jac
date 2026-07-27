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
    api_fleet_state, api_request_ride, api_reset_fleet
}

glob _NEED_OPTIONS: list[dict] = [
    {"value": "food", "label": "Food assistance"},
    {"value": "coaching", "label": "Job coaching"},
    {"value": "health", "label": "Healthcare"},
    {"value": "counseling", "label": "Counseling"},
    {"value": "employment", "label": "Employment services"},
];

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
    return <Badge variant="outline" className="text-xs">{status}</Badge>;
}

def:pub PathwayView() -> JsxElement {
    has pickups: list[dict] = [];
    has destinations: list[dict] = [];
    has fleet: list[dict] = [];
    has requests: list[dict] = [];
    has capacity: dict = {};
    has loading: bool = True;

    has name: str = "";
    has note: str = "";
    has availability: str = "now";
    has has_car: str = "no";
    has need: str = "food";
    has pickup_name: str = "";
    has dest_id: str = "";

    has requesting: bool = False;
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
        } except Exception as e {
            error = str(e);
        }
        loading = False;
    }

    def handle_name_change(e: ChangeEvent) {
        name = e.target.value;
    }

    def handle_note_change(e: ChangeEvent) {
        note = e.target.value;
    }

    def _apply_state(st: dict) {
        fleet = st["fleet"] as list[dict];
        requests = st["requests"] as list[dict];
        capacity = st["capacity"] as dict;
        pickups = st["pickups"] as list[dict];
        destinations = st["destinations"] as list[dict];
    }

    async def handle_request() -> None {
        if name == "" or pickup_name == "" or dest_id == "" {
            return;
        }
        requesting = True;
        error = "";
        plat = 0.0;
        plng = 0.0;
        for pp in pickups {
            if (pp["name"] as str) == pickup_name {
                plat = pp["lat"] as float;
                plng = pp["lng"] as float;
            }
        }
        try {
            data: any = await api_request_ride(name, note, availability, has_car == "yes", need, pickup_name, plat, plng, dest_id);
            st = data as dict;
            if "error" in st {
                error = st["error"] as str;
            } else {
                _apply_state(st);
                current = st["current"] as dict;
                has_current = True;
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
        } except Exception as e {
            error = str(e);
        }
        requesting = False;
    }

    if loading {
        return <div className="p-6">
            <div className="mb-6">
                <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">On-Demand AV as a Social Service</p>
                <h1 className="text-2xl font-semibold tracking-tight mt-1">Pathway</h1>
                <p className="text-muted-foreground text-sm mt-1">Dispatching the autonomous fleet to social-service appointments</p>
            </div>
            <Skeleton className="h-96 w-full" />
        </div>;
    }

    can_request = name != "" and pickup_name != "" and dest_id != "" and not requesting;
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
                    A participant requests a ride to a booked service. The agent dispatches an AV by
                    live fleet capacity and proximity, plans the route, maps every trip, and recommends
                    the best next ride.
                </p>
            </div>
            <div className="flex items-center gap-2">
                <Badge variant="secondary" className="text-xs">{str(cap_free) + " / " + str(cap_total) + " seats free"}</Badge>
                <Button variant="outline" onClick={lambda { handle_reset(); }} disabled={requesting}>Reset fleet</Button>
            </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <Card className="lg:col-span-1">
                <CardHeader>
                    <CardTitle>Ride request</CardTitle>
                    <CardDescription>Participant intake at the community center.</CardDescription>
                </CardHeader>
                <CardContent className="flex flex-col gap-4">
                    <Field>
                        <FieldLabel htmlFor="name">Name</FieldLabel>
                        <Input id="name" value={name} onChange={handle_name_change} placeholder="e.g. Maya" />
                    </Field>
                    <Field>
                        <FieldLabel htmlFor="pickup">Where are you now? (pickup)</FieldLabel>
                        <Select value={pickup_name} onValueChange={lambda (v: str) { pickup_name = v; }}>
                            <SelectTrigger id="pickup"><SelectValue placeholder="Current location..." /></SelectTrigger>
                            <SelectContent>
                                <SelectGroup>
                                    {for pp in pickups {
                                        pp_name = pp["name"] as str;
                                        pp_zone = pp["zone"] as str;
                                        <SelectItem key={pp_name} value={pp_name}>{pp_name}</SelectItem>
                                    }}
                                </SelectGroup>
                            </SelectContent>
                        </Select>
                    </Field>
                    <Field>
                        <FieldLabel htmlFor="dest">Where are you going? (service)</FieldLabel>
                        <Select value={dest_id} onValueChange={lambda (v: str) { dest_id = v; }}>
                            <SelectTrigger id="dest"><SelectValue placeholder="Booked service..." /></SelectTrigger>
                            <SelectContent>
                                <SelectGroup>
                                    {for d in destinations {
                                        d_id = d["id"] as str;
                                        d_service = d["service"] as str;
                                        d_name = d["name"] as str;
                                        <SelectItem key={d_id} value={d_id}>{d_service + " — " + d_name}</SelectItem>
                                    }}
                                </SelectGroup>
                            </SelectContent>
                        </Select>
                    </Field>
                    <Field>
                        <FieldLabel htmlFor="note">Experience feedback (note)</FieldLabel>
                        <Textarea id="note" value={note} onChange={handle_note_change} placeholder="e.g. Needs a wheelchair-accessible vehicle, mornings only" />
                    </Field>
                    <div className="grid grid-cols-2 gap-4">
                        <Field>
                            <FieldLabel htmlFor="avail">Availability</FieldLabel>
                            <Select value={availability} onValueChange={lambda (v: str) { availability = v; }}>
                                <SelectTrigger id="avail"><SelectValue /></SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="now">Now</SelectItem>
                                    <SelectItem value="morning">Morning</SelectItem>
                                    <SelectItem value="afternoon">Afternoon</SelectItem>
                                </SelectContent>
                            </Select>
                        </Field>
                        <Field>
                            <FieldLabel htmlFor="car">Has a car?</FieldLabel>
                            <Select value={has_car} onValueChange={lambda (v: str) { has_car = v; }}>
                                <SelectTrigger id="car"><SelectValue /></SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="no">No</SelectItem>
                                    <SelectItem value="yes">Yes</SelectItem>
                                </SelectContent>
                            </Select>
                        </Field>
                    </div>
                    <Field>
                        <FieldLabel htmlFor="need">What do you need next?</FieldLabel>
                        <Select value={need} onValueChange={lambda (v: str) { need = v; }}>
                            <SelectTrigger id="need"><SelectValue /></SelectTrigger>
                            <SelectContent>
                                <SelectGroup>
                                    {for n in _NEED_OPTIONS {
                                        n_val = n["value"] as str;
                                        n_label = n["label"] as str;
                                        <SelectItem key={n_val} value={n_val}>{n_label}</SelectItem>
                                    }}
                                </SelectGroup>
                            </SelectContent>
                        </Select>
                    </Field>
                    <Button onClick={lambda { handle_request(); }} disabled={not can_request}>
                        {requesting and <Spinner className="size-4 mr-2" /> or <span></span>}
                        {requesting and "Dispatching..." or "Request ride & dispatch"}
                    </Button>
                </CardContent>
            </Card>

            <Card className="lg:col-span-2 overflow-hidden">
                <CardHeader>
                    <CardTitle>Fleet map</CardTitle>
                    <CardDescription>AVs (green idle / blue en-route), pickups (grey), services (amber), and every planned route.</CardDescription>
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
        </div>

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
