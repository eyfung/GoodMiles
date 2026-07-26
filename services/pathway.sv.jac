# Pathway — agentic employment-pathway coordinator (community-center dashboard)
#
# Given a participant's profile (skills, availability, transport, documents,
# income need) the agent does NOT just recommend jobs. It:
#   find realistic jobs -> reject infeasible ones with reasons -> select the
#   strongest -> detect barriers -> match community resources -> build an
#   ordered pathway -> execute approved actions with tools -> hold for consent
#   -> and REPLAN automatically when a step fails (e.g. the job fills),
#   preserving completed progress and escalating to a caseworker when no
#   realistic pathway exists.
#
# Deterministic code owns hard requirements (schedules, transit windows,
# required documents). The LLM is used ONLY to interpret free-text experience
# into a job category (with a keyword fallback when no key is configured).
# Grounded in real app data: intake happens at an actual ServiceStop, imported
# read-only from services/goodmiles.jac. This module never mutates
# Neighbor / ServiceStop / Trip.

import os;
import math;

import from services.goodmiles { ServiceStop, get_all_stops, seed_demo_data }

# ============================================================
# Constants — hard, deterministic rules
# ============================================================

glob TRANSIT_START_HOUR: int = 6;   # public transit begins at 06:00

# ============================================================
# Node / edge / enum definitions
# ============================================================

node Participant {
    has name: str;
    has notes: str;
    has category: str;
    has availability: str = "any";       # morning | afternoon | evening | any
    has has_car: bool = False;
    has documents: list[str] = [];       # e.g. ["id", "resume"]
    has needs_income: bool = False;
}

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
    has shift_start_hour: int = 9;
    has shift_label: str = "";
    has required_docs: list[str] = [];   # e.g. ["resume", "id"]
    has required_items: list[str] = [];  # e.g. ["work_shoes"]
    has is_open: bool = True;
}

node SupportResource {
    has name: str;
    has resource_type: str;   # work_shoes | id | transit_pass | childcare
    has provider: str;
    has zone: str;
    has capacity: int;
    has is_open: bool = True;
}

node Pathway {
    has participant_id: str;
    has participant_name: str;
    has center_name: str;
    has center_zone: str;
    has origin: dict = {};
    has goal: str = "";
    has status: str = "active";          # active | escalated
    has selected: dict = {};
    has feasibility_reason: str = "";
    has rejected: list[dict] = [];
    has barriers: list[dict] = [];
    has resolved_barriers: list[str] = [];
    has steps: list[dict] = [];
    has activity_log: list[dict] = [];
    has caseworker_tasks: list[dict] = [];
    has replan_history: list[dict] = [];
    has log_seq: int = 0;
}

node PathwaySeeded {
    has done: bool = True;
}

edge VISITED: Participant --> ServiceStop {}

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

# ============================================================
# Seed data (idempotent) — open jobs + community resources
# ============================================================

