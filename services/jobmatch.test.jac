# Test annex for services/jobmatch.sv.jac — sees the module's declarations
# (including imports like ServiceStop) without imports. Run with
# `jac test services/jobmatch.sv.jac`.
# Note: tests share a persisted root across a run (see jac-testing) — run
# `jac clean --all --force` first if results look stale.

test "keyword classifier maps notes to categories" {
    assert _classify_keyword("worked kitchen prep at a diner") == JobCategory.KITCHEN;
    assert _classify_keyword("forklift operator in a warehouse") == JobCategory.WAREHOUSE;
    assert _classify_keyword("front desk receptionist experience") == JobCategory.ADMIN;
    assert _classify_keyword("hotel housekeeping for three years") == JobCategory.HOSPITALITY;
}

test "distance in miles is directionally sane" {
    d_same = calculate_distance_miles(37.7749, -122.4194, 37.7749, -122.4194);
    assert d_same < 0.01;

    d_near = calculate_distance_miles(37.7749, -122.4194, 37.7839, -122.4194);
    d_far = calculate_distance_miles(37.7749, -122.4194, 34.0522, -118.2437);
    assert d_far > d_near;
}

test "find_best_jobs ranks category match first, then by distance, and tallies open spots" {
    stop = root ++> ServiceStop(
        name="Test Stop", stop_type="jobs", zone="north", base_cost=0, bonus_on_visit=0
    );

    near_match = root ++> Job(
        title="Near Kitchen Job", employer_name="Test Co A", category=JobCategory.KITCHEN,
        address="1 Near St", zone="north", lat=37.7855, lng=-122.4115, open_spots=2, wage_hint=""
    );
    far_match = root ++> Job(
        title="Far Kitchen Job", employer_name="Test Co B", category=JobCategory.KITCHEN,
        address="2 Far St", zone="south", lat=37.9000, lng=-122.6000, open_spots=3, wage_hint=""
    );
    near_nomatch = root ++> Job(
        title="Near Warehouse Job", employer_name="Test Co C", category=JobCategory.WAREHOUSE,
        address="3 Near Ave", zone="north", lat=37.7860, lng=-122.4120, open_spots=5, wage_hint=""
    );

    seeker = root ++> JobSeeker(name="Test Seeker", notes="kitchen experience", category=JobCategory.KITCHEN);
    seeker +>:VISITED():+> stop;

    result = root spawn find_best_jobs(seeker_id=jid(seeker));
    assert len(result.reports) > 0;
    report0 = result.reports[0];
    matches = report0["matches"];

    target_ids = [jid(near_match), jid(far_match), jid(near_nomatch)];
    filtered = [m for m in matches if (m["job_id"] as str) in target_ids];

    assert len(filtered) == 3;
    assert (filtered[0]["job_id"] as str) == jid(near_match);
    assert (filtered[1]["job_id"] as str) == jid(far_match);
    assert (filtered[2]["job_id"] as str) == jid(near_nomatch);

    # Report surfaces the origin center, a single recommended hop, and spot tallies.
    assert (report0["origin"]["name"] as str) == "Test Stop";
    assert (report0["recommended"]["job_id"] as str) == jid(near_match);
    # near_match carries a real place string and a distance in miles.
    assert "Test Co A" in (filtered[0]["place"] as str);
    assert (filtered[0]["distance_miles"] as float) >= 0.0;
    # total open spots counts every open job the walker found (>= our 3 test spots).
    assert (report0["total_open_spots"] as int) >= 10;
}
