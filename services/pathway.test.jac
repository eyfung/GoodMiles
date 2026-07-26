# Test annex for services/pathway.sv.jac — sees the module's declarations
# (including imports like ServiceStop) without imports.
# Note: tests share a persisted root across a run — run
# `jac clean --all --force` first if results look stale.

test "keyword classifier maps notes to categories" {
    assert _classify_keyword("worked kitchen prep at a diner") == JobCategory.KITCHEN;
    assert _classify_keyword("forklift operator in a warehouse") == JobCategory.WAREHOUSE;
    assert _classify_keyword("front desk receptionist experience") == JobCategory.ADMIN;
    assert _classify_keyword("hotel housekeeping for three years") == JobCategory.HOSPITALITY;
}

test "transit feasibility blocks pre-dawn shifts without a car" {
    before = check_transit_feasibility(4, False);
    assert not (before["ok"] as bool);
    ok_shift = check_transit_feasibility(8, False);
    assert ok_shift["ok"] as bool;
    with_car = check_transit_feasibility(4, True);
    assert with_car["ok"] as bool;
}

test "infeasible jobs are rejected with a reason" {
    p = root ++> Participant(
        name="Test Feasibility", notes="warehouse loading", category=JobCategory.WAREHOUSE,
        availability="morning", has_car=False, documents=["id"], needs_income=True
    );
    overnight = root ++> Job(
        title="Overnight Loader", employer_name="Test Freight", category=JobCategory.WAREHOUSE,
        address="1 Dock Rd", zone="south", lat=37.7, lng=-122.4, open_spots=1, wage_hint="",
        shift_start_hour=4, shift_label="Overnight 4am–12pm", required_docs=[], required_items=[]
    );
    ev = evaluate_job_feasibility(overnight, p);
    assert not (ev["feasible"] as bool);
    assert len(ev["reasons"] as list) > 0;
}

test "build_pathway selects a feasible job, resolves barriers, and awaits consent" {
    stop = root ++> ServiceStop(
        name="Test Center A", stop_type="jobs", zone="north", base_cost=0, bonus_on_visit=0
    );
    kitchen = root ++> Job(
        title="Test Kitchen", employer_name="Test Diner", category=JobCategory.KITCHEN,
        address="1 Test St", zone="north", lat=37.786, lng=-122.411, open_spots=1, wage_hint="$18/hr",
        shift_start_hour=8, shift_label="Morning 8am–2pm",
        required_docs=["resume"], required_items=["work_shoes"]
    );
    shoes = root ++> SupportResource(
        name="Test Closet", resource_type="work_shoes", provider="Test Shelter",
        zone="north", capacity=3
    );
    p = root ++> Participant(
        name="Test Maya", notes="restaurant experience", category=JobCategory.KITCHEN,
        availability="morning", has_car=False, documents=["id"], needs_income=True
    );
    p +>:VISITED():+> stop;

    res = api_build_pathway(jid(p));
    assert (res["status"] as str) == "active";
    assert (res["selected"]["title"] as str) == "Test Kitchen";
    # résumé + work-shoe barriers detected and resolved
    assert len(res["barriers"] as list) == 2;
    # a work-shoe reservation really decremented the resource
    assert shoes.capacity == 2;
    # at least one step is awaiting consent before submission
    assert (res["counts"]["awaiting_consent"] as int) >= 1;
}

test "replan keeps completed progress and switches to a feasible alternative" {
    stop = root ++> ServiceStop(
        name="Test Center B", stop_type="jobs", zone="north", base_cost=0, bonus_on_visit=0
    );
    kitchen = root ++> Job(
        title="Replan Kitchen", employer_name="Diner B", category=JobCategory.KITCHEN,
        address="2 Test St", zone="north", lat=37.786, lng=-122.411, open_spots=1, wage_hint="$18/hr",
        shift_start_hour=8, shift_label="Morning 8am–2pm",
        required_docs=["resume"], required_items=["work_shoes"]
    );
    hotel = root ++> Job(
        title="Replan Hotel", employer_name="Inn B", category=JobCategory.HOSPITALITY,
        address="3 Test St", zone="north", lat=37.787, lng=-122.408, open_spots=1, wage_hint="$18/hr",
        shift_start_hour=9, shift_label="Morning 9am–3pm",
        required_docs=["resume"], required_items=["work_shoes"]
    );
    shoes = root ++> SupportResource(
        name="Test Closet B", resource_type="work_shoes", provider="Shelter B",
        zone="north", capacity=3
    );
    p = root ++> Participant(
        name="Replan Maya", notes="restaurant experience", category=JobCategory.KITCHEN,
        availability="morning", has_car=False, documents=["id"], needs_income=True
    );
    p +>:VISITED():+> stop;

    built = api_build_pathway(jid(p));
    assert (built["selected"]["title"] as str) == "Replan Kitchen";
    cap_after_build = shoes.capacity;

    replanned = api_replan(built["pathway_id"] as str);
    # switched away from the filled kitchen job
    assert (replanned["selected"]["title"] as str) != "Replan Kitchen";
    # replan history explains the change
    assert len(replanned["replan_history"] as list) == 1;
    # completed prep was preserved: the work-shoe reservation was NOT re-reserved
    assert shoes.capacity == cap_after_build;
}
