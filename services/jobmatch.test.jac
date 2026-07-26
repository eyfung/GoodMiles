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

test "zone_distance grows with zone separation" {
    assert zone_distance("north", "north") == 0;
    assert zone_distance("north", "central") == 1;
    assert zone_distance("north", "south") == 2;
    assert zone_distance("north", "south") > zone_distance("north", "central");
    assert zone_distance("north", "nowhere") == 99;
}

test "find_best_jobs ranks category match before zone, then by zone proximity" {
    stop = root ++> ServiceStop(
        name="Test Stop", stop_type="jobs", zone="north", base_cost=0, bonus_on_visit=0
    );

    same_match = root ++> Job(
        title="Same-zone Kitchen Job", employer_name="Test Co A", category=JobCategory.KITCHEN,
        address="", zone="north", wage_hint=""
    );
    far_match = root ++> Job(
        title="Far Kitchen Job", employer_name="Test Co B", category=JobCategory.KITCHEN,
        address="", zone="south", wage_hint=""
    );
    same_nomatch = root ++> Job(
        title="Same-zone Warehouse Job", employer_name="Test Co C", category=JobCategory.WAREHOUSE,
        address="", zone="north", wage_hint=""
    );

    seeker = root ++> JobSeeker(name="Test Seeker", notes="kitchen experience", category=JobCategory.KITCHEN);
    seeker +>:VISITED():+> stop;

    result = root spawn find_best_jobs(seeker_id=jid(seeker));
    assert len(result.reports) > 0;
    report0 = result.reports[0];
    matches = report0["matches"];

    target_ids = [jid(same_match), jid(far_match), jid(same_nomatch)];
    filtered = [m for m in matches if (m["job_id"] as str) in target_ids];

    assert len(filtered) == 3;
    assert (filtered[0]["job_id"] as str) == jid(same_match);
    assert (filtered[1]["job_id"] as str) == jid(far_match);
    assert (filtered[2]["job_id"] as str) == jid(same_nomatch);

    # Report also surfaces the origin center and a single recommended hop.
    assert (report0["origin"]["name"] as str) == "Test Stop";
    assert (report0["recommended"]["job_id"] as str) == jid(same_match);
}
