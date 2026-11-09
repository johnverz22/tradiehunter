using NetTopologySuite.Geometries;

namespace FixoApi.Services;

/// <summary>
/// Geographic helpers for the spatial matching queries.
/// </summary>
/// <remarks>
/// PostGIS <c>ST_Distance</c> on a <c>geometry(Point, 4326)</c> returns
/// <em>degrees</em>, not metres — a value in the single digits for New
/// Zealand. Comparing that against a metre radius makes every filter pass, so
/// distance is never actually applied in SQL. Instead we use EF Core spatial
/// LINQ only for the coarse test (does this point fall inside the search
/// box?) and compute the exact great-circle distance here in C# via
/// NetTopologySuite. No raw PostGIS SQL, so the SQL Server swap path stays open.
/// </remarks>
internal static class Geo
{
    /// <summary>Mean metres per degree of latitude. Accurate to ~0.3% — plenty
    /// for candidate filtering and ranking.</summary>
    private const double MetresPerDegreeLatitude = 111_320.0;

    /// <summary>
    /// Great-circle distance in metres between two WGS84 points (haversine).
    /// </summary>
    public static double HaversineMetres(Point a, Point b)
    {
        const double earthRadiusMetres = 6_371_008.8;

        var lat1 = a.Y * Math.PI / 180.0;
        var lat2 = b.Y * Math.PI / 180.0;
        var dLat = lat2 - lat1;
        var dLon = (b.X - a.X) * Math.PI / 180.0;

        var h = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
              + Math.Cos(lat1) * Math.Cos(lat2)
              * Math.Sin(dLon / 2) * Math.Sin(dLon / 2);

        return 2 * earthRadiusMetres * Math.Asin(Math.Min(1.0, Math.Sqrt(h)));
    }

    /// <summary>
    /// Axis-aligned bounding box (in degrees) that fully contains a circle of
    /// <paramref name="radiusMetres"/> around <paramref name="centre"/>. The
    /// box is deliberately generous — it is a SQL-side prefilter, and the
    /// exact radius test is applied in C# afterwards.
    /// </summary>
    public static Envelope BoundingBox(Point centre, double radiusMetres)
    {
        var latDelta = radiusMetres / MetresPerDegreeLatitude;

        // Longitude degrees shrink towards the poles; clamp the cosine so a
        // job near the poles doesn't produce a divide-by-zero.
        var cosLat = Math.Max(0.01, Math.Cos(centre.Y * Math.PI / 180.0));
        var lonDelta = radiusMetres / (MetresPerDegreeLatitude * cosLat);

        return new Envelope(
            centre.X - lonDelta, centre.X + lonDelta,
            centre.Y - latDelta, centre.Y + latDelta);
    }

    /// <summary>
    /// Wraps <see cref="BoundingBox"/> in an SRID-tagged polygon so it can be
    /// used with EF Core spatial LINQ (<c>Intersects</c>). The SRID must match
    /// the <c>Location</c> column or PostGIS rejects the mixed-SRID operation.
    /// </summary>
    public static Polygon SearchArea(Point centre, double radiusMetres)
    {
        var e = BoundingBox(centre, radiusMetres);
        var factory = new GeometryFactory(new PrecisionModel(), centre.SRID);

        var ring = factory.CreateLinearRing(new[]
        {
            new Coordinate(e.MinX, e.MinY),
            new Coordinate(e.MaxX, e.MinY),
            new Coordinate(e.MaxX, e.MaxY),
            new Coordinate(e.MinX, e.MaxY),
            new Coordinate(e.MinX, e.MinY),
        });

        var polygon = factory.CreatePolygon(ring);
        polygon.SRID = centre.SRID;
        return polygon;
    }
}
