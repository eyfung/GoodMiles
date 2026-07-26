# Job-match agent — community-center dashboard backend
#
# New, additive feature: staff at a service stop (community center / food bank)
# type a few notes about a walk-in, the system suggests a job category (human
# confirms or overrides it), and an agentic walker ranks the open jobs by
# category fit and real distance (miles) from that center, and tallies the
# open spots.
#
# Grounded in the REAL app data: the walk-in's location is an actual
# ServiceStop node (the same ones the Service Stops page shows), imported
# read-only from services/goodmiles.jac. This module never mutates
# Neighbor / ServiceStop / Trip or the points-optimize flow — it only reads
# ServiceStops and adds its own JobSeeker / Job graph on the side.

import os;

import from services.goodmiles { ServiceStop, get_all_stops, seed_demo_data }

# ========================================
# Node / edge / enum definitions
# ========================================

node Job {
    has title: str;
    has employer_name: str;
    has category: str;
    has address: str;
    has zone: str;
    has lat: float;
    has lng: float;
    has open_spots: int = 1;
    has wage_hint: str = "";
}

node JobSeeker {
    has name: str;
    has notes: str;
    has category: str;
}

node JobMatchSeeded {
    has done: bool = True;
}

# A walk-in is intake'd AT a real ServiceStop.
edge VISITED: JobSeeker --> ServiceStop {}

enum JobCategory: str {
    KITCHEN = "kitchen",
    CLEANING = "cleaning",
    WAREHOUSE = "warehouse",
    HOSPITALITY = "hospitality",
    RETAIL = "retail",
    ADMIN = "admin",
}
sem JobCategory.KITCHEN = "Kitchen prep, cooking, or restaurant back-of-house experience.";
sem JobCategory.CLEANING = "Janitorial, custodial, or event/venue cleanup experience.";
sem JobCategory.WAREHOUSE = "Warehouse, logistics, forklift, or stock-room experience.";
sem JobCategory.HOSPITALITY = "Hotel housekeeping or hospitality service experience.";
sem JobCategory.RETAIL = "Grocery, retail stocking, or cashier experience.";
sem JobCategory.ADMIN = "Front-desk, reception, or general office/administrative experience.";

# ========================================
# Seed data (idempotent)
# ========================================
# ServiceStops come from goodmiles' own seed (the Service Stops page) — this
# module only seeds the open Jobs: a GoodMiles zone for grouping, real
# coordinates for distance, and how many spots are open at each.

def seed_jobmatch_data {
    existing = [root-->][?:JobMatchSeeded];
    if len(existing) > 0 {
        return;
    }
    root ++> JobMatchSeeded();

    root ++> Job(
        title="Kitchen Prep Assistant", employer_name="Golden Spoon Diner",
        category=JobCategory.KITCHEN, address="10 Market St, San Francisco, CA",
        zone="north", lat=37.7879, lng=-122.4074, open_spots=2, wage_hint="$18/hr"
    );
    root ++> Job(
        title="Event Cleanup Worker", employer_name="Civic Hall Events Co.",
        category=JobCategory.CLEANING, address="99 Civic Center Plz, San Francisco, CA",
        zone="central", lat=37.7793, lng=-122.4193, open_spots=4, wage_hint="$17/hr"
    );
    root ++> Job(
        title="Warehouse Associate", employer_name="Bay Area Logistics Partners",
        category=JobCategory.WAREHOUSE, address="500 SoMa Way, San Francisco, CA",
        zone="south", lat=37.7749, lng=-122.4034, open_spots=3, wage_hint="$19/hr"
    );
    root ++> Job(
        title="Hotel Housekeeping", employer_name="Union Square Inn",
        category=JobCategory.HOSPITALITY, address="20 Union Sq, San Francisco, CA",
        zone="north", lat=37.7880, lng=-122.4075, open_spots=1, wage_hint="$18.50/hr"
    );
    root ++> Job(
        title="Grocery Stocker", employer_name="Mission Market Grocers",
        category=JobCategory.RETAIL, address="300 Mission St, San Francisco, CA",
        zone="south", lat=37.7599, lng=-122.4148, open_spots=2, wage_hint="$17.50/hr"
    );
    root ++> Job(
        title="Community Center Receptionist", employer_name="Bayview Family Resource Center",
        category=JobCategory.ADMIN, address="88 Bayview Blvd, San Francisco, CA",
        zone="central", lat=37.7300, lng=-122.3850, open_spots=1, wage_hint="$18/hr"
    );
}

