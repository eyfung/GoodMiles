# Pathway — agentic AV mobility dispatch (community-center dashboard)
#
# A participant requests a ride to a booked service (job coaching, medical,
# food pantry, counseling). The agent:
#   1) dispatches an AV from the live fleet based on current capacity and
#      proximity to the pickup (deterministic),
#   2) plans the route (AV -> pickup -> destination) and estimates distance/ETA,
#   3) keeps every request's pathway so the whole fleet can be shown on one map,
#   4) recommends the participant's most useful next service/ride.
#
# Locations are owned by Pathway. Completed visits write their point impact
# back to the participant record and create a visible history entry.

import os;
import math;
import json;
import urllib.request;
import from datetime { datetime }

import from services.goodmiles { Neighbor, Trip, get_all_neighbors, get_neighbor, seed_demo_data }

glob AV_SPEED_MPH: float = 25.0;

# ========================================
# Nodes
# ========================================

node AV {
    has name: str;
    has seats_total: int;
    has lat: float;
    has lng: float;
    has zone: str;
    has seats_used: int = 0;
    has status: str = "idle";   # idle | enroute
}

node RideRequest {
    has participant: str;
    has note: str;
    has availability: str;
    has has_car: bool;
    has need: str;
    has pickup_name: str;
    has pickup_lat: float;
    has pickup_lng: float;
    has dest_name: str;
    has dest_type: str;
    has dest_lat: float;
    has dest_lng: float;
    has av_name: str = "";
    has distance_miles: float = 0.0;
    has eta_min: int = 0;
    has status: str = "requested";   # dispatched | self_transport | queued | cleared
    has route: list = [];            # [[lat, lng], ...]
    has decision: str = "";
    has next_service: dict = {};
    has transcript: str = "";
    has interpretation: dict = {};
    has location_id: str = "";
    has visit_cost: int = 0;
    has points_reward: int = 0;
    has upskill_category: str = "";
    has completed: bool = False;
}

node PathwayLocation {
    has location_id: str;
    has name: str;
    has service_type: str;
    has category: str;
    has zone: str;
    has lat: float;
    has lng: float;
    has visit_cost: int;
    has points_reward: int;
    has capacity_total: int;
    has capacity_used: int = 0;
}

node FleetSeeded {
    has done: bool = True;
}

node CatalogSeeded {
    has done: bool = True;
}

# ========================================
# Seed — the AV fleet (destinations come from goodmiles ServiceStops)
# ========================================

def seed_fleet_data {
    existing = [root-->][?:FleetSeeded];
    if len(existing) > 0 {
        return;
    }
    root ++> FleetSeeded();
    root ++> AV(name="AV-01", seats_total=4, lat=37.7880, lng=-122.4080, zone="north");
    root ++> AV(name="AV-02", seats_total=3, lat=37.7620, lng=-122.4190, zone="central");
    root ++> AV(name="AV-03", seats_total=4, lat=37.7350, lng=-122.3900, zone="south");
    root ++> AV(name="AV-04", seats_total=3, lat=37.7800, lng=-122.4120, zone="north");
}

def seed_location_catalog {
    existing = [root-->][?:CatalogSeeded];
    if len(existing) > 0 {
        return;
    }
    root ++> CatalogSeeded();
    root ++> PathwayLocation(location_id="river-pantry", name="River Pantry", service_type="food", category="Stability", zone="north", lat=37.7749, lng=-122.4194, visit_cost=5, points_reward=20, capacity_total=18);
    root ++> PathwayLocation(location_id="career-hub", name="Career Hub", service_type="coaching", category="Career skills", zone="north", lat=37.7880, lng=-122.4074, visit_cost=5, points_reward=25, capacity_total=12);
    root ++> PathwayLocation(location_id="wellness-center", name="Wellness Center", service_type="counseling", category="Wellbeing", zone="central", lat=37.7599, lng=-122.4148, visit_cost=5, points_reward=20, capacity_total=10);
    root ++> PathwayLocation(location_id="community-health", name="Community Health", service_type="health", category="Health readiness", zone="south", lat=37.7300, lng=-122.3850, visit_cost=10, points_reward=25, capacity_total=14);
    root ++> PathwayLocation(location_id="jobs-office", name="Jobs Office", service_type="employment", category="Employment readiness", zone="south", lat=37.7320, lng=-122.3890, visit_cost=5, points_reward=30, capacity_total=16);
    root ++> PathwayLocation(location_id="digital-learning-lab", name="Digital Learning Lab", service_type="education", category="Digital skills", zone="central", lat=37.7665, lng=-122.4172, visit_cost=5, points_reward=25, capacity_total=20);
    root ++> PathwayLocation(location_id="community-kitchen", name="Community Kitchen", service_type="community", category="Community contribution", zone="north", lat=37.7812, lng=-122.4104, visit_cost=5, points_reward=30, capacity_total=15);
}

