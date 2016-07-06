//
//  S2LatLng.swift
//  S2Geometry
//
//  Created by Alex Studnicka on 7/1/16.
//  Copyright © 2016 Alex Studnicka. All rights reserved.
//

#if os(Linux)
	import Glibc
#else
	import Darwin.C
#endif

public struct S2LatLng: Equatable {
	
	/// Approximate "effective" radius of the Earth in meters.
	public static let earthRadiusMeters: Double = 6367000
	
	public let lat: S1Angle
	public let lng: S1Angle
	
	public init(lat: S1Angle = S1Angle(), lng: S1Angle = S1Angle()) {
		self.lat = lat
		self.lng = lng
	}
	
	public init(latRadians: Double, lngRadians: Double) {
		self.lat = S1Angle(radians: latRadians)
		self.lng = S1Angle(radians: lngRadians)
	}
	
	public init(latDegrees: Double, lngDegrees: Double) {
		self.lat = S1Angle(degrees: latDegrees)
		self.lng = S1Angle(degrees: lngDegrees)
	}
	
	/// Convert a point (not necessarily normalized) to an S2LatLng.
	public init(point p: S2Point) {
		// The latitude and longitude are already normalized. We use atan2 to
		// compute the latitude because the input vector is not necessarily unit
		// length, and atan2 is much more accurate than asin near the poles.
		// Note that atan2(0, 0) is defined to be zero.
		self.init(latRadians: atan2(p.z, sqrt(p.x * p.x + p.y * p.y)), lngRadians: atan2(p.y, p.x))
	}
	
	/**
		Return true if the latitude is between -90 and 90 degrees inclusive and the
		longitude is between -180 and 180 degrees inclusive.
	*/
	public var isValid: Bool {
		return abs(lat.radians) <= M_PI_2 && abs(lng.radians) <= M_PI
	}
	
	/**
		Returns a new S2LatLng based on this instance for which `isValid` will be `true`.
		- Latitude is clipped to the range `[-90, 90]`
		- Longitude is normalized to be in the range `[-180, 180]`
		If the current point is valid then the returned point will have the same coordinates.
	*/
	public var normalized: S2LatLng {
		// drem(x, 2 * S2.M_PI) reduces its argument to the range
		// [-S2.M_PI, S2.M_PI] inclusive, which is what we want here.
		return S2LatLng(latRadians: max(-M_PI_2, min(M_PI_2, lat.radians)), lngRadians: remainder(lng.radians, 2 * M_PI))
	}
	
	/// Convert an S2LatLng to the equivalent unit-length vector (S2Point).
	public var point: S2Point {
		let phi = lat.radians
		let theta = lng.radians
		let cosphi = cos(phi)
		return S2Point(x: cos(theta) * cosphi, y: sin(theta) * cosphi, z: sin(phi))
	}
	
	/// Return the distance (measured along the surface of the sphere) to the given point.
	public func getDistance(to o: S2LatLng) -> S1Angle {
		// This implements the Haversine formula, which is numerically stable for
		// small distances but only gets about 8 digits of precision for very large
		// distances (e.g. antipodal points). Note that 8 digits is still accurate
		// to within about 10cm for a sphere the size of the Earth.
		//
		// This could be fixed with another sin() and cos() below, but at that point
		// you might as well just convert both arguments to S2Points and compute the
		// distance that way (which gives about 15 digits of accuracy for all
		// distances).
		
		let lat1 = lat.radians
		let lat2 = o.lat.radians
		let lng1 = lng.radians
		let lng2 = o.lng.radians
		let dlat = sin(0.5 * (lat2 - lat1))
		let dlng = sin(0.5 * (lng2 - lng1))
		let x = dlat * dlat + dlng * dlng * cos(lat1) * cos(lat2)
		return S1Angle(radians: 2 * atan2(sqrt(x), sqrt(max(0.0, 1.0 - x))))
		
		// Return the distance (measured along the surface of the sphere) to the
		// given S2LatLng. This is mathematically equivalent to:
		//
		// S1Angle::FromRadians(ToPoint().Angle(o.ToPoint())
		//
		// but this implementation is slightly more efficient.
	}
	
	/// Returns the surface distance to the given point assuming a constant radius.
	public func getDistance(to o: S2LatLng, radius: Double = S2LatLng.earthRadiusMeters) -> Double {
		// TODO(dbeaumont): Maybe check that radius >= 0 ?
		return getDistance(to: o).radians * radius
	}
	
}

public func ==(lhs: S2LatLng, rhs: S2LatLng) -> Bool {
	return lhs.lat == rhs.lat && lhs.lng == rhs.lng
}

public func +(lhs: S2LatLng, rhs: S2LatLng) -> S2LatLng {
	return S2LatLng(lat: lhs.lat + rhs.lat, lng: lhs.lng + rhs.lng)
}

public func -(lhs: S2LatLng, rhs: S2LatLng) -> S2LatLng {
	return S2LatLng(lat: lhs.lat - rhs.lat, lng: lhs.lng - rhs.lng)
}

public func *(lhs: S2LatLng, m: S1Angle) -> S2LatLng {
	return S2LatLng(lat: lhs.lat * m, lng: lhs.lng * m)
}