# ========================================
# Distance — real miles from the center to each open job
# ========================================
# ServiceStops carry no coordinates (they're located by zone), so each center
# gets a representative point — its known location, or its zone centroid as a
# fallback. calculate_distance_miles is the seam for a real integration: swap
# the Haversine body for a live drive/transit time (e.g. Google Distance
# Matrix) — same signature, no caller changes needed.

import math;

def center_coord(stop: ServiceStop) -> dict {
    known = {
        "River Pantry": {"lat": 37.7749, "lng": -122.4194},
        "Career Hub": {"lat": 37.7880, "lng": -122.4074},
        "Wellness Center": {"lat": 37.7599, "lng": -122.4148},
        "Community Health": {"lat": 37.7300, "lng": -122.3850},
        "Jobs Office": {"lat": 37.7320, "lng": -122.3890},
    };
    if stop.name in known {
        return known[stop.name];
    }
    centroid = {
        "north": {"lat": 37.7850, "lng": -122.4110},
        "central": {"lat": 37.7600, "lng": -122.4180},
        "south": {"lat": 37.7300, "lng": -122.3880},
    };
    return centroid.get(stop.zone, {"lat": 37.7749, "lng": -122.4194});
}

def calculate_distance_miles(lat1: float, lng1: float, lat2: float, lng2: float) -> float {
    radius_mi = 3958.8;
    phi1 = math.radians(lat1);
    phi2 = math.radians(lat2);
    dphi = math.radians(lat2 - lat1);
    dlambda = math.radians(lng2 - lng1);
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2;
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radius_mi * c;
}

# ========================================
# Category classification — LLM suggestion, human confirms
# ========================================

def _classify_llm(notes: str) -> JobCategory by llm();
sem _classify_llm = "Classify a walk-in job seeker's free-text notes into the single best-fit job category. This is only a SUGGESTION a human caseworker will review and can override.";
sem _classify_llm.notes = "Free-text notes a community-center caseworker wrote about the person's work experience, availability, and preferences.";

def _classify_keyword(notes: str) -> JobCategory {
    text = notes.lower();
    if "kitchen" in text or "cook" in text or "restaurant" in text or "food prep" in text or "chef" in text {
        return JobCategory.KITCHEN;
    }
    if "clean" in text or "janitor" in text or "custodial" in text or "event" in text {
        return JobCategory.CLEANING;
    }
    if "warehouse" in text or "forklift" in text or "logistics" in text or "stock room" in text or "loading" in text {
        return JobCategory.WAREHOUSE;
    }
    if "hotel" in text or "housekeeping" in text or "hospitality" in text {
        return JobCategory.HOSPITALITY;
    }
    if "grocery" in text or "cashier" in text or "stocker" in text or "retail" in text {
        return JobCategory.RETAIL;
    }
    if "reception" in text or "office" in text or "admin" in text or "front desk" in text or "clerical" in text {
        return JobCategory.ADMIN;
    }
    return JobCategory.RETAIL;
}

# ========================================
# Helpers
# ========================================

def get_service_stop(id: str) -> ServiceStop | None {
    node_obj = jobj(id);
    if isinstance(node_obj, ServiceStop) {
        return node_obj;
    }
    return None;
}

# ========================================
# find_best_jobs — the graph-traversal agent
# ========================================
# Genuinely walks: JobSeeker -> its VISITED ServiceStop -> ranks every open
# Job by category match + real distance (miles) from that center.