def seed_pathway_data {
    existing = [root-->][?:PathwaySeeded];
    if len(existing) > 0 {
        return;
    }
    root ++> PathwaySeeded();

    root ++> Job(
        title="Kitchen Prep Assistant", employer_name="Golden Spoon Diner",
        category=JobCategory.KITCHEN, address="10 Market St, San Francisco, CA",
        zone="north", lat=37.7879, lng=-122.4074, open_spots=2, wage_hint="$18/hr",
        shift_start_hour=8, shift_label="Morning 8am–2pm",
        required_docs=["resume"], required_items=["work_shoes"]
    );
    root ++> Job(
        title="Event Cleanup Worker", employer_name="Civic Hall Events Co.",
        category=JobCategory.CLEANING, address="99 Civic Center Plz, San Francisco, CA",
        zone="central", lat=37.7793, lng=-122.4193, open_spots=4, wage_hint="$17/hr",
        shift_start_hour=18, shift_label="Evening 6pm–11pm",
        required_docs=["resume"], required_items=[]
    );
    root ++> Job(
        title="Warehouse Associate", employer_name="Bay Area Logistics Partners",
        category=JobCategory.WAREHOUSE, address="500 SoMa Way, San Francisco, CA",
        zone="south", lat=37.7749, lng=-122.4034, open_spots=3, wage_hint="$19/hr",
        shift_start_hour=4, shift_label="Overnight 4am–12pm",
        required_docs=["resume"], required_items=["work_shoes"]
    );
    root ++> Job(
        title="Hotel Housekeeping", employer_name="Union Square Inn",
        category=JobCategory.HOSPITALITY, address="20 Union Sq, San Francisco, CA",
        zone="north", lat=37.7880, lng=-122.4075, open_spots=1, wage_hint="$18.50/hr",
        shift_start_hour=9, shift_label="Morning 9am–3pm",
        required_docs=["resume"], required_items=["work_shoes"]
    );
    root ++> Job(
        title="Grocery Stocker", employer_name="Mission Market Grocers",
        category=JobCategory.RETAIL, address="300 Mission St, San Francisco, CA",
        zone="south", lat=37.7599, lng=-122.4148, open_spots=2, wage_hint="$17.50/hr",
        shift_start_hour=7, shift_label="Morning 7am–1pm",
        required_docs=["resume"], required_items=[]
    );
    root ++> Job(
        title="Community Center Receptionist", employer_name="Bayview Family Resource Center",
        category=JobCategory.ADMIN, address="88 Bayview Blvd, San Francisco, CA",
        zone="central", lat=37.7300, lng=-122.3850, open_spots=1, wage_hint="$18/hr",
        shift_start_hour=9, shift_label="Morning 9am–5pm",
        required_docs=["resume", "id"], required_items=[]
    );

    root ++> SupportResource(
        name="Community Closet", resource_type="work_shoes",
        provider="Eastside Neighborhood Shelter", zone="central", capacity=6
    );
    root ++> SupportResource(
        name="Fresh Threads Clothing Bank", resource_type="work_shoes",
        provider="Bayview Family Resource Center", zone="south", capacity=4
    );
    root ++> SupportResource(
        name="ID Access Clinic", resource_type="id",
        provider="City Community Services", zone="central", capacity=5
    );
    root ++> SupportResource(
        name="Transit Pass Program", resource_type="transit_pass",
        provider="Muni Access", zone="north", capacity=10
    );
}

# ============================================================
# Distance — real miles from a center to a job
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

# ============================================================
# Category classification — LLM interprets free text, human confirms
# ============================================================

def _classify_llm(notes: str) -> JobCategory by llm();
sem _classify_llm = "Classify a participant's free-text experience notes into the single best-fit job category. This is only a SUGGESTION a human caseworker reviews and can override.";
sem _classify_llm.notes = "Free-text notes about the person's work experience, availability, and preferences.";

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

# ============================================================
# Small utilities
# ============================================================

def _join(items: list, sep: str) -> str {
    out = "";
    i = 0;
    while i < len(items) {
        if i > 0 {
            out = out + sep;
        }
        out = out + (items[i] as str);
        i = i + 1;
    }
    return out;
}

def _labels(items: list) -> list {
    out: list = [];
    for s in items {
        out = out + [s["label"] as str];
    }
    return out;
}

def _barrier_label(kind: str) -> str {
    m = {
        "resume": "Needs a résumé",
        "work_shoes": "Needs work shoes",
        "id": "Needs a photo ID",
        "transit_pass": "Needs a transit pass",
        "childcare": "Needs childcare",
    };
    return m.get(kind, "Needs " + kind);
}

def shift_window(hour: int) -> str {
    if hour < 11 {
        return "morning";
    }
    if hour < 16 {
        return "afternoon";
    }
    return "evening";
}

def get_service_stop(id: str) -> ServiceStop | None {
    node_obj = jobj(id);
    if isinstance(node_obj, ServiceStop) {
        return node_obj;
    }
    return None;
}

def _add_log(pw: Pathway, message: str) {
    pw.log_seq = pw.log_seq + 1;
    pw.activity_log = pw.activity_log + [{"seq": pw.log_seq, "message": message}];
}

def _mk_step(order: int, phase: str, kind: str, label: str, status: str, detail: str, requires_consent: bool) -> dict {
    return {
        "order": order, "phase": phase, "kind": kind, "label": label,
        "status": status, "detail": detail, "requires_consent": requires_consent
    };
}

