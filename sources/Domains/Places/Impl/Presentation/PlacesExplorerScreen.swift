import DesignSystem
import MapKit
import PlacesAPI
import SwiftUI

struct PlacesExplorerScreen: View {
    @State private var viewModel: PlacesExplorerViewModel
    @State private var showsList = false
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: GeoMath.cityCenter.coordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    ))

    init(service: any PlacesService) {
        _viewModel = State(initialValue: PlacesExplorerViewModel(service: service))
    }

    var body: some View {
        VStack(spacing: 0) {
            CategoryChips(selection: $viewModel.category)
            AsyncContentView(state: viewModel.state, retry: viewModel.load) { places in
                if showsList {
                    PlacesList(places: places)
                } else {
                    map(places)
                }
            }
        }
        .navigationTitle("Places")
        .toolbar {
            Button(showsList ? "Map" : "List", systemImage: showsList ? "map" : "list.bullet") {
                showsList.toggle()
            }
        }
        .navigationDestination(for: Place.self) { place in
            PlaceDetailScreen(place: place, service: viewModel.service)
        }
        .task(id: viewModel.category) {
            await viewModel.load()
        }
    }

    private func map(_ places: [NearbyPlace]) -> some View {
        Map(position: $position, selection: $viewModel.selectedPlaceID) {
            UserAnnotation()
            ForEach(places) { nearby in
                Marker(nearby.place.name, systemImage: nearby.place.category.systemImage, coordinate: nearby.place.location.coordinate)
                    .tint(nearby.place.category.tint)
                    .tag(nearby.id)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let selected = viewModel.selectedPlace {
                NavigationLink(value: selected.place) {
                    PlaceCard(nearby: selected)
                }
                .buttonStyle(.plain)
                .padding(Spacing.medium)
            }
        }
    }
}

private struct CategoryChips: View {
    @Binding var selection: PlaceCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.small * 2) {
                chip("All", systemImage: "square.grid.2x2", isSelected: selection == nil) { selection = nil }
                ForEach(PlaceCategory.allCases, id: \.self) { category in
                    chip(category.title, systemImage: category.systemImage, isSelected: selection == category) {
                        selection = selection == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small * 2)
        }
    }

    private func chip(_ title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small * 2)
                .background(isSelected ? Palette.accent : Palette.cardBackground, in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct PlacesList: View {
    let places: [NearbyPlace]

    var body: some View {
        if places.isEmpty {
            EmptyStateView("No places", systemImage: "mappin.slash", message: "Nothing in this category within 5 km.")
        } else {
            List(places) { nearby in
                NavigationLink(value: nearby.place) {
                    PlaceRow(nearby: nearby)
                }
            }
            .listStyle(.plain)
        }
    }
}

struct PlaceRow: View {
    let nearby: NearbyPlace

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Image(systemName: nearby.place.category.systemImage)
                .foregroundStyle(nearby.place.category.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(nearby.place.name)
                Text(nearby.place.address.district)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(nearby.distance.walkingDescription)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

private struct PlaceCard: View {
    let nearby: NearbyPlace

    var body: some View {
        PlaceRow(nearby: nearby)
            .padding(Spacing.medium)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.card))
    }
}

#Preview {
    NavigationStack {
        PlacesExplorerScreen(service: PreviewPlacesService())
    }
}
