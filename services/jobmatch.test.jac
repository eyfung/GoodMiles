# Test annex for services/jobmatch.sv.jac — sees the module's declarations
# without imports. Run with `jac test services/jobmatch.sv.jac`.
# Note: tests share a persisted root across a run (see jac-testing) — run
# `jac clean --all --force` first if results look stale.

test "keyword classifier maps notes to categories" {
    assert _classify_keyword("worked kitchen prep at a diner") == JobCategory.KITCHEN;
    assert _classify_keyword("forklift operator in a warehouse") == JobCategory.WAREHOUSE;
    assert _classify_keyword("front desk receptionist experience") == JobCategory.ADMIN;
    assert _classify_keyword("hotel housekeeping for three years") == JobCategory.HOSPITALITY;
}

test "haversine distance is directionally sane" {
    d_same = calculate_distance_km(37.7749, -122.4194, 37.7749, -122.4194);
    assert d_same < 0.001;

    d_near = calculate_distance_km(37.7749, -122.4194, 37.7839, -122.4194);
    d_far = calculate_distance_km(37.7749, -122.4194, 34.0522, -118.2437);
    assert d_far > d_near;
}

test "find_best_jobs ranks category match before distance, then by distance" {
    center = root ++> CommunityCenter(
        name="Test Center", address="1 Test St", lat=37.7749, lng=-122.4194
    );

    near_match = root ++> Job(
        title="Near Kitchen Job", employer_name="Test Co A", category=JobCategory.KITCHEN,
        address="", lat=37.7750, lng=-122.4195, wage_hint=""
    );
    far_match = root ++> Job(
        title="Far Kitchen Job", employer_name="Test Co B", category=JobCategory.KITCHEN,
        address="", lat=37.9000, lng=-122.6000, wage_hint=""
    );
    near_nomatch = root ++> Job(
        title="Near Warehouse Job", employer_name="Test Co C", category=JobCategory.WAREHOUSE,
        address="", lat=37.7751, lng=-122.4196, wage_hint=""
    );

    seeker = root ++> JobSeeker(name="Test Seeker", notes="kitchen experience", category=JobCategory.KITCHEN);
    seeker +>:VISITED():+> center;

    result = root spawn find_best_jobs(seeker_id=jid(seeker));
    assert len(result.reports) > 0;
    matches = result.reports[0];

    target_ids = [jid(near_match), jid(far_match), jid(near_nomatch)];
    filtered = [m for m in matches if (m["job_id"] as str) in target_ids];

    assert len(filtered) == 3;
    assert (filtered[0]["job_id"] as str) == jid(near_match);
    assert (filtered[1]["job_id"] as str) == jid(far_match);
    assert (filtered[2]["job_id"] as str) == jid(near_nomatch);
}