# ============================================================
# TOOLS — deterministic actions that read/change real state
# ============================================================

def search_jobs() -> list[Job] {
    return [root-->][?:Job];
}

def check_job_availability(job: Job) -> bool {
    return job.is_open and job.open_spots > 0;
}

def check_transit_feasibility(shift_start_hour: int, has_car: bool) -> dict {
    if has_car {
        return {"ok": True, "reason": "Has a car"};
    }
    if shift_start_hour < TRANSIT_START_HOUR {
        return {"ok": False, "reason": f"Shift starts at {shift_start_hour}:00, before public transit begins ({TRANSIT_START_HOUR}:00)"};
    }
    return {"ok": True, "reason": "Transit-accessible shift"};
}

def evaluate_job_feasibility(job: Job, p: Participant) -> dict {
    if not check_job_availability(job) {
        return {"feasible": False, "reasons": ["Position already filled"]};
    }
    feasible = True;
    reasons: list = [];
    transit = check_transit_feasibility(job.shift_start_hour, p.has_car);
    if not (transit["ok"] as bool) {
        feasible = False;
        reasons = reasons + [transit["reason"] as str];
    }
    if p.availability != "any" and shift_window(job.shift_start_hour) != p.availability {
        feasible = False;
        reasons = reasons + [f"{job.shift_label} doesn't fit {p.availability} availability"];
    }
    return {"feasible": feasible, "reasons": reasons};
}

def search_support_resources(kind: str) -> list[SupportResource] {
    out: list[SupportResource] = [];
    for r in [root-->][?:SupportResource] {
        if r.resource_type == kind and r.is_open and r.capacity > 0 {
            out = out + [r];
        }
    }
    return out;
}

def reserve_support_resource(r: SupportResource) -> dict {
    if r.capacity > 0 {
        r.capacity = r.capacity - 1;
    }
    return {"name": r.name, "provider": r.provider, "remaining": r.capacity};
}

def create_resume_draft(p: Participant) -> dict {
    return {
        "participant": p.name,
        "headline": p.category + " worker",
        "summary": "Reliable " + p.category + " experience; " + p.availability + " availability.",
        "status": "draft"
    };
}

def create_application_draft(p: Participant, job: Job) -> dict {
    return {
        "participant": p.name,
        "job": job.title,
        "employer": job.employer_name,
        "status": "draft",
        "note": "Ready to submit pending consent"
    };
}

def schedule_interview(job_title: str) -> dict {
    return {"job": job_title, "when": "in 2 business days, 10:00 AM"};
}

def notify_participant(pw: Pathway, message: str) {
    _add_log(pw, "Notified participant: " + message);
}

def assign_caseworker_task(pw: Pathway, label: str, reason: str) {
    pw.caseworker_tasks = pw.caseworker_tasks + [{"label": label, "reason": reason, "status": "pending"}];
    _add_log(pw, "Escalated to caseworker: " + label);
}

# ============================================================
# Selection + barriers + planning
# ============================================================

def _job_to_dict(job: Job, origin: dict) -> dict {
    miles = calculate_distance_miles(origin["lat"], origin["lng"], job.lat, job.lng);
    return {
        "job_id": jid(job),
        "title": job.title,
        "employer_name": job.employer_name,
        "category": job.category,
        "place": job.employer_name + " — " + job.address,
        "address": job.address,
        "zone": job.zone,
        "shift_label": job.shift_label,
        "wage_hint": job.wage_hint,
        "open_spots": job.open_spots,
        "distance_miles": round(miles, 1)
    };
}

def _score_job(job: Job, p: Participant, origin: dict, resolved: list) -> float {
    score = 0.0;
    if job.category == p.category {
        score = score + 100.0;
    }
    reuse = len(job.required_items) > 0;
    for item in job.required_items {
        if item not in p.documents and item not in resolved {
            reuse = False;
        }
    }
    if reuse {
        score = score + 20.0;
    }
    miles = calculate_distance_miles(origin["lat"], origin["lng"], job.lat, job.lng);
    score = score - miles;
    return score;
}

