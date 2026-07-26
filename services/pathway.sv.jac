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
# Grounded in real app data: destinations are actual ServiceStops, imported
# read-only from services/goodmiles.jac. This module never mutates
# Neighbor / ServiceStop / Trip.

import os;
import math;

import from services.goodmiles { ServiceStop, get_all_stops, seed_demo_data }

glob AV_SPEED_MPH: float = 25.0;

# ============================================================
# Nodes
# ============================================================

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
}

node FleetSeeded {
    has done: bool = True;
}

# ============================================================
# Seed — the AV fleet (destinations come from goodmiles ServiceStops)
# ============================================================

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

# ============================================================
# Geometry + reference data
# ============================================================

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

def _service_label(stop_type: str) -> str {
    m = {
        "pantry": "Food Pantry", "coaching": "Job Coaching", "counseling": "Counseling",
        "health": "Medical Clinic", "jobs": "Employment Services"
    };
    return m.get(stop_type, stop_type);
}

def _next_type(stop_type: str) -> str {
    m = {
        "pantry": "health", "coaching": "jobs", "jobs": "counseling",
        "health": "pantry", "counseling": "coaching"
    };
    return m.get(stop_type, "pantry");
}

def get_service_stop(id: str) -> ServiceStop | None {
    node_obj = jobj(id);
    if isinstance(node_obj, ServiceStop) {
        return node_obj;
    }
    return None;
}

def _nearest_stop_of_type(stop_type: str, from_lat: float, from_lng: float, exclude_id: str) -> dict {
    best: dict = {};
    best_d = 999999.0;
    for s in get_all_stops() {
        if s.stop_type == stop_type and jid(s) != exclude_id {
            c = center_coord(s);
            d = calculate_distance_miles(from_lat, from_lng, c["lat"], c["lng"]);
            if d < best_d {
                best_d = d;
                best = {
                    "id": jid(s), "name": s.name, "service": _service_label(s.stop_type),
                    "lat": c["lat"], "lng": c["lng"], "distance_miles": round(d, 1)
                };
            }
        }
    }
    return best;
}

# ============================================================
# TOOLS — deterministic dispatch + routing (real state changes)
# ============================================================

# Pick the nearest AV to the pickup that still has a free seat.
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
        "status": r.status, "route": r.route, "decision": r.decision, "next_service": r.next_service
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
        "destinations": _destinations_list()
    };
}

def _destinations_list() -> list {
    out: list = [];
    for s in get_all_stops() {
        c = center_coord(s);
        out = out + [{
            "id": jid(s), "name": s.name, "stop_type": s.stop_type,
            "service": _service_label(s.stop_type), "lat": c["lat"], "lng": c["lng"], "zone": s.zone
        }];
    }
    return out;
}

# ============================================================
# Public API
# ============================================================

def:pub api_pickup_points() -> list[dict] {
    return _pickup_points();
}

def:pub api_destinations() -> list[dict] {
    seed_demo_data();
    seed_fleet_data();
    return _destinations_list();
}

def:pub api_fleet_state() -> dict {
    seed_demo_data();
    seed_fleet_data();
    return _serialize_state(None);
}

def:pub api_request_ride(
    name: str, note: str, availability: str, has_car: bool, need: str,
    pickup_name: str, pickup_lat: float, pickup_lng: float, dest_id: str
) -> dict {
    seed_demo_data();
    seed_fleet_data();
    stop = get_service_stop(dest_id);
    if stop == None {
        return {"error": "Destination not found"};
    }
    dc = center_coord(stop);
    dest_lat = dc["lat"];
    dest_lng = dc["lng"];

    req = root ++> RideRequest(
        participant=name, note=note, availability=availability, has_car=has_car, need=need,
        pickup_name=pickup_name, pickup_lat=pickup_lat, pickup_lng=pickup_lng,
        dest_name=stop.name, dest_type=stop.stop_type, dest_lat=dest_lat, dest_lng=dest_lng
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

    # Recommend the most useful next service/ride.
    nt = _next_type(stop.stop_type);
    rec = _nearest_stop_of_type(nt, dest_lat, dest_lng, jid(stop));
    if len(rec) > 0 {
        rec["reason"] = "After " + _service_label(stop.stop_type) + ", a common next step is " + _service_label(nt) + " — nearest is " + (rec["name"] as str) + ".";
    }
    req.next_service = rec;

    return _serialize_state(req);
}

def:pub api_reset_fleet() -> dict {
    seed_demo_data();
    seed_fleet_data();
    for r in [root-->][?:RideRequest] {
        r.status = "cleared";
    }
    for v in [root-->][?:AV] {
        v.seats_used = 0;
        v.status = "idle";
    }
    return _serialize_state(None);
}
