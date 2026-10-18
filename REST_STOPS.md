# Nearby rest-stop recommendations

The Rest Stops page now keeps category filters at the top and shows mapped places beneath them. Categories are All nearby, Rest areas, Fuel, Cafes, Food and Parking. The user can search within 3, 5 or 10 km, refresh the area, filter the loaded results, and open driving directions for an individual place in Maps.

The app queries OpenStreetMap through the public Overpass service directly from the phone. No extra API key, backend migration or paid Places subscription is configured. The existing http package is used. Backend account tokens and driving history are never sent to this service.

Search centres are rounded to three decimal places before transmission. Distances are calculated from the current location and shown as approximate straight-line distances, not route lengths or travel times. Results are sorted by distance within the requested radius. The first result is labelled nearest in the returned list, not the best or safest place. Access and opening hours need checking in Maps. Ratings, photos, live availability and estimated driving times are not supplied by this integration.

Cards show names (or a clearly generic mapped-place label when a name is absent), category, approximate distance and any mapped address. Twenty-four-hour listings, toilets and wheelchair access appear only when the source explicitly records them. Clearly private, inaccessible and disused places are filtered out; unlabelled restrictions can still be missing from map data.

Requests are bounded by time, response size and result count. In-memory results are cached for ten minutes for up to four area/radius combinations, identical simultaneous requests are coalesced, and a rate-limit response pauses new searches for thirty seconds. Categories filter locally without querying again. Coverage is not exhaustive; dense areas can exceed the response limit, and rural data can be sparse. Production-scale usage would need reviewing against the service's public-instance limits.

Location permission/service failures, empty data, incomplete provider responses, rate limits and network failures have recovery states. Maps category search remains available even when nearby data cannot be loaded. The page explains location sharing and includes OpenStreetMap attribution.

## Verified and still to check

Five service checks verify parsing/facilities/access rules, coordinate handling, sorting/radius/cache, request coalescing, rate-limit cooldown and response failures. Four screen checks cover narrow/wide phones, category filtering without additional requests, empty results and location failure recovery. Rendered examples were inspected internally; example fixtures are only test data and are not production recommendations.

A live request could not be verified from this execution session: the Windows HTTPS check reported an offline certificate-revocation service. TLS verification was not disabled. On the target phone, enable location and internet, open Rest Stops, and check actual places, categories, search distance and opening Maps. No device-network address is displayed in this page.

Official references checked 16 October 2026:
- https://dev.overpass-api.de/overpass-doc/en/preface/commons.html
- https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL
- https://www.openstreetmap.org/copyright