def _why_feasible(job: Job, p: Participant) -> str {
    parts: list = [];
    if job.category == p.category {
        parts = parts + [f"Matches {p.category} experience"];
    }
    transit = check_transit_feasibility(job.shift_start_hour, p.has_car);
    parts = parts + [transit["reason"] as str];
    if p.availability != "any" {
        parts = parts + [f"{job.shift_label} fits {p.availability} availability"];
    } else {
        parts = parts + [job.shift_label];
    }
    return _join(parts, "; ");
}

def _run_selection(p: Participant, origin: dict, exclude_ids: list, resolved: list) -> dict {
    evaluated = 0;
    rejected: list = [];
    best: Job | None = None;
    best_score = -999999.0;
    for job in search_jobs() {
        if jid(job) not in exclude_ids {
            evaluated = evaluated + 1;
            ev = evaluate_job_feasibility(job, p);
            if ev["feasible"] as bool {
                s = _score_job(job, p, origin, resolved);
                if s > best_score {
                    best_score = s;
                    best = job;
                }
            } else {
                reason_str = _join(ev["reasons"] as list, "; ");
                rejected = rejected + [{
                    "title": job.title, "employer_name": job.employer_name, "reason": reason_str
                }];
            }
        }
    }
    return {"selected_node": best, "rejected": rejected, "evaluated": evaluated};
}

def detect_barriers(job: Job, p: Participant, resolved: list) -> list {
    out: list = [];
    for doc in job.required_docs {
        if doc not in p.documents and doc not in resolved {
            out = out + [{"kind": doc, "label": _barrier_label(doc), "resolved": False, "resource": {}}];
        }
    }
    for item in job.required_items {
        if item not in p.documents and item not in resolved {
            out = out + [{"kind": item, "label": _barrier_label(item), "resolved": False, "resource": {}}];
        }
    }
    return out;
}

def _goal_text(p: Participant) -> str {
    tail = "with steady income soon" if p.needs_income else "building toward stability";
    return "Start " + p.category + " work " + tail;
}

# Resolve one barrier with a real tool/state change; returns (step, resolved_barrier_record).
def _resolve_barrier(pw: Pathway, p: Participant, b: dict, order: int) -> dict {
    kind = b["kind"] as str;
    if kind == "resume" {
        _add_log(pw, "Résumé barrier detected");
        create_resume_draft(p);
        pw.resolved_barriers = pw.resolved_barriers + [kind];
        _add_log(pw, "Résumé draft created");
        b["resolved"] = True;
        b["resource"] = {"name": "Auto-generated résumé draft", "provider": "Pathway agent"};
        return {"step": _mk_step(order, "prep", "create_resume", "Create résumé draft", "completed", "Draft ready for review", False), "barrier": b, "resolved": True};
    }
    resources = search_support_resources(kind);
    if len(resources) > 0 {
        r = resources[0];
        _add_log(pw, _barrier_label(kind) + " detected");
        info = reserve_support_resource(r);
        pw.resolved_barriers = pw.resolved_barriers + [kind];
        _add_log(pw, r.name + " reserved");
        b["resolved"] = True;
        b["resource"] = {"name": r.name, "provider": r.provider};
        return {"step": _mk_step(order, "prep", "reserve_resource", "Reserve " + r.name + " (" + r.provider + ")", "completed", "Reserved — " + str(info["remaining"]) + " slots left", False), "barrier": b, "resolved": True};
    }
    assign_caseworker_task(pw, "Resolve " + _barrier_label(kind), "No community resource available for " + kind);
    b["resolved"] = False;
    b["resource"] = {};
    return {"step": _mk_step(order, "prep", "resolve_barrier", "Resolve: " + _barrier_label(kind), "blocked", "No resource available — escalated", False), "barrier": b, "resolved": False};
}

