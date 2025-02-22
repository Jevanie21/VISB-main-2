//
//  NavigationView.swift
//  VISB
//
//  Created by violetedwards on 1/30/25.
//import SwiftUI
import SwiftUI
import MapKit
import AVFoundation

struct NavigationView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.92153265231176, longitude: -77.02107302194575),
        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001) // Zoom in more
    )
    @State private var annotations: [IdentifiableAnnotation] = []
    @State private var instructions: String = ""
    @State private var isFetchingData: Bool = false
    @State private var currentStep: Int = 0
    @State private var routeSteps: [[String: Any]] = []
    @State private var isNavigating: Bool = false
    @State private var timer: Timer?
    @State private var selectedDestination: String = "LKD"
    @State private var selectedStartLocation: String = "Mackey"
    @State private var commuteTime: String = ""
    @State private var walkingImage: String = "figure.walk"
    @State private var walkingDirection: String = "arrow.up"
    @State private var currentLocation: CLLocationCoordinate2D?
    @State private var heading: Double = 0
    @State private var isDataLoaded: Bool = false

    struct IdentifiableAnnotation: Identifiable {
        let id = UUID()
        var coordinate: CLLocationCoordinate2D
    }

    let destinations = [
        "LKD",
        "Howard Hospital",
        "Howard Law School",
        "Howard Chapel",
        "Howard Engineering Building"
    ]

    let startLocations = [
        "Mackey",
        "LKD"
    ]

    var body: some View {
        VStack {
            // Map View using UIViewRepresentable
            MapView(region: $region, annotations: annotations, currentLocation: $currentLocation, heading: $heading)
                .ignoresSafeArea()
                .frame(height: 300)

            // Dynamic Arrow and Directions
            if isNavigating {
                VStack {
                    Image(systemName: walkingImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(heading))
                        .padding()

                    Image(systemName: walkingDirection)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.green)
                        .padding()

                    Text(instructions)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding()

                    Text("Estimated Commute Time: \(commuteTime)")
                        .font(.subheadline)
                        .padding()
                }
            } else if isFetchingData {
                ProgressView("Fetching navigation data...")
                    .padding()
            } else if isDataLoaded {
                VStack {
                    Text("Navigation Data Loaded")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()

                    Text("Ready to Go!")
                        .font(.title2)
                        .foregroundColor(.green)
                        .padding()

                    ScrollView {
                        Text(instructions)
                            .font(.body)
                            .padding()
                    }
                    .frame(height: 100)
                }
            }

            // Start Location Picker
            Picker("Select Start Location", selection: $selectedStartLocation) {
                ForEach(startLocations, id: \.self) { location in
                    Text(location).tag(location)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()

            // Destination Picker
            Picker("Select Destination", selection: $selectedDestination) {
                ForEach(destinations, id: \.self) { destination in
                    Text(destination).tag(destination)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()

            // Start Navigation Button
            Button(action: startNavigation) {
                Text(isNavigating ? "Stop Navigation" : "Start Navigation from \(selectedStartLocation) to \(selectedDestination)")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isNavigating ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .padding()
        }
        .onAppear {
            fetchNavigationData()
        }
        .onDisappear {
            stopNavigation()
        }
        .onChange(of: selectedDestination) { oldValue, newValue in
            fetchNavigationData()
        }
        .onChange(of: selectedStartLocation) { oldValue, newValue in
            fetchNavigationData()
        }
    }

    // Fetch navigation data
    private func fetchNavigationData() {
        isFetchingData = true
        NavigationManager.shared.fetchNavigationData(start: selectedStartLocation, destination: selectedDestination) { data in
            if let route = data["route"] as? [[String: Any]] {
                self.routeSteps = route
                self.instructions = NavigationManager.shared.convertToGoogleMapsInstructions(data: data)
            }

            if let waypoints = data["waypoints"] as? [[String: Double]] {
                for waypoint in waypoints {
                    if let latitude = waypoint["latitude"], let longitude = waypoint["longitude"] {
                        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        annotations.append(IdentifiableAnnotation(coordinate: coordinate))
                    }
                }
            }

            if let time = data["commute_time"] as? String {
                self.commuteTime = time
            }

            isFetchingData = false
            isDataLoaded = true
        }
    }

    // Start navigation
    private func startNavigation() {
        if isNavigating {
            stopNavigation()
            return
        }

        isNavigating = true
        currentStep = 0
        AlertManager.shared.notifyUser(message: "Starting navigation from \(selectedStartLocation) to \(selectedDestination).")

        // Start simulating navigation steps
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            if currentStep < routeSteps.count {
                let step = routeSteps[currentStep]
                announceStep(step)
                updateWalkingImageAndDirection(step)
                currentStep += 1
            } else {
                stopNavigation()
                AlertManager.shared.notifyUser(message: "You have reached your destination.")
            }
        }
    }

    // Stop navigation
    private func stopNavigation() {
        timer?.invalidate()
        timer = nil
        isNavigating = false
        AlertManager.shared.notifyUser(message: "Navigation stopped.")
    }

    // Announce step
    private func announceStep(_ step: [String: Any]) {
        if let instruction = step["instruction"] as? String {
            SpeechManager.shared.speak(instruction)
        }
    }

    // Update walking image and direction
    private func updateWalkingImageAndDirection(_ step: [String: Any]) {
        if let action = step["action"] as? String {
            switch action {
            case "start":
                walkingImage = "figure.walk"
                walkingDirection = "arrow.up"
            case "turn_left":
                walkingImage = "figure.walk"
                walkingDirection = "arrow.turn.up.left"
            case "turn_right":
                walkingImage = "figure.walk"
                walkingDirection = "arrow.turn.up.right"
            case "arrive":
                walkingImage = "figure.walk"
                walkingDirection = "arrow.up"
            default:
                walkingImage = "figure.walk"
                walkingDirection = "arrow.up"
            }
        }
    }
}

#Preview {
    NavigationView()
        .environmentObject(AppSettings.shared)
}
