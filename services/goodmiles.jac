# GoodMiles — Graph nodes, seed data, allocation engine, API endpoints

# ===========================
# Node definitions
# ===========================

node Neighbor {
    has name: str;
    has points_balance: int;
    has home_zone: str;
    has points_earned: int = 0;
    has points_spent: int = 0;
    has points_initialized: bool = False;
}

node ServiceStop {
    has name: str;
    has stop_type: str;
    has zone: str;
    has base_cost: int;
    has bonus_on_visit: int;
}

node Trip {
    has trip_id: str;
    has neighbor_name: str;
    has stop_name: str;
    has cost: int;
    has bonus: int;
    has feeling: str = "Not recorded";
    has notes: str = "";
}

node Seeded {
    has done: bool = True;
}

# ===========================
# Seed data (idempotent) — called once at server boot
# ===========================

def seed_demo_data {
    existing = [root-->][?:Seeded];
    if len(existing) > 0 {
        return;
    }
    root ++> Seeded();

    root ++> ServiceStop(name="River Pantry", stop_type="pantry", zone="north", base_cost=20, bonus_on_visit=0);
    root ++> ServiceStop(name="Career Hub", stop_type="coaching", zone="north", base_cost=10, bonus_on_visit=15);
    root ++> ServiceStop(name="Wellness Center", stop_type="counseling", zone="central", base_cost=10, bonus_on_visit=20);
    root ++> ServiceStop(name="Community Health", stop_type="health", zone="south", base_cost=15, bonus_on_visit=10);
    root ++> ServiceStop(name="Jobs Office", stop_type="jobs", zone="south", base_cost=15, bonus_on_visit=25);

    root ++> Neighbor(name="Alex", points_balance=50, home_zone="north", points_initialized=True);
    root ++> Neighbor(name="Jordan", points_balance=50, home_zone="south", points_initialized=True);
    root ++> Neighbor(name="Morgan", points_balance=50, home_zone="central", points_initialized=True);
    root ++> Neighbor(name="Riley", points_balance=50, home_zone="north", points_initialized=True);
}

# ===========================
# Helpers
# ===========================

def get_all_neighbors() -> list[Neighbor] {
    return [root-->][?:Neighbor];
}

def get_all_stops() -> list[ServiceStop] {
    return [root-->][?:ServiceStop];
}

def get_neighbor(name: str) -> Neighbor | None {
    for n in get_all_neighbors() {
        if n.name == name {
            return n;
        }
    }
    return None;
}

def get_stop(name: str) -> ServiceStop | None {
    for s in get_all_stops() {
        if s.name == name {
            return s;
        }
    }
    return None;
}

def initialize_starting_points {
    for n in get_all_neighbors() {
        if not n.points_initialized {
            n.points_balance = 50;
            n.points_earned = 0;
            n.points_spent = 0;
            n.points_initialized = True;
        }
    }
}

# ===========================
# Public API endpoints
# ===========================

def:pub api_neighbors() -> list[dict] {
    seed_demo_data();
    initialize_starting_points();
    result: list[dict] = [];
    for n in get_all_neighbors() {
        upskill_progress = n.points_balance - 50;
        if upskill_progress < 0 {
            upskill_progress = 0;
        }
        if upskill_progress > 100 {
            upskill_progress = 100;
        }
        wellbeing_history: list[dict] = [];
        for t in [root-->][?:Trip] {
            if t.neighbor_name == n.name {
                wellbeing_history = wellbeing_history + [{
                    "id": jid(t),
                    "stop": t.stop_name,
                    "cost": t.cost,
                    "bonus": t.bonus,
                    "net": t.bonus - t.cost,
                    "feeling": t.feeling,
                    "notes": getattr(t, "notes", "")
                }];
            }
        }
        result = result + [{
            "id": jid(n),
            "name": n.name,
            "points_balance": n.points_balance,
            "points_earned": n.points_earned,
            "points_spent": n.points_spent,
            "home_zone": n.home_zone,
            "upskill_progress": upskill_progress,
            "wellbeing_history": wellbeing_history
        }];
    }
    return result;
}

def:pub api_add_neighbor(name: str, home_zone: str) -> dict {
    seed_demo_data();
    initialize_starting_points();

    clean_name = name.strip();
    clean_zone = home_zone.lower();
    if clean_name == "" {
        return {"error": "Name is required"};
    }
    if clean_zone not in ["north", "central", "south"] {
        return {"error": "Select a valid region"};
    }
    for n in get_all_neighbors() {
        if n.name.lower() == clean_name.lower() {
            return {"error": "A person with this name already exists"};
        }
    }

    person = root ++> Neighbor(
        name=clean_name,
        points_balance=50,
        home_zone=clean_zone,
        points_initialized=True
    );
    return {
        "id": jid(person),
        "name": person.name,
        "points_balance": person.points_balance,
        "points_earned": person.points_earned,
        "points_spent": person.points_spent,
        "home_zone": person.home_zone
    };
}