# Build the job-specific tail of the pathway (select -> transit -> application
# -> consent -> interview). Shared by initial planning and replanning.
def _build_job_steps(pw: Pathway, p: Participant, job: Job, start_order: int) -> list {
    steps: list = [];
    order = start_order;
    steps = steps + [_mk_step(order, "job", "select_job", "Matched to " + job.title + " at " + job.employer_name, "completed", pw.feasibility_reason, False)];
    order = order + 1;

    transit = check_transit_feasibility(job.shift_start_hour, p.has_car);
    if transit["ok"] as bool {
        steps = steps + [_mk_step(order, "job", "verify_transit", "Verify transit to interview", "completed", transit["reason"] as str, False)];
        _add_log(pw, "Transit to interview verified");
    } else {
        steps = steps + [_mk_step(order, "job", "verify_transit", "Verify transit to interview", "blocked", transit["reason"] as str, False)];
        assign_caseworker_task(pw, "Arrange transit to interview", transit["reason"] as str);
    }
    order = order + 1;

    create_application_draft(p, job);
    steps = steps + [_mk_step(order, "job", "create_application", "Draft job application", "completed", "Draft ready — not yet submitted", False)];
    order = order + 1;
    _add_log(pw, "Application draft created");

    steps = steps + [_mk_step(order, "job", "await_consent", "Await participant consent to submit application", "awaiting_consent", "Requires participant or caseworker approval", True)];
    order = order + 1;
    _add_log(pw, "Waiting for participant consent");

    steps = steps + [_mk_step(order, "job", "schedule_interview", "Schedule interview", "pending", "Blocked until consent is granted", False)];
    return steps;
}

def _plan_for_job(pw: Pathway, p: Participant, origin: dict, job: Job) {
    pw.selected = _job_to_dict(job, origin);
    pw.feasibility_reason = _why_feasible(job, p);
    _add_log(pw, job.title + " selected");

    steps: list = [];
    order = 1;
    steps = steps + [_mk_step(order, "job", "select_job", "Matched to " + job.title + " at " + job.employer_name, "completed", pw.feasibility_reason, False)];
    order = order + 1;

    # barriers -> resources
    barriers = detect_barriers(job, p, pw.resolved_barriers);
    pw.barriers = [];
    for b in barriers {
        res = _resolve_barrier(pw, p, b, order);
        steps = steps + [res["step"] as dict];
        pw.barriers = pw.barriers + [res["barrier"] as dict];
        order = order + 1;
    }

    # transit + application + consent + interview
    transit = check_transit_feasibility(job.shift_start_hour, p.has_car);
    if transit["ok"] as bool {
        steps = steps + [_mk_step(order, "job", "verify_transit", "Verify transit to interview", "completed", transit["reason"] as str, False)];
        _add_log(pw, "Transit to interview verified");
    } else {
        steps = steps + [_mk_step(order, "job", "verify_transit", "Verify transit to interview", "blocked", transit["reason"] as str, False)];
        assign_caseworker_task(pw, "Arrange transit to interview", transit["reason"] as str);
    }
    order = order + 1;

    create_application_draft(p, job);
    steps = steps + [_mk_step(order, "job", "create_application", "Draft job application", "completed", "Draft ready — not yet submitted", False)];
    order = order + 1;
    _add_log(pw, "Application draft created");

    steps = steps + [_mk_step(order, "job", "await_consent", "Await participant consent to submit application", "awaiting_consent", "Requires participant or caseworker approval", True)];
    order = order + 1;
    _add_log(pw, "Waiting for participant consent");

    steps = steps + [_mk_step(order, "job", "schedule_interview", "Schedule interview", "pending", "Blocked until consent is granted", False)];
    order = order + 1;

    steps = steps + [_mk_step(order, "prep", "caseworker_task", "Caseworker follow-up: confirm start date", "pending", "Assigned to caseworker", False)];
    pw.caseworker_tasks = pw.caseworker_tasks + [{"label": "Follow up with " + p.name + " on start date", "reason": "Post-placement support", "status": "pending"}];

    pw.steps = steps;
    pw.status = "active";
}

def _plan(pw: Pathway, p: Participant, origin: dict) {
    _add_log(pw, "Participant profile created");

    sel = _run_selection(p, origin, [], pw.resolved_barriers);
    pw.rejected = sel["rejected"] as list;
    _add_log(pw, str(sel["evaluated"] as int) + " jobs evaluated");
    _add_log(pw, str(len(pw.rejected)) + " jobs rejected because of schedule or transportation");

    best = sel["selected_node"];
    if isinstance(best, Job) {
        _plan_for_job(pw, p, origin, best);
    } else {
        pw.status = "escalated";
        assign_caseworker_task(pw, "No feasible job found — manual review", "No open position fits schedule and transportation");
        _add_log(pw, "No realistic pathway — escalated to caseworker");
    }
}

