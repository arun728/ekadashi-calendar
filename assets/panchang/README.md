# Offline location catalog

`cities.json` contains 34,152 entries from GeoNames `cities15000.zip`, retrieved
2026-10-05 from https://download.geonames.org/export/dump/cities15000.zip.
GeoNames provides this data under CC BY 4.0: https://www.geonames.org/about.html.
Attribution: GeoNames geographical database, https://www.geonames.org/.

Each row is `[geonameId, name, asciiName, countryCode, latitude, longitude,
ianaTimezone]`. These are public place coordinates, not user location records.
The complete IANA 2025b database is loaded through timezone 0.10.1, including
zones omitted by that package's smaller default database. All catalog entries
are checked for valid coordinates and a resolvable zone. Future government
changes to timezone rules require a database update.

The original eight cities remain quick picks; arbitrary coordinates/timezones
are also supported. GPS is optional and requests permission only on user action.
No reverse-geocoding/network request is made by the Panchang location picker.