# ========================================
# Geometry + reference data
# ========================================

def get_all_locations() -> list[PathwayLocation] {
    seed_location_catalog();
    return [root-->][?:PathwayLocation];
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

def _eta_min(miles: float) -> int {
    return round(miles / AV_SPEED_MPH * 60.0);
}

def _pickup_points() -> list {
    return [
        {"name": "Tenderloin SRO", "lat": 37.7840, "lng": -122.4130, "zone": "north"},
        {"name": "Mission Homes", "lat": 37.7600, "lng": -122.4180, "zone": "central"},
        {"name": "Sunnydale Apartments", "lat": 37.7120, "lng": -122.4160, "zone": "south"},
        {"name": "Bayview Blocks", "lat": 37.7300, "lng": -122.3860, "zone": "south"},
    ];
}

def _consultation_scenarios() -> list[dict] {
    return [
        {
            "id": "maya_food",
            "title": "Maya — food insecurity",
            "participant": "Maya",
            "transcript": "Avatar: This ride is a private space. Share only what you are comfortable sharing, and I will use it to help plan support.\nMaya: Thank you. I have not had a full meal since yesterday, and my benefits do not reload until next week. I am staying at the Tenderloin SRO and do not have a car. I can go now, but crowded places make me a little anxious.\nAvatar: Would you like help reaching a food resource today?\nMaya: Yes, a pantry today would help a lot.",
            "pickup_name": "Tenderloin SRO",
            "destination_name": "River Pantry",
            "availability": "now",
            "has_car": False,
            "need": "food",
            "wellbeing": "Anxious but comfortable continuing",
            "urgency": "high",
            "summary": "Maya needs same-day food assistance and transportation from the Tenderloin SRO. She reports mild anxiety in crowded spaces, so a calm handoff is recommended.",
            "evidence": ["No full meal since yesterday", "Benefits unavailable until next week", "Requested pantry support today"],
            "safety_flags": ["Food insecurity", "Crowd-related anxiety"]
        },
        {
            "id": "marcus_coaching",
            "title": "Marcus — job loss",
            "participant": "Marcus",
            "transcript": "Avatar: You are in a private consultation. I can help turn what you share into a support plan.\nMarcus: I was laid off two weeks ago and have applied everywhere without hearing back. I live at Mission Homes, do not have a car, and mornings are easiest because I watch my daughter after school. I want help fixing my resume and practicing interviews.\nAvatar: Would job coaching be the best first step?\nMarcus: Yes, I am ready to work on that.",
            "pickup_name": "Mission Homes",
            "destination_name": "Career Hub",
            "availability": "morning",
            "has_car": False,
            "need": "coaching",
            "wellbeing": "Discouraged but motivated",
            "urgency": "medium",
            "summary": "Marcus is seeking job coaching after a recent layoff and needs morning transportation from Mission Homes. He feels discouraged but is motivated to improve his resume and interview skills.",
            "evidence": ["Laid off two weeks ago", "Needs resume and interview help", "Available in the morning"],
            "safety_flags": []
        },
        {
            "id": "elena_health",
            "title": "Elena — health follow-up",
            "participant": "Elena",
            "transcript": "Avatar: This conversation is private and focused on arranging the support you choose.\nElena: My blood pressure medication is almost gone, and I have been feeling dizzy. I am at Sunnydale Apartments and cannot drive. Afternoons work best. I use a walker, so I need a vehicle with easy boarding and a little extra time.\nAvatar: Do you want a clinic visit arranged as the priority?\nElena: Yes, please. I want to be seen before the medication runs out.",
            "pickup_name": "Sunnydale Apartments",
            "destination_name": "Community Health",
            "availability": "afternoon",
            "has_car": False,
            "need": "health",
            "wellbeing": "Worried and physically uncomfortable",
            "urgency": "high",
            "summary": "Elena needs a prompt medical visit for dizziness and a nearly depleted prescription. Dispatch should support walker access, easy boarding, and extra pickup time at Sunnydale Apartments.",
            "evidence": ["Medication is almost gone", "Reports dizziness", "Uses a walker"],
            "safety_flags": ["Medication continuity", "Dizziness", "Mobility accommodation"]
        },
        {
            "id": "darius_counseling",
            "title": "Darius — emotional distress",
            "participant": "Darius",
            "transcript": "Avatar: You can speak freely here, and you control what is shared for arranging care.\nDarius: I have barely slept this week and keep feeling overwhelmed. I am safe right now, but I do not want to be alone with it. I am near Bayview Blocks, have no car, and can leave now. I would like to talk with a counselor somewhere quiet.\nAvatar: I hear that you are safe now and want support today. Should I prioritize counseling?\nDarius: Yes, please.",
            "pickup_name": "Bayview Blocks",
            "destination_name": "Wellness Center",
            "availability": "now",
            "has_car": False,
            "need": "counseling",
            "wellbeing": "Overwhelmed; states they are currently safe",
            "urgency": "high",
            "summary": "Darius requests same-day counseling after poor sleep and feeling overwhelmed. He states he is currently safe, and a quiet, supportive handoff with timely follow-up is recommended.",
            "evidence": ["Barely slept this week", "Feels overwhelmed", "Explicitly states they are safe now"],
            "safety_flags": ["Emotional distress", "Same-day follow-up"]
        },
        {
            "id": "priya_employment",
            "title": "Priya — returning to work",
            "participant": "Priya",
            "transcript": "Avatar: This private check-in helps me coordinate only the services you agree to use.\nPriya: I have been caring for my father and have been out of work for a year. I am ready to return, but I do not know which openings fit my experience. I am at the Tenderloin SRO, do not have a car, and afternoons are best after his home aide arrives.\nAvatar: Would you like an employment-services appointment first?\nPriya: Yes. I want help identifying jobs and making a plan.",
            "pickup_name": "Tenderloin SRO",
            "destination_name": "Jobs Office",
            "availability": "afternoon",
            "has_car": False,
            "need": "employment",
            "wellbeing": "Hopeful but uncertain",
            "urgency": "medium",
            "summary": "Priya is returning to work after a caregiving gap and wants help identifying suitable openings. She needs afternoon transportation from the Tenderloin SRO after her father’s home aide arrives.",
            "evidence": ["One-year caregiving employment gap", "Ready to return to work", "Afternoon availability"],
            "safety_flags": []
        }
    ];
}

def _service_label(stop_type: str) -> str {
    m = {
        "pantry": "Food Pantry", "coaching": "Job Coaching", "counseling": "Counseling",
        "health": "Medical Clinic", "employment": "Employment Services",
        "education": "Digital Learning", "community": "Community Contribution"
    };
    return m.get(stop_type, stop_type);
}

def _next_type(stop_type: str) -> str {
    m = {
        "food": "health", "coaching": "employment", "employment": "counseling",
        "health": "food", "counseling": "coaching", "education": "employment",
        "community": "coaching"
    };
    return m.get(stop_type, "food");
}

def get_location(id: str) -> PathwayLocation | None {
    for location in get_all_locations() {
        if location.location_id == id or jid(location) == id {
            return location;
        }
    }
    return None;
}

def _nearest_stop_of_type(stop_type: str, from_lat: float, from_lng: float, exclude_id: str) -> dict {
    best: dict = {};
    best_d = 999999.0;
    for location in get_all_locations() {
        if location.service_type == stop_type and location.location_id != exclude_id {
            d = calculate_distance_miles(from_lat, from_lng, location.lat, location.lng);
            if d < best_d {
                best_d = d;
                best = {
                    "id": location.location_id, "name": location.name, "service": _service_label(location.service_type),
                    "lat": location.lat, "lng": location.lng, "distance_miles": round(d, 1)
                };
            }
        }
    }
    return best;
}

# ========================================
# TOOLS — deterministic dispatch + routing (real state changes)
# ========================================

def dispatch_av(pickup_lat: float, pickup_lng: float) -> AV | None {
    best: AV | None = None;
    best_d = 999999.0;
    for v in [root-->][?:AV] {
        if v.seats_used < v.seats_total {
            d = calculate_distance_miles(v.lat, v.lng, pickup_lat, pickup_lng);
            if d < best_d {
                best_d = d;
                best = v;
            }
        }
    }
    return best;
}

def _av_dict(v: AV) -> dict {
    return {
        "name": v.name, "seats_total": v.seats_total, "seats_used": v.seats_used,
        "seats_free": v.seats_total - v.seats_used, "status": v.status,
        "lat": v.lat, "lng": v.lng, "zone": v.zone
    };
}

def _req_dict(r: RideRequest) -> dict {
    return {
        "id": jid(r), "participant": r.participant, "note": r.note,
        "availability": r.availability, "has_car": r.has_car, "need": r.need,
        "pickup_name": r.pickup_name, "pickup_lat": r.pickup_lat, "pickup_lng": r.pickup_lng,
        "dest_name": r.dest_name, "dest_type": r.dest_type, "dest_service": _service_label(r.dest_type),
        "dest_lat": r.dest_lat, "dest_lng": r.dest_lng,
        "av_name": r.av_name, "distance_miles": r.distance_miles, "eta_min": r.eta_min,
        "status": r.status, "route": r.route, "decision": r.decision, "next_service": r.next_service,
        "transcript": getattr(r, "transcript", ""),
        "interpretation": getattr(r, "interpretation", {}),
        "location_id": getattr(r, "location_id", ""),
        "visit_cost": getattr(r, "visit_cost", 0),
        "points_reward": getattr(r, "points_reward", 0),
        "upskill_category": getattr(r, "upskill_category", ""),
        "completed": getattr(r, "completed", False)
    };
}

def _serialize_state(current: RideRequest | None) -> dict {
    fleet: list = [];
    total_seats = 0;
    used_seats = 0;
    for v in [root-->][?:AV] {
        fleet = fleet + [_av_dict(v)];
        total_seats = total_seats + v.seats_total;
        used_seats = used_seats + v.seats_used;
    }
    requests: list = [];
    for r in [root-->][?:RideRequest] {
        if r.status != "cleared" {
            requests = requests + [_req_dict(r)];
        }
    }
    cur: dict = {};
    if isinstance(current, RideRequest) {
        cur = _req_dict(current);
    }
    return {
        "fleet": fleet,
        "requests": requests,
        "current": cur,
        "capacity": {"total": total_seats, "used": used_seats, "free": total_seats - used_seats},
        "pickups": _pickup_points(),
        "destinations": _destinations_list(),
        "scenarios": _consultation_scenarios()
    };
}

def _destinations_list() -> list {
    out: list = [];
    for location in get_all_locations() {
        out = out + [{
            "id": location.location_id, "name": location.name, "stop_type": location.service_type,
            "service": _service_label(location.service_type), "category": location.category,
            "lat": location.lat, "lng": location.lng, "zone": location.zone,
            "visit_cost": location.visit_cost, "points_reward": location.points_reward,
            "net_points": location.points_reward - location.visit_cost,
            "capacity_total": location.capacity_total,
            "capacity_used": location.capacity_used,
            "capacity_free": location.capacity_total - location.capacity_used
        }];
    }
    return out;
}

def _preset_demo_interpretation(scenario_id: str) -> dict {
    selected: dict = {};
    for scenario in _consultation_scenarios() {
        if (scenario["id"] as str) == scenario_id {
            selected = scenario;
        }
    }
    if len(selected) == 0 {
        return {"error": "Preset interpretation is unavailable"};
    }
    location_ids = {
        "River Pantry": "river-pantry",
        "Career Hub": "career-hub",
        "Wellness Center": "wellness-center",
        "Community Health": "community-health",
        "Jobs Office": "jobs-office"
    };
    pickup_zones = {
        "Tenderloin SRO": "north",
        "Mission Homes": "central",
        "Sunnydale Apartments": "south",
        "Bayview Blocks": "south"
    };
    destination_name = selected["destination_name"] as str;
    pickup_name = selected["pickup_name"] as str;
    return {
        "agent": "Preset demo interpretation",
        "participant": selected["participant"],
        "primary_need": selected["need"],
        "urgency": selected["urgency"],
        "availability": selected["availability"],
        "pickup_name": pickup_name,
        "home_zone": pickup_zones[pickup_name],
        "has_car": selected["has_car"],
        "wellbeing_signal": selected["wellbeing"],
        "summary": selected["summary"],
        "evidence": selected["evidence"],
        "safety_flags": selected["safety_flags"],
        "recommended_location_id": location_ids[destination_name],
        "allocation_reason": "Preset MVP routing matches the participant's stated primary need to the approved location catalogue.",
        "consent_scope": "Use consultation details only for service coordination and safe transportation",
        "raw_transcript_retained": True
    };
}

def _gemini_interpret_transcript(transcript: str) -> dict {
    api_key = os.getenv("GEMINI_API_KEY", "");
    if api_key == "" {
        return {
            "error": "Gemini is not configured. Set GEMINI_API_KEY and restart the server.",
            "code": "gemini_not_configured"
        };
    }

    catalog_context: list[dict] = [];
    for location in get_all_locations() {
        catalog_context = catalog_context + [{
            "location_id": location.location_id,
            "name": location.name,
            "service_type": location.service_type,
            "category": location.category,
            "zone": location.zone,
            "visit_cost": location.visit_cost,
            "points_reward": location.points_reward,
            "capacity_free": location.capacity_total - location.capacity_used
        }];
    }

    prompt = "You are the GoodMiles Pathway Consultation Interpreter. Extract only facts supported by the private in-car consultation transcript. Do not diagnose, invent details, or treat points as proof of human worth. Recommend exactly one available catalogue location that best addresses the participant's stated need. Flag urgent safety concerns for human follow-up. The transcript is retained only because this is an MVP demo.\n\nPICKUP OPTIONS:\n" + json.dumps(_pickup_points()) + "\n\nLOCATION CATALOGUE:\n" + json.dumps(catalog_context) + "\n\nTRANSCRIPT:\n" + transcript;
    schema = {
        "type": "object",
        "properties": {
            "participant": {"type": "string"},
            "primary_need": {"type": "string", "enum": ["food", "coaching", "health", "counseling", "employment", "education", "community"]},
            "urgency": {"type": "string", "enum": ["low", "medium", "high"]},
            "availability": {"type": "string", "enum": ["now", "morning", "afternoon"]},
            "pickup_name": {"type": "string"},
            "home_zone": {"type": "string", "enum": ["north", "central", "south"]},
            "has_car": {"type": "boolean"},
            "wellbeing_signal": {"type": "string"},
            "summary": {"type": "string"},
            "evidence": {"type": "array", "items": {"type": "string"}, "minItems": 1, "maxItems": 5},
            "safety_flags": {"type": "array", "items": {"type": "string"}, "maxItems": 5},
            "recommended_location_id": {"type": "string"},
            "allocation_reason": {"type": "string"}
        },
        "required": [
            "participant", "primary_need", "urgency", "availability", "pickup_name",
            "home_zone", "has_car", "wellbeing_signal", "summary", "evidence",
            "safety_flags", "recommended_location_id", "allocation_reason"
        ],
        "additionalProperties": False
    };
    request_body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": schema
        }
    };
    try {
        request = urllib.request.Request(
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
            data=json.dumps(request_body).encode("utf-8"),
            headers={"x-goog-api-key": api_key, "Content-Type": "application/json"},
            method="POST"
        );
        response = urllib.request.urlopen(request, timeout=45);
        response_data = json.loads(response.read().decode("utf-8"));
        output_text = response_data["candidates"][0]["content"]["parts"][0]["text"];
        interpreted = json.loads(output_text);
        interpreted["agent"] = "Gemini 2.5 Flash";
        interpreted["consent_scope"] = "Use consultation details only for service coordination and safe transportation";
        interpreted["raw_transcript_retained"] = True;
        return interpreted;
    } except Exception as e {
        return {"error": "Gemini interpretation failed: " + str(e), "code": "gemini_request_failed"};
    }
}