def _replan_for_job(pw: Pathway, p: Participant, origin: dict, job: Job, preserved: list, old_title: str) -> dict {
    pw.selected = _job_to_dict(job, origin);
    pw.feasibility_reason = _why_feasible(job, p);

    steps: list = [];
    order = 1;
    # keep preserved prep steps, renumbered
    for s in preserved {
        s2 = s;
        s2["order"] = order;
        steps = steps + [s2];
        order = order + 1;
    }

    # resolve any genuinely new barrier for the new job (reused ones are skipped)
    new_barriers = detect_barriers(job, p, pw.resolved_barriers);
    for b in new_barriers {
        res = _resolve_barrier(pw, p, b, order);
        steps = steps + [res["step"] as dict];
        pw.barriers = pw.barriers + [res["barrier"] as dict];
        order = order + 1;
    }

    # rebuild only the job-specific tail
    tail = _build_job_steps(pw, p, job, order);
    changed: list = [];
    for s in tail {
        s3 = s;
        s3["order"] = order;
        steps = steps + [s3];
        changed = changed + [s["label"] as str];
        order = order + 1;
    }

    steps = steps + [_mk_step(order, "prep", "caseworker_task", "Caseworker follow-up: confirm start date", "pending", "Assigned to caseworker", False)];
    pw.steps = steps;
    pw.status = "active";

    _add_log(pw, "Pathway replanned to " + job.title);
    notify_participant(pw, "Your pathway was updated to " + job.title + " — completed steps were kept");
    pw.replan_history = pw.replan_history + [{
        "from": old_title, "to": job.title, "reason": "Selected position filled",
        "preserved": _labels(preserved), "changed": changed
    }];
    return _serialize(pw);
}

# ============================================================
# Serialization for the dashboard
# ============================================================

def _serialize(pw: Pathway) -> dict {
    completed = 0; pending = 0; blocked = 0; failed = 0; consent_ct = 0;
    consent_pending: list = [];
    for s in pw.steps {
        st = s["status"] as str;
        if st == "completed" { completed = completed + 1; }
        elif st == "pending" { pending = pending + 1; }
        elif st == "blocked" { blocked = blocked + 1; }
        elif st == "failed" { failed = failed + 1; }
        elif st == "awaiting_consent" {
            consent_ct = consent_ct + 1;
            consent_pending = consent_pending + [s];
        }
    }
    return {
        "pathway_id": jid(pw),
        "participant_name": pw.participant_name,
        "center_name": pw.center_name,
        "goal": pw.goal,
        "status": pw.status,
        "selected": pw.selected,
        "feasibility_reason": pw.feasibility_reason,
        "rejected": pw.rejected,
        "barriers": pw.barriers,
        "steps": pw.steps,
        "activity_log": pw.activity_log,
        "caseworker_tasks": pw.caseworker_tasks,
        "replan_history": pw.replan_history,
        "consent_pending": consent_pending,
        "counts": {
            "completed": completed, "pending": pending, "blocked": blocked,
            "failed": failed, "awaiting_consent": consent_ct
        }
    };
}

# ============================================================
# Public API
# ============================================================

