import Foundation

/// Great-circle initial bearing to the Kaaba, degrees clockwise from true north.
public enum QiblaMath {
    public static let kaabaLatitude = 21.4225
    public static let kaabaLongitude = 39.8262

    public static func bearing(fromLatitude lat: Double, longitude lon: Double) -> Double {
        let phi1 = lat * .pi / 180
        let phi2 = kaabaLatitude * .pi / 180
        let deltaLambda = (kaabaLongitude - lon) * .pi / 180
        let y = sin(deltaLambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda)
        let theta = atan2(y, x) * 180 / .pi
        return (theta + 360).truncatingRemainder(dividingBy: 360)
    }
}