# ========================================
# Public API
# ========================================

def:pub api_pickup_points() -> list[dict] {
    return _pickup_points();
}

def:pub api_destinations() -> list[dict] {
    return _destinations_list();
}

def:pub api_fleet_state() -> dict {
    return _serialize_state(None);
}

def:pub api_consultation_scenarios() -> list[dict] {
    return _consultation_scenarios();
}

def:pub api_request_ride(
    name: str, note: str, availability: str, has_car: bool, need: str,
    pickup_name: str, pickup_lat: float, pickup_lng: float, dest_id: str,
    transcript: str = "", interpretation: dict = {}
) -> dict {
    location = get_location(dest_id);
    if location == None {
        return {"error": "Destination not found"};
    }
    if location.capacity_used >= location.capacity_total {
        return {"error": "Selected location is currently at capacity"};
    }
    dest_lat = location.lat;
    dest_lng = location.lng;

    req = root ++> RideRequest(
        participant=name, note=note, availability=availability, has_car=has_car, need=need,
        pickup_name=pickup_name, pickup_lat=pickup_lat, pickup_lng=pickup_lng,
        dest_name=location.name, dest_type=location.service_type, dest_lat=dest_lat, dest_lng=dest_lng,
        transcript=transcript, interpretation=interpretation, location_id=location.location_id,
        visit_cost=location.visit_cost, points_reward=location.points_reward,
        upskill_category=location.category
    );

    rider_miles = calculate_distance_miles(pickup_lat, pickup_lng, dest_lat, dest_lng);

    if has_car {
        req.status = "self_transport";
        req.decision = "Participant has a car — self-transport recommended; AV capacity preserved for riders who need it.";
        req.distance_miles = round(rider_miles, 1);
        req.eta_min = _eta_min(rider_miles);
        req.route = [[pickup_lat, pickup_lng], [dest_lat, dest_lng]];
    } else {
        av = dispatch_av(pickup_lat, pickup_lng);
        if isinstance(av, AV) {
            approach = calculate_distance_miles(av.lat, av.lng, pickup_lat, pickup_lng);
            total = approach + rider_miles;
            av.seats_used = av.seats_used + 1;
            av.status = "enroute";
            req.av_name = av.name;
            req.status = "dispatched";
            req.decision = av.name + " dispatched (" + str(round(approach, 1)) + " mi to pickup) — " + str(av.seats_total - av.seats_used) + " of " + str(av.seats_total) + " seats left.";
            req.distance_miles = round(total, 1);
            req.eta_min = _eta_min(total);
            req.route = [[av.lat, av.lng], [pickup_lat, pickup_lng], [dest_lat, dest_lng]];
        } else {
            req.status = "queued";
            req.decision = "All AVs at capacity — request queued and a caseworker was notified.";
            req.distance_miles = round(rider_miles, 1);
            req.eta_min = _eta_min(rider_miles);
            req.route = [[pickup_lat, pickup_lng], [dest_lat, dest_lng]];
        }
    }

    location.capacity_used = location.capacity_used + 1;
    nt = _next_type(location.service_type);
    rec = _nearest_stop_of_type(nt, dest_lat, dest_lng, location.location_id);
    if len(rec) > 0 {
        rec["reason"] = "After " + _service_label(location.service_type) + ", a common next step is " + _service_label(nt) + " — nearest is " + (rec["name"] as str) + ".";
    }
    req.next_service = rec;

    return _serialize_state(req);
}

