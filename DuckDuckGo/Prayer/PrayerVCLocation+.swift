//
// Copyright 2023 Kahf Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//


import Foundation
import CoreLocation

// MARK: - CLLocationManagerDelegate

extension PrayerVC: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        coordinate = location.coordinate
        fetchTimes(coordinate: location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        //Show location page
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                startUpdatingLocation()
            case .denied, .restricted, .notDetermined:
                return //Show location page
            @unknown default:
                break
            }
    }
    
    func getAddressFromCoordinates(latitude: CLLocationDegrees, longitude: CLLocationDegrees, completion: @escaping (String?) -> Void) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if let error = error {
                print("Reverse geocoding failed with error: \(error.localizedDescription)")
                completion(nil)
            } else if let placemark = placemarks?.first {
                completion(placemark.administrativeArea ?? placemark.locality)
            } else {
                print("No placemarks available.")
                completion(nil)
            }
        }
    }
    
    func checkAndRequestLocationAuthorization() {
        if CLLocationManager.locationServicesEnabled() {
            let authorizationStatus = locationManager.authorizationStatus
            if !(authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways) {
                locationManager.requestWhenInUseAuthorization()
            } else {
                startUpdatingLocation()
            }
        } else {
            print("Location services are not enabled.")
        }
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
}