walker find_best_jobs {
    has seeker_id: str;
    has seeker_category: str = "";
    has origin_center: dict = {};
    has matches: list[dict] = [];

    can start with Root entry {
        seeker = jobj(self.seeker_id);
        if isinstance(seeker, JobSeeker) {
            visit [seeker];
        }
    }

    can from_seeker with JobSeeker entry {
        self.seeker_category = here.category;
        stops = [here ->:VISITED:->];
        if len(stops) > 0 {
            visit [stops[0]];
        }
    }

    can from_stop with ServiceStop entry {
        # The person's current community center — the "from" of the trip.
        origin = center_coord(here);
        self.origin_center = {
            "id": jid(here), "name": here.name, "zone": here.zone, "stop_type": here.stop_type
        };
        results: list[dict] = [];
        for j in [root-->][?:Job] {
            miles = calculate_distance_miles(origin["lat"], origin["lng"], j.lat, j.lng);
            results = results + [{
                "job_id": jid(j),
                "title": j.title,
                "employer_name": j.employer_name,
                "category": j.category,
                "place": j.employer_name + " — " + j.address,
                "address": j.address,
                "wage_hint": j.wage_hint,
                "open_spots": j.open_spots,
                "distance_miles": round(miles, 1),
                "category_match": j.category == self.seeker_category
            }];
        }

        # Insertion sort by (category_match desc, distance_miles asc) — same
        # manual-sort style already used in services/goodmiles.jac.
        i = 0;
        while i < len(results) {
            j2 = i + 1;
            while j2 < len(results) {
                a = results[i];
                b = results[j2];
                a_match = a["category_match"] as bool;
                b_match = b["category_match"] as bool;
                a_dist = a["distance_miles"] as float;
                b_dist = b["distance_miles"] as float;
                swap = False;
                if b_match and not a_match {
                    swap = True;
                } elif a_match == b_match and b_dist < a_dist {
                    swap = True;
                }
                if swap {
                    tmp = results[i];
                    results[i] = results[j2];
                    results[j2] = tmp;
                }
                j2 = j2 + 1;
            }
            i = i + 1;
        }

        self.matches = results;
    }

    can finish with Root exit {
        recommended: dict = self.matches[0] if len(self.matches) > 0 else {};
        total_spots = 0;
        for m in self.matches {
            total_spots = total_spots + (m["open_spots"] as int);
        }
        report {
            "origin": self.origin_center,
            "recommended": recommended,
            "matches": self.matches,
            "total_open_spots": total_spots,
            "open_positions": len(self.matches)
        };
    }
}

# ========================================
# Public API endpoints
# ========================================
# Intake happens at a real ServiceStop, so the picker is the actual stop list.

def:pub api_service_stops() -> list[dict] {
    seed_demo_data();
    seed_jobmatch_data();
    result: list[dict] = [];
    for s in get_all_stops() {
        result = result + [{
            "id": jid(s), "name": s.name, "zone": s.zone, "stop_type": s.stop_type
        }];
    }
    return result;
}

def:pub api_jobs() -> list[dict] {
    seed_jobmatch_data();
    result: list[dict] = [];
    for j in [root-->][?:Job] {
        result = result + [{
            "id": jid(j), "title": j.title, "employer_name": j.employer_name,
            "category": j.category, "address": j.address, "zone": j.zone,
            "open_spots": j.open_spots, "wage_hint": j.wage_hint
        }];
    }
    return result;
}

def:pub api_suggest_category(notes: str) -> dict {
    api_key = os.environ.get("OPENAI_API_KEY", "");
    if api_key != "" {
        category = _classify_llm(notes);
        source = "llm";
    } else {
        category = _classify_keyword(notes);
        source = "keyword";
    }
    return {"category": category, "source": source};
}

def:pub api_create_job_seeker(name: str, notes: str, category: str, service_stop_id: str) -> dict {
    seed_demo_data();
    stop = get_service_stop(service_stop_id);
    if stop == None {
        return {"error": "Service stop not found"};
    }
    seeker = root ++> JobSeeker(name=name, notes=notes, category=category);
    seeker +>:VISITED():+> stop;
    return {"id": jid(seeker), "name": seeker.name, "category": seeker.category};
}

def:pub api_find_best_jobs(seeker_id: str) -> dict {
    result = root spawn find_best_jobs(seeker_id=seeker_id);
    if result.reports {
        return result.reports[0];
    }
    return {"origin": {}, "recommended": {}, "matches": [], "total_open_spots": 0, "open_positions": 0};
}
