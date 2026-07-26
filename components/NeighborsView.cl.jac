import from ".ui.button" { Button }
import from ".ui.select" { Select, SelectTrigger, SelectContent, SelectGroup, SelectItem, SelectValue }
import from ".ui.table" { Table, TableHeader, TableBody, TableRow, TableHead, TableCell }
import from ".ui.skeleton" { Skeleton }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Search01Icon,
    Add01Icon,
    PencilEdit01Icon,
    Delete02Icon,
    UnfoldMoreIcon
}
sv import from "..services.goodmiles" { api_neighbors, api_add_neighbor, api_delete_neighbor }

def:pub NeighborsView() -> JsxElement {
    has neighbors: list[dict] = [];
    has loading: bool = True;
    has error: str = "";
    has search: str = "";
    has selected_zone: str = "all";
    has show_add: bool = False;
    has new_name: str = "";
    has new_zone: str = "";
    has adding: bool = False;
    has form_error: str = "";
    has deleting_id: str = "";
    has wellbeing_person: str = "";
    has wellbeing_history: list[dict] = [];

    async can with entry {
        try {
            data: any = await api_neighbors();
            neighbors = data as list[dict];
        } except Exception as e {
            error = str(e);
        }
        loading = False;
    }

    def open_add(_e: MouseEvent) {
        new_name = "";
        new_zone = "";
        form_error = "";
        show_add = True;
    }

    def close_add(_e: MouseEvent) {
        if not adding {
            show_add = False;
        }
    }

    def update_new_name(e: ChangeEvent) {
        new_name = e.target.value;
    }

    async def submit_person(e: FormEvent) -> None {
        e.preventDefault();
        if new_name.strip() == "" {
            form_error = "Enter a name.";
            return;
        }
        if new_zone == "" {
            form_error = "Select a region.";
            return;
        }
        adding = True;
        form_error = "";
        try {
            data: any = await api_add_neighbor(new_name, new_zone);
            result = data as dict;
            if "error" in result {
                form_error = result["error"] as str;
            } else {
                refreshed: any = await api_neighbors();
                neighbors = refreshed as list[dict];
                show_add = False;
                new_name = "";
                new_zone = "";
            }
        } except Exception as ex {
            form_error = str(ex);
        }
        adding = False;
    }

    async def delete_person(person_id: str, person_name: str) -> None {
        if not confirm("Delete " + person_name + "? This cannot be undone.") {
            return;
        }
        deleting_id = person_id;
        error = "";
        try {
            data: any = await api_delete_neighbor(person_id);
            result = data as dict;
            if "error" in result {
                error = result["error"] as str;
            } else {
                neighbors = [n for n in neighbors if (n["id"] as str) != person_id];
            }
        } except Exception as ex {
            error = str(ex);
        }
        deleting_id = "";
    }

    def open_wellbeing(person_name: str, history: list[dict]) {
        wellbeing_person = person_name;
        wellbeing_history = history;
    }

    def close_wellbeing(_e: MouseEvent) {
        wellbeing_person = "";
        wellbeing_history = [];
    }

    def feeling_class(feeling: str) -> str {
        if feeling == "Great" {
            return "bg-emerald-100 text-emerald-800";
        }
        elif feeling == "Good" {
            return "bg-lime-100 text-lime-800";
        }
        elif feeling == "Okay" {
            return "bg-amber-100 text-amber-800";
        }
        elif feeling == "Struggling" {
            return "bg-orange-100 text-orange-800";
        }
        elif feeling == "Distressed" {
            return "bg-rose-100 text-rose-800";
        }
        return "bg-muted text-muted-foreground";
    }

    visible_neighbors: list[dict] = [];
    not_started_count = 0;
    in_progress_count = 0;
    completed_count = 0;
    query = search.lower();
    for n in neighbors {
        person_name = n["name"] as str;
        person_zone = n["home_zone"] as str;
        person_balance = n["points_balance"] as int;
        if person_balance <= 50 {
            not_started_count = not_started_count + 1;
        }
        elif person_balance >= 150 {
            completed_count = completed_count + 1;
        }
        else {
            in_progress_count = in_progress_count + 1;
        }
        matches_search = query == "" or query in person_name.lower();
        matches_zone = selected_zone == "all" or person_zone == selected_zone;
        if matches_search and matches_zone {
            visible_neighbors = visible_neighbors + [n];
        }
    }

    return <div className="p-6 lg:p-8 min-h-full">
        <div className="flex flex-col gap-5 lg:flex-row lg:items-start lg:justify-between mb-6">
            <div>
                <h1 className="text-3xl font-semibold tracking-tight">People</h1>
                <p className="text-muted-foreground text-sm mt-1.5">Everyone in the mobility program, in one place.</p>
            </div>
            <div className="flex flex-col sm:flex-row gap-3 w-full lg:w-auto">
                <div className="relative sm:w-72">
                    <HugeiconsIcon
                        icon={Search01Icon}
                        strokeWidth={2}
                        className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground pointer-events-none"
                    />
                    <input
                        type="search"
                        value={search}
                        onChange={lambda (e: any) { search = e.target.value; }}
                        placeholder="Search people..."
                        aria-label="Search people"
                        className="h-10 w-full rounded-lg border border-input bg-background pl-9 pr-3 text-sm outline-none transition-shadow placeholder:text-muted-foreground focus:border-primary focus:ring-2 focus:ring-primary/15"
                    />
                </div>
                <Select value={selected_zone} onValueChange={lambda (v: str) { selected_zone = v; }}>
                    <SelectTrigger className="h-10 w-full sm:w-40">
                        <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectGroup>
                            <SelectItem value="all">All zones</SelectItem>
                            <SelectItem value="north">North</SelectItem>
                            <SelectItem value="central">Central</SelectItem>
                            <SelectItem value="south">South</SelectItem>
                        </SelectGroup>
                    </SelectContent>
                </Select>
                <Button className="h-10 px-4" title="Add a person (name and home zone only)" onClick={open_add}>
                    <HugeiconsIcon icon={Add01Icon} strokeWidth={2} className="size-4" />
                    Add Person
                </Button>
            </div>
        </div>

        {not loading and error == "" and
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-6">
                <div className="rounded-xl border border-amber-300 bg-amber-100 p-4">
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-sm font-medium text-amber-900">Not started</p>
                            <p className="text-xs text-amber-700 mt-1">50 points</p>
                        </div>
                        <span className="text-2xl font-semibold text-amber-700">{str(not_started_count)}</span>
                    </div>
                </div>
                <div className="rounded-xl border border-lime-300 bg-lime-100 p-4">
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-sm font-medium text-lime-900">In progress</p>
                            <p className="text-xs text-lime-700 mt-1">51–149 points</p>
                        </div>
                        <span className="text-2xl font-semibold text-lime-700">{str(in_progress_count)}</span>
                    </div>
                </div>
                <div className="rounded-xl border border-emerald-300 bg-emerald-100 p-4">
                    <div className="flex items-center justify-between">
                        <div>
                            <p className="text-sm font-medium text-emerald-900">Completed</p>
                            <p className="text-xs text-emerald-700 mt-1">150 points or more</p>
                        </div>
                        <span className="text-2xl font-semibold text-emerald-700">{str(completed_count)}</span>
                    </div>
                </div>
            </div>
        }

        {error != "" and
            <div className="rounded-lg border border-destructive/50 bg-destructive/10 p-4 text-destructive text-sm">
                Failed to load people: {error}
            </div>
        }

        {error == "" and
            <div className="rounded-lg border border-border overflow-hidden min-h-[430px]">
                <Table>
                    <TableHeader>
                        <TableRow className="hover:bg-transparent">
                            <TableHead className="h-12 px-4">Upskilling Progress</TableHead>
                            <TableHead className="h-12 px-4">
                                <span className="inline-flex items-center gap-1.5">Name <HugeiconsIcon icon={UnfoldMoreIcon} strokeWidth={2} className="size-3.5 text-muted-foreground" /></span>
                            </TableHead>
                            <TableHead className="h-12 px-4">
                                <span className="inline-flex items-center gap-1.5">Home Zone <HugeiconsIcon icon={UnfoldMoreIcon} strokeWidth={2} className="size-3.5 text-muted-foreground" /></span>
                            </TableHead>
                            <TableHead className="h-12 w-24 px-2 text-center text-xs">
                                <span className="inline-flex items-center justify-center gap-1 leading-tight whitespace-normal">Points Balance <HugeiconsIcon icon={UnfoldMoreIcon} strokeWidth={2} className="size-3.5 text-muted-foreground shrink-0" /></span>
                            </TableHead>
                            <TableHead className="h-12 w-24 px-2 text-center text-xs">
                                <span className="inline-flex items-center justify-center gap-1 leading-tight whitespace-normal">Points Earned <HugeiconsIcon icon={UnfoldMoreIcon} strokeWidth={2} className="size-3.5 text-muted-foreground shrink-0" /></span>
                            </TableHead>
                            <TableHead className="h-12 w-24 px-2 text-center text-xs">
                                <span className="inline-flex items-center justify-center gap-1 leading-tight whitespace-normal">Points Spent <HugeiconsIcon icon={UnfoldMoreIcon} strokeWidth={2} className="size-3.5 text-muted-foreground shrink-0" /></span>
                            </TableHead>
                            <TableHead className="h-12 w-24 px-2 text-center text-xs">
                                <span className="inline-flex items-center justify-center gap-1 leading-tight whitespace-normal">Net Gained <HugeiconsIcon icon={UnfoldMoreIcon} strokeWidth={2} className="size-3.5 text-muted-foreground shrink-0" /></span>
                            </TableHead>
                            <TableHead className="h-12 px-4">Wellbeing</TableHead>
                            <TableHead className="h-12 px-4 text-center">Actions</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {loading and
                            <TableRow>
                                <TableCell className="h-16 px-4"><Skeleton className="h-4 w-24" /></TableCell>
                                <TableCell className="h-16 px-4"><Skeleton className="h-4 w-20" /></TableCell>
                                <TableCell className="h-16 px-4"><Skeleton className="h-4 w-20" /></TableCell>
                                <TableCell className="h-16 px-4"><Skeleton className="h-4 w-20" /></TableCell>
                                <TableCell className="h-16 px-4"><Skeleton className="h-4 w-20" /></TableCell>
                                <TableCell className="h-16 px-4"><Skeleton className="h-4 w-20" /></TableCell>
                                <TableCell className="h-16 px-4"><Skeleton className="h-4 w-20" /></TableCell>
                                <TableCell className="h-16 px-4"><Skeleton className="h-4 w-20" /></TableCell>
                                <TableCell className="h-16 px-4"><Skeleton className="h-4 w-20" /></TableCell>
                            </TableRow>
                        }
                        {for n in visible_neighbors {
                            id_str = n["id"] as str;
                            name_str = n["name"] as str;
                            zone_str = n["home_zone"] as str;
                            balance = n["points_balance"] as int;
                            earned = n["points_earned"] as int;
                            spent = n["points_spent"] as int;
                            progress = n["upskill_progress"] as int;
                            progress_label = "Not started" if balance <= 50 else ("Completed" if balance >= 150 else "In progress");
                            progress_detail = str(balance) + " current points";
                            progress_color = "bg-amber-300";
                            if progress >= 75 {
                                progress_color = "bg-emerald-600";
                            }
                            elif progress >= 50 {
                                progress_color = "bg-lime-500";
                            }
                            elif progress >= 25 {
                                progress_color = "bg-yellow-400";
                            }
                            net_gained = earned - spent;
                            net_class = "w-24 px-2 text-center font-medium " + ("text-emerald-600" if net_gained >= 0 else "text-rose-600");
                            history = n["wellbeing_history"] as list[dict];
                            <TableRow key={id_str} className="h-16">
                                <TableCell className="px-4">
                                    <div className="w-44">
                                        <div className="flex items-center justify-between gap-2 mb-1.5">
                                            <span className="text-xs font-medium">{progress_label}</span>
                                            <span className="text-xs text-muted-foreground">{str(progress)}%</span>
                                        </div>
                                        <div className="h-1.5 rounded-full bg-muted overflow-hidden">
                                            <div
                                                className={"h-full rounded-full transition-all " + progress_color}
                                                style={{"width": str(progress) + "%"}}
                                            />
                                        </div>
                                        <p className="mt-1.5 text-[11px] text-muted-foreground whitespace-normal leading-tight">{progress_detail}</p>
                                    </div>
                                </TableCell>
                                <TableCell className="px-4 font-medium">{name_str}</TableCell>
                                <TableCell className="px-4 capitalize">{zone_str}</TableCell>
                                <TableCell className="w-24 px-2 text-center">{str(balance)}</TableCell>
                                <TableCell className="w-24 px-2 text-center">{str(earned)}</TableCell>
                                <TableCell className="w-24 px-2 text-center">{str(spent)}</TableCell>
                                <TableCell className={net_class}>{("+" if net_gained > 0 else "") + str(net_gained)}</TableCell>
                                <TableCell className="px-4">
                                    <Button
                                        variant="outline"
                                        size="sm"
                                        onClick={lambda { open_wellbeing(name_str, history); }}
                                        title={"View " + name_str + "'s wellbeing history"}
                                    >
                                        View
                                    </Button>
                                </TableCell>
                                <TableCell className="px-4">
                                    <div className="flex items-center justify-center gap-1">
                                        <Button variant="ghost" size="icon-sm" title={"Edit " + name_str + " name or home zone"}>
                                            <HugeiconsIcon icon={PencilEdit01Icon} strokeWidth={2} className="size-4" />
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            size="icon-sm"
                                            className="text-destructive hover:text-destructive"
                                            title={"Delete " + name_str}
                                            disabled={deleting_id != ""}
                                            onClick={lambda { delete_person(id_str, name_str); }}
                                        >
                                            <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-4" />
                                        </Button>
                                    </div>
                                </TableCell>
                            </TableRow>
                        }}
                        {not loading and len(visible_neighbors) == 0 and
                            <TableRow>
                                <TableCell colSpan={9} className="h-32 text-center text-muted-foreground">
                                    No people match this search and zone.
                                </TableCell>
                            </TableRow>
                        }
                    </TableBody>
                </Table>
            </div>
        }

        {show_add and
            <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/35 p-4">
                <div className="w-full max-w-md rounded-xl border border-border bg-background p-6 shadow-xl">
                    <div className="mb-5">
                        <h2 className="text-xl font-semibold">Add Person</h2>
                        <p className="text-sm text-muted-foreground mt-1">New people automatically start with 50 points.</p>
                    </div>
                    <form onSubmit={submit_person} className="space-y-4">
                        <div>
                            <label htmlFor="person-name" className="text-sm font-medium">Name</label>
                            <input
                                id="person-name"
                                value={new_name}
                                onChange={update_new_name}
                                placeholder="Enter their name"
                                autoFocus={True}
                                className="mt-1.5 h-10 w-full rounded-lg border border-input bg-background px-3 text-sm outline-none focus:border-primary focus:ring-2 focus:ring-primary/15"
                            />
                        </div>
                        <div>
                            <label className="text-sm font-medium">Region</label>
                            <Select value={new_zone} onValueChange={lambda (v: str) { new_zone = v; }}>
                                <SelectTrigger className="mt-1.5 h-10 w-full">
                                    <SelectValue placeholder="Select a region" />
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectGroup>
                                        <SelectItem value="north">North</SelectItem>
                                        <SelectItem value="central">Central</SelectItem>
                                        <SelectItem value="south">South</SelectItem>
                                    </SelectGroup>
                                </SelectContent>
                            </Select>
                        </div>
                        {form_error != "" and <p className="text-sm text-destructive">{form_error}</p>}
                        <div className="flex justify-end gap-2 pt-2">
                            <Button type="button" variant="outline" onClick={close_add} disabled={adding}>Cancel</Button>
                            <Button type="submit" disabled={adding}>{("Adding..." if adding else "Add Person")}</Button>
                        </div>
                    </form>
                </div>
            </div>
        }

        {wellbeing_person != "" and
            <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/35 p-4">
                <div className="w-full max-w-2xl rounded-xl border border-border bg-background p-6 shadow-xl">
                    <div className="flex items-start justify-between gap-4 mb-5">
                        <div>
                            <div className="flex items-center gap-2">
                                <h2 className="text-xl font-semibold">{wellbeing_person}</h2>
                                <span className="rounded-full bg-muted px-2.5 py-1 text-xs font-medium text-muted-foreground">
                                    {str(len(wellbeing_history)) + (" session" if len(wellbeing_history) == 1 else " sessions")}
                                </span>
                            </div>
                            <p className="text-sm text-muted-foreground mt-1">Session history, point impact, and recorded feelings.</p>
                        </div>
                        <Button variant="ghost" size="sm" onClick={close_wellbeing}>Close</Button>
                    </div>
                    {len(wellbeing_history) == 0 and
                        <div className="rounded-lg bg-muted/50 py-10 text-center text-sm text-muted-foreground">
                            No completed sessions yet.
                        </div>
                    }
                    {len(wellbeing_history) > 0 and
                        <div className="max-h-[420px] overflow-y-auto rounded-lg border border-border">
                            {for (session_index, session) in enumerate(wellbeing_history) {
                                session_stop = session["stop"] as str;
                                session_feeling = session["feeling"] as str;
                                session_net = session["net"] as int;
                                <div key={session["id"] as str} className="flex items-center justify-between gap-4 border-b border-border last:border-b-0 p-4">
                                    <div>
                                        <p className="text-sm font-medium">{session_stop}</p>
                                        <p className="text-xs text-muted-foreground mt-1">{"Session " + str(session_index + 1)}</p>
                                    </div>
                                    <div className="flex items-center gap-3">
                                        <span className={"rounded-full px-2.5 py-1 text-xs font-medium " + feeling_class(session_feeling)}>
                                            {session_feeling}
                                        </span>
                                        <span className={"text-sm font-medium " + ("text-emerald-600" if session_net >= 0 else "text-rose-600")}>
                                            {("+" if session_net > 0 else "") + str(session_net) + " pts"}
                                        </span>
                                    </div>
                                </div>
                            }}
                        </div>
                    }
                </div>
            </div>
        }
    </div>;
}