def:pub api_service_stops() -> list[dict] {
    seed_demo_data();
    seed_pathway_data();
    result: list[dict] = [];
    for s in get_all_stops() {
        result = result + [{
            "id": jid(s), "name": s.name, "zone": s.zone, "stop_type": s.stop_type
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

def:pub api_create_participant(
    name: str, notes: str, category: str, service_stop_id: str,
    availability: str, has_car: bool, has_resume: bool, needs_income: bool
) -> dict {
    seed_demo_data();
    seed_pathway_data();
    stop = get_service_stop(service_stop_id);
    if stop == None {
        return {"error": "Service stop not found"};
    }
    docs: list[str] = ["id"];
    if has_resume {
        docs = docs + ["resume"];
    }
    p = root ++> Participant(
        name=name, notes=notes, category=category, availability=availability,
        has_car=has_car, documents=docs, needs_income=needs_income
    );
    p +>:VISITED():+> stop;
    return {"id": jid(p), "name": p.name};
}

def:pub api_build_pathway(participant_id: str) -> dict {
    p = jobj(participant_id);
    if not isinstance(p, Participant) {
        return {"error": "Participant not found"};
    }
    stops = [p ->:VISITED:->];
    if len(stops) == 0 {
        return {"error": "No community center on file for this participant"};
    }
    center = stops[0];
    origin = center_coord(center);
    origin["name"] = center.name;
    origin["zone"] = center.zone;
    origin["stop_type"] = center.stop_type;
    pw = root ++> Pathway(
        participant_id=jid(p), participant_name=p.name,
        center_name=center.name, center_zone=center.zone,
        origin=origin, goal=_goal_text(p)
    );
    _plan(pw, p, origin);
    return _serialize(pw);
}

def:pub api_grant_consent(pathway_id: str) -> dict {
    pw = jobj(pathway_id);
    if not isinstance(pw, Pathway) {
        return {"error": "Pathway not found"};
    }
    new_steps: list = [];
    for s in pw.steps {
        st = s;
        if (s["kind"] as str) == "await_consent" and (s["status"] as str) == "awaiting_consent" {
            st["status"] = "completed";
            st["label"] = "Consent granted — application submitted";
            st["requires_consent"] = False;
            _add_log(pw, "Consent granted — application submitted");
        }
        if (s["kind"] as str) == "schedule_interview" and (s["status"] as str) == "pending" {
            sched = schedule_interview(pw.selected["title"] as str);
            st["status"] = "completed";
            st["detail"] = "Interview " + (sched["when"] as str);
            _add_log(pw, "Interview scheduled — " + (sched["when"] as str));
        }
        new_steps = new_steps + [st];
    }
    pw.steps = new_steps;
    return _serialize(pw);
}

# The most important agentic feature: detect a changed condition (the selected
# job filled), preserve completed progress, re-search, revise only the affected
# steps, explain what changed, and notify.
def:pub api_replan(pathway_id: str) -> dict {
    pw = jobj(pathway_id);
    if not isinstance(pw, Pathway) {
        return {"error": "Pathway not found"};
    }
    old = pw.selected;
    if not ("job_id" in old) {
        return {"error": "Nothing to replan"};
    }
    old_id = old["job_id"] as str;
    old_title = old["title"] as str;

    # Detect + apply the changed condition: the position filled (real state).
    oldjob = jobj(old_id);
    if isinstance(oldjob, Job) {
        oldjob.is_open = False;
        oldjob.open_spots = 0;
    }
    _add_log(pw, old_title + " became unavailable");

    p = jobj(pw.participant_id);
    if not isinstance(p, Participant) {
        return {"error": "Participant not found"};
    }
    origin = pw.origin;

    # Preserve completed prep (résumé, reservations) — do not restart.
    preserved: list = [];
    for s in pw.steps {
        if (s["phase"] as str) == "prep" and (s["status"] as str) == "completed" {
            preserved = preserved + [s];
        }
    }

    sel = _run_selection(p, origin, [old_id], pw.resolved_barriers);
    pw.rejected = sel["rejected"] as list;
    best = sel["selected_node"];
    if isinstance(best, Job) {
        return _replan_for_job(pw, p, origin, best, preserved, old_title);
    }

    # No feasible alternative — preserve progress, escalate, explain.
    pw.status = "escalated";
    failed_steps: list = [];
    for s in pw.steps {
        s2 = s;
        if (s["phase"] as str) == "job" {
            s2["status"] = "failed";
        }
        failed_steps = failed_steps + [s2];
    }
    pw.steps = failed_steps;
    assign_caseworker_task(pw, "No alternative job — manual review", "Selected position filled and no feasible alternative exists");
    _add_log(pw, "No alternative pathway — escalated to caseworker");
    pw.replan_history = pw.replan_history + [{
        "from": old_title, "to": "(none)", "reason": "Selected position filled",
        "preserved": _labels(preserved), "changed": []
    }];
    return _serialize(pw);
}
