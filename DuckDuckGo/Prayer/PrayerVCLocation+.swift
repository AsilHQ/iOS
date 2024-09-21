//
//  KahfBrowserOnboardingView.swift
//  DuckDuckGo
//
//  Copyright © 2024 KahfBrowser. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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

