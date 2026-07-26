# Job-match agent — community-center dashboard backend
#
# New, additive feature: staff at a community center/food bank type a few
# notes about a walk-in, the system suggests a job category (human confirms
# or overrides it), and an agentic walker ranks seeded jobs by category fit
# and distance from that center. Independent of services/goodmiles.sv.jac —
# does not touch Neighbor / ServiceStop / the points-optimize flow.

import os;
import math;

# ========================================
# Node / edge / enum definitions
# ========================================

node CommunityCenter {
    has name: str;
    has address: str;
    has lat: float;
    has lng: float;
}

node Job {
    has title: str;
    has employer_name: str;
    has category: str;
    has address: str;
    has lat: float;
    has lng: float;
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

edge VISITED: JobSeeker --> CommunityCenter {}

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

def seed_jobmatch_data {
    existing = [root-->][?:JobMatchSeeded];
    if len(existing) > 0 {
        return;
    }
    root ++> JobMatchSeeded();

    root ++> CommunityCenter(
        name="Riverside Community Food Bank",
        address="1200 Riverside Ave, San Francisco, CA",
        lat=37.7749, lng=-122.4194
    );
    root ++> CommunityCenter(
        name="Eastside Neighborhood Shelter",
        address="450 Eastside St, San Francisco, CA",
        lat=37.7599, lng=-122.4148
    );
    root ++> CommunityCenter(
        name="Bayview Family Resource Center",
        address="88 Bayview Blvd, San Francisco, CA",
        lat=37.7300, lng=-122.3850
    );

    root ++> Job(
        title="Kitchen Prep Assistant", employer_name="Golden Spoon Diner",
        category=JobCategory.KITCHEN, address="10 Market St, San Francisco, CA",
        lat=37.7879, lng=-122.4074, wage_hint="$18/hr"
    );
    root ++> Job(
        title="Event Cleanup Worker", employer_name="Civic Hall Events Co.",
        category=JobCategory.CLEANING, address="99 Civic Center Plz, San Francisco, CA",
        lat=37.7793, lng=-122.4193, wage_hint="$17/hr"
    );
    root ++> Job(
        title="Warehouse Associate", employer_name="Bay Area Logistics Partners",
        category=JobCategory.WAREHOUSE, address="500 SoMa Way, San Francisco, CA",
        lat=37.7749, lng=-122.4034, wage_hint="$19/hr"
    );
    root ++> Job(
        title="Hotel Housekeeping", employer_name="Union Square Inn",
        category=JobCategory.HOSPITALITY, address="20 Union Sq, San Francisco, CA",
        lat=37.7880, lng=-122.4075, wage_hint="$18.50/hr"
    );
    root ++> Job(
        title="Grocery Stocker", employer_name="Mission Market Grocers",
        category=JobCategory.RETAIL, address="300 Mission St, San Francisco, CA",
        lat=37.7599, lng=-122.4148, wage_hint="$17.50/hr"
    );
    root ++> Job(
        title="Community Center Receptionist", employer_name="Bayview Family Resource Center",
        category=JobCategory.ADMIN, address="88 Bayview Blvd, San Francisco, CA",
        lat=37.7300, lng=-122.3850, wage_hint="$18/hr"
    );
}

# ========================================
# Distance — Haversine now, Google-ready later
# ========================================
# calculate_distance_km is the seam for a real integration: swap the body for
# a call to Google's Distance Matrix API (guarded by GOOGLE_MAPS_API_KEY) for
# real drive/transit time. Same signature, no caller changes needed.

def calculate_distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float {
    radius_km = 6371.0;
    phi1 = math.radians(lat1);
    phi2 = math.radians(lat2);
    dphi = math.radians(lat2 - lat1);
    dlambda = math.radians(lng2 - lng1);
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2;
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radius_km * c;
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

def get_community_center(id: str) -> CommunityCenter | None {
    node_obj = jobj(id);
    if isinstance(node_obj, CommunityCenter) {
        return node_obj;
    }
    return None;
}

# ========================================
# find_best_jobs — the graph-traversal agent
# ========================================
# Genuinely walks: JobSeeker -> its VISITED community center -> ranks every
# seeded Job by category match + Haversine distance from that center.

walker find_best_jobs {
    has seeker_id: str;
    has seeker_category: str = "";
    has matches: list[dict] = [];
    has reports: list[list[dict]] = [];

    can start with Root entry {
        seeker = jobj(self.seeker_id);
        if isinstance(seeker, JobSeeker) {
            visit [seeker];
        }
    }

    can from_seeker with JobSeeker entry {
        self.seeker_category = here.category;
        centers = [here ->:VISITED:->];
        if len(centers) > 0 {
            visit [centers[0]];
        }
    }

    can from_center with CommunityCenter entry {
        results: list[dict] = [];
        for j in [root-->][?:Job] {
            dist = calculate_distance_km(here.lat, here.lng, j.lat, j.lng);
            results = results + [{
                "job_id": jid(j),
                "title": j.title,
                "employer_name": j.employer_name,
                "category": j.category,
                "address": j.address,
                "wage_hint": j.wage_hint,
                "distance_km": dist,
                "category_match": j.category == self.seeker_category
            }];
        }

        # Insertion sort by (category_match desc, distance_km asc) — same
        # manual-sort style already used in services/goodmiles.sv.jac.
        i = 0;
        while i < len(results) {
            j2 = i + 1;
            while j2 < len(results) {
                a = results[i];
                b = results[j2];
                a_match = a["category_match"] as bool;
                b_match = b["category_match"] as bool;
                a_dist = a["distance_km"] as float;
                b_dist = b["distance_km"] as float;
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
        report self.matches;
    }
}

# ========================================
# Public API endpoints
# ========================================

def:pub api_community_centers() -> list[dict] {
    seed_jobmatch_data();
    result: list[dict] = [];
    for c in [root-->][?:CommunityCenter] {
        result = result + [{
            "id": jid(c), "name": c.name, "address": c.address, "lat": c.lat, "lng": c.lng
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
            "category": j.category, "address": j.address, "wage_hint": j.wage_hint
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

def:pub api_create_job_seeker(name: str, notes: str, category: str, community_center_id: str) -> dict {
    seed_jobmatch_data();
    center = get_community_center(community_center_id);
    if center == None {
        return {"error": "Community center not found"};
    }
    seeker = root ++> JobSeeker(name=name, notes=notes, category=category);
    seeker +>:VISITED():+> center;
    return {"id": jid(seeker), "name": seeker.name, "category": seeker.category};
}

def:pub api_find_best_jobs(seeker_id: str) -> list[dict] {
    result = root spawn find_best_jobs(seeker_id=seeker_id);
    return result.reports[0] if result.reports else [];
}