def:pub api_ingest_consultation(scenario_id: str, transcript: str) -> dict {
    scenario_exists = False;
    for scenario in _consultation_scenarios() {
        if (scenario["id"] as str) == scenario_id {
            scenario_exists = True;
        }
    }
    if not scenario_exists {
        return {"error": "Consultation scenario not found"};
    }
    if transcript.strip() == "" {
        return {"error": "Transcript is required"};
    }

    if os.getenv("GEMINI_API_KEY", "") == "" {
        interpretation = _preset_demo_interpretation(scenario_id);
    } else {
        interpretation = _gemini_interpret_transcript(transcript);
    }
    if "error" in interpretation {
        return interpretation;
    }

    pickup_name = interpretation["pickup_name"] as str;
    pickup_lat = 0.0;
    pickup_lng = 0.0;
    pickup_found = False;
    for pp in _pickup_points() {
        if (pp["name"] as str) == pickup_name {
            pickup_lat = pp["lat"] as float;
            pickup_lng = pp["lng"] as float;
            pickup_found = True;
        }
    }
    if not pickup_found {
        return {"error": "Gemini returned an unknown pickup location", "code": "invalid_gemini_output"};
    }

    destination_id = interpretation["recommended_location_id"] as str;
    destination = get_location(destination_id);
    if destination == None {
        return {"error": "Gemini returned a location outside the approved catalogue", "code": "invalid_gemini_output"};
    }

    participant_name = interpretation["participant"] as str;
    participant = get_neighbor(participant_name);
    if participant == None {
        participant = root ++> Neighbor(
            name=participant_name,
            points_balance=50,
            home_zone=interpretation["home_zone"] as str,
            points_initialized=True
        );
    }

    interpretation["transportation_barrier"] = "No personal vehicle" if not (interpretation["has_car"] as bool) else "Self-transport available";
    interpretation["recommended_service"] = destination.name;
    interpretation["recommended_service_type"] = destination.service_type;
    interpretation["recommended_location_category"] = destination.category;
    interpretation["visit_cost"] = destination.visit_cost;
    interpretation["points_reward"] = destination.points_reward;
    interpretation["net_points"] = destination.points_reward - destination.visit_cost;
    interpretation["starting_balance"] = participant.points_balance;

    state = api_request_ride(
        participant_name,
        interpretation["summary"] as str,
        interpretation["availability"] as str,
        interpretation["has_car"] as bool,
        interpretation["primary_need"] as str,
        pickup_name,
        pickup_lat,
        pickup_lng,
        destination_id,
        transcript,
        interpretation
    );
    state["interpretation"] = interpretation;
    state["ingested_transcript"] = transcript;
    state["gemini_model"] = interpretation["agent"];
    return state;
}