def:pub api_delete_neighbor(person_id: str) -> dict {
    for n in get_all_neighbors() {
        if jid(n) == person_id {
            removed_name = n.name;
            deleted_trips = 0;
            for t in [root-->][?:Trip] {
                if t.neighbor_name == removed_name {
                    del t;
                    deleted_trips = deleted_trips + 1;
                }
            }
            del n;
            return {
                "status": "deleted",
                "name": removed_name,
                "deleted_trip_records": deleted_trips
            };
        }
    }
    return {"error": "Person not found"};
}

def:pub api_stops() -> list[dict] {
    result: list[dict] = [];
    for s in get_all_stops() {
        result = result + [{
            "id": jid(s),
            "name": s.name,
            "stop_type": s.stop_type,
            "zone": s.zone,
            "base_cost": s.base_cost,
            "bonus_on_visit": s.bonus_on_visit
        }];
    }
    return result;
}

def:pub api_optimize(neighbor_name: str) -> dict {
    seed_demo_data();
    initialize_starting_points();
    n = get_neighbor(neighbor_name);
    if n == None {
        return {"error": "Neighbor not found"};
    }

    all_stops = get_all_stops();
    budget = n.points_balance;
    candidates: list[dict] = [];

    for s in all_stops {
        cost = s.base_cost;
        bonus = s.bonus_on_visit;
        ratio = (bonus + 1.0) / (cost + 1.0);
        candidates = candidates + [{"stop_name": s.name, "stop_type": s.stop_type, "zone": s.zone, "cost": cost, "bonus": bonus, "ratio": ratio}];
    }

    # Bubble sort by ratio descending
    i = 0;
    while i < len(candidates) {
        j = i + 1;
        while j < len(candidates) {
            if candidates[j]["ratio"] > candidates[i]["ratio"] {
                tmp = candidates[i];
                candidates[i] = candidates[j];
                candidates[j] = tmp;
            }
            j = j + 1;
        }
        i = i + 1;
    }

    plan: list[dict] = [];
    total_cost = 0;
    total_bonus = 0;

    for c in candidates {
        c_cost = c["cost"] as int;
        c_bonus = c["bonus"] as int;
        if total_cost + c_cost <= budget {
            plan = plan + [{"stop": c["stop_name"], "stop_type": c["stop_type"], "zone": c["zone"], "cost": c_cost, "bonus": c_bonus}];
            total_cost = total_cost + c_cost;
            total_bonus = total_bonus + c_bonus;
        }
    }

    remaining = budget - total_cost + total_bonus;

    return {
        "neighbor": n.name,
        "balance": n.points_balance,
        "home_zone": n.home_zone,
        "route_plan": plan,
        "total_cost": total_cost,
        "total_bonus": total_bonus,
        "remaining": remaining
    };
}

def:pub api_execute(neighbor_name: str, stop_name: str, feeling: str = "Not recorded", notes: str = "") -> dict {
    neighbor = get_neighbor(neighbor_name);
    stop = get_stop(stop_name);

    if neighbor == None or stop == None {
        return {"error": "Neighbor or stop not found"};
    }

    cost = stop.base_cost;
    bonus = stop.bonus_on_visit;
    recorded_feeling = feeling;
    if recorded_feeling not in ["Great", "Good", "Okay", "Struggling", "Distressed"] {
        recorded_feeling = "Not recorded";
    }

    if neighbor.points_balance < cost {
        return {"error": "Insufficient points", "balance": neighbor.points_balance, "cost": cost};
    }

    neighbor.points_balance = neighbor.points_balance - cost + bonus;
    neighbor.points_spent = neighbor.points_spent + cost;
    neighbor.points_earned = neighbor.points_earned + bonus;

    trip_id = neighbor.name + "-" + stop.name + "-" + str(neighbor.points_spent);
    root ++> Trip(
        trip_id=trip_id,
        neighbor_name=neighbor.name,
        stop_name=stop.name,
        cost=cost,
        bonus=bonus,
        feeling=recorded_feeling,
        notes=notes.strip()
    );

    return {
        "status": "completed",
        "neighbor": neighbor.name,
        "stop": stop.name,
        "cost": cost,
        "bonus": bonus,
        "feeling": recorded_feeling,
        "notes": notes.strip(),
        "new_balance": neighbor.points_balance
    };
}

def:pub api_update_trip_notes(trip_id: str, notes: str) -> dict {
    for t in [root-->][?:Trip] {
        if jid(t) == trip_id {
            t.notes = notes.strip();
            return {
                "status": "updated",
                "id": trip_id,
                "notes": t.notes
            };
        }
    }
    return {"error": "Session not found"};
}

def:pub api_trips() -> list[dict] {
    result: list[dict] = [];
    for t in [root-->][?:Trip] {
        result = result + [{
            "id": jid(t),
            "neighbor": t.neighbor_name,
            "stop": t.stop_name,
            "cost": t.cost,
            "bonus": t.bonus,
            "feeling": t.feeling,
            "notes": getattr(t, "notes", "")
        }];
    }
    return result;
}

# ===========================
# Boot — seed data once when server starts
# ===========================

with entry {
    seed_demo_data();
}
