# Test annex for services/pathway.sv.jac — sees the module's declarations
# (including imports like ServiceStop) without imports.
# Note: tests share a persisted root across a run — run
# `jac clean --all --force` first if results look stale.

test "distance in miles is directionally sane" {
    d0 = calculate_distance_miles(37.7749, -122.4194, 37.7749, -122.4194);
    assert d0 < 0.01;
    dn = calculate_distance_miles(37.7749, -122.4194, 37.7849, -122.4194);
    df = calculate_distance_miles(37.7749, -122.4194, 34.0522, -118.2437);
    assert df > dn;
}

test "dispatch picks the nearest AV that still has a free seat" {
    near = root ++> AV(name="AV-NEAR", seats_total=2, lat=40.0001, lng=-120.0001, zone="test");
    far = root ++> AV(name="AV-FAR", seats_total=2, lat=41.0, lng=-121.0, zone="test");
    full = root ++> AV(name="AV-FULL", seats_total=1, seats_used=1, lat=40.00002, lng=-120.00002, zone="test");
    chosen = dispatch_av(40.0, -120.0);
    assert isinstance(chosen, AV);
    if isinstance(chosen, AV) {
        # AV-FULL is closer but has no seat, so the nearest *available* wins
        assert chosen.name == "AV-NEAR";
    }
}

test "request_ride dispatches the nearest AV, consumes a seat, plans a 3-leg route, recommends next" {
    dests = api_destinations();
    dest = dests[0];
    myav = root ++> AV(name="AV-TESTDISPATCH", seats_total=2, lat=39.5, lng=-119.5, zone="test");
    state = api_request_ride(
        "Iso Rider", "restaurant experience", "morning", False, "food",
        "Iso Pickup", 39.5001, -119.5001, dest["id"] as str
    );
    cur = state["current"] as dict;
    assert (cur["status"] as str) == "dispatched";
    assert (cur["av_name"] as str) == "AV-TESTDISPATCH";
    assert myav.seats_used == 1;
    assert len(cur["route"] as list) == 3;
    assert "id" in (cur["next_service"] as dict);
}

test "participant with a car is routed as self-transport, no AV consumed" {
    dests = api_destinations();
    dest = dests[0];
    state = api_request_ride(
        "Car Rider", "has a car", "morning", True, "food",
        "Mission Homes", 37.7600, -122.4180, dest["id"] as str
    );
    cur = state["current"] as dict;
    assert (cur["status"] as str) == "self_transport";
    assert (cur["av_name"] as str) == "";
    assert len(cur["route"] as list) == 2;
}

test "fleet state exposes capacity, pickups, and destinations" {
    state = api_fleet_state();
    cap = state["capacity"] as dict;
    assert (cap["total"] as int) > 0;
    assert (cap["free"] as int) <= (cap["total"] as int);
    assert len(state["pickups"] as list) > 0;
    assert len(state["destinations"] as list) > 0;
}