def:pub api_complete_pathway_visit(request_id: str) -> dict {
    target: RideRequest | None = None;
    for request in [root-->][?:RideRequest] {
        if jid(request) == request_id {
            target = request;
        }
    }
    if target == None {
        return {"error": "Pathway request not found"};
    }
    if getattr(target, "completed", False) {
        return {"error": "This visit has already been completed"};
    }

    participant = get_neighbor(target.participant);
    if participant == None {
        return {"error": "Participant is not enrolled in the points program"};
    }
    if participant.points_balance < target.visit_cost {
        return {"error": "Participant does not have enough points for this visit"};
    }

    participant.points_balance = participant.points_balance - target.visit_cost + target.points_reward;
    participant.points_spent = participant.points_spent + target.visit_cost;
    participant.points_earned = participant.points_earned + target.points_reward;
    target.completed = True;
    target.status = "completed";

    location = get_location(target.location_id);
    if isinstance(location, PathwayLocation) and location.capacity_used > 0 {
        location.capacity_used = location.capacity_used - 1;
    }
    if target.av_name != "" {
        for vehicle in [root-->][?:AV] {
            if vehicle.name == target.av_name and vehicle.seats_used > 0 {
                vehicle.seats_used = vehicle.seats_used - 1;
                if vehicle.seats_used == 0 {
                    vehicle.status = "idle";
                }
            }
        }
    }

    completed_at = datetime.now().strftime("%m/%d/%Y %H:%M");
    root ++> Trip(
        trip_id=target.participant + "-" + target.location_id + "-" + completed_at,
        neighbor_name=target.participant,
        stop_name=target.dest_name,
        cost=target.visit_cost,
        bonus=target.points_reward,
        feeling="Not recorded",
        notes=target.note,
        notes_saved_at=completed_at
    );

    return {
        "status": "completed",
        "request_id": request_id,
        "participant": participant.name,
        "visit_cost": target.visit_cost,
        "points_reward": target.points_reward,
        "net_points": target.points_reward - target.visit_cost,
        "new_balance": participant.points_balance,
        "transition_status": "ready_for_review" if participant.points_balance >= 150 else "in_progress",
        "state": _serialize_state(target)
    };
}

def:pub api_reset_fleet() -> dict {
    for r in [root-->][?:RideRequest] {
        r.status = "cleared";
    }
    for v in [root-->][?:AV] {
        v.seats_used = 0;
        v.status = "idle";
    }
    for location in get_all_locations() {
        location.capacity_used = 0;
    }
    return _serialize_state(None);
}

# ========================================
# Boot — seed fleet once when server starts
# ========================================

with entry {
    seed_fleet_data();
    seed_location_catalog();
}
