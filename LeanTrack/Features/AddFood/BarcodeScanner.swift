import SwiftUI
import SwiftData
import VisionKit
import AVFoundation

/// Live barcode scanner: Apple's VisionKit scanner when available, otherwise AVFoundation.
struct BarcodeScannerView: View {
    let onCode: (String) -> Void
    @State private var access = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        Group {
            switch access {
            case .authorized:
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(onCode: onCode)
                } else {
                    AVBarcodeScanner(onCode: onCode)
                }
            case .notDetermined:
                ProgressView().task {
                    _ = await AVCaptureDevice.requestAccess(for: .video)
                    access = AVCaptureDevice.authorizationStatus(for: .video)
                }
            default:
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill").font(.largeTitle).foregroundStyle(Theme.textSecondary)
                    Text("Camera access is off for LeanTrack.").foregroundStyle(Theme.textPrimary)
                    Text("Turn it on in Settings → LeanTrack → Camera, or type the barcode numbers below.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open Settings", destination: url)
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

/// VisionKit DataScannerViewController (iPhone XS and newer).
struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128, .itf14])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var reported = false

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !reported else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue, !value.isEmpty {
                    reported = true
                    onCode(value)
                    return
                }
            }
        }
    }
}

/// AVFoundation fallback scanner.
struct AVBarcodeScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> AVScannerViewController {
        let controller = AVScannerViewController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ controller: AVScannerViewController, context: Context) {}
}

final class AVScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var reported = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        let wanted: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .code128, .itf14]
        output.metadataObjectTypes = wanted.filter { output.availableMetadataObjectTypes.contains($0) }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        preview = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let code = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        Task { @MainActor [weak self] in self?.report(code) }
    }

    private func report(_ code: String) {
        guard !reported else { return }
        reported = true
        onCode?(code)
    }
}

/// Camera (or the photo library on devices without one) for food photos.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage, dismiss: { dismiss() }) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let dismiss: () -> Void

        init(onImage: @escaping (UIImage) -> Void, dismiss: @escaping () -> Void) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            dismiss()
            if let image { onImage(image) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { dismiss() }
    }
}

// MARK: - Barcode lookup flow

/// Scan (or type) a barcode → Open Food Facts → USDA Branded → else create a custom food with the barcode filled in.
struct BarcodeFlowView: View {
    let meal: MealSlot
    let day: Date
    let onLogged: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("openFoodFactsEnabled") private var openFoodFactsEnabled = true
    @Query private var customFoods: [CustomFood]
    @State private var state: LookupState = .scanning
    @State private var manualCode = ""
    @State private var path = NavigationPath()
    @State private var creatingFor: BarcodeValue?

    enum LookupState: Equatable {
        case scanning
        case looking(String)
        case found(String)
        case notFound(String)
        case failed(String, String)
    }

    struct BarcodeValue: Identifiable { let code: String; var id: String { code } }

    init(meal: MealSlot, day: Date, onLogged: @escaping (String) -> Void) {
        self.meal = meal
        self.day = day
        self.onLogged = onLogged
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    switch state {
                    case .scanning:
                        BarcodeScannerView { code in lookUp(code) }
                            .frame(height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                        Text("Point the camera at the barcode on the package.").foregroundStyle(Theme.textSecondary)
                        manualEntry
                    case .looking(let code):
                        ProgressView("Looking up \(code)…").padding(.top, 60)
                    case .found(let code):
                        NoteCard(text: "Found \(code). Scan another, or go back to the food.")
                        Button("Scan Another") { state = .scanning }.buttonStyle(LTSecondaryButtonStyle())
                    case .notFound(let code):
                        notFoundView(code: code, message: "\(code) isn't in \(openFoodFactsEnabled ? "Open Food Facts or " : "")USDA's branded foods yet.")
                    case .failed(let code, let message):
                        notFoundView(code: code, message: message)
                    }
                }
                .padding(Theme.screenPadding)
            }
            .background(Theme.background)
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .navigationDestination(for: FoodPortion.self) { portion in
                FoodDetailView(portion: portion, mode: .log(day: day), meal: meal) { message in
                    if let message { onLogged(message) }
                    dismiss()
                }
            }
        }
        .sheet(item: $creatingFor) { value in
            CustomFoodEditor(food: nil, barcode: value.code) { saved in
                state = .found(value.code)
                path.append(FoodPortion.defaultFor(saved.loggedFood))
            }
        }
    }

    private var manualEntry: some View {
        HStack {
            TextField("Or type the numbers", text: $manualCode)
                .keyboardType(.numberPad)
                .padding(10)
                .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityIdentifier("barcode.manual")
            Button("Look Up") { lookUp(manualCode) }
                .buttonStyle(.borderedProminent)
                .disabled(Barcode.digits(manualCode).count < 8)
        }
    }

    private func notFoundView(code: String, message: String) -> some View {
        VStack(spacing: 14) {
            NoteCard(text: message, warning: true)
            Button("Create Custom Food") { creatingFor = BarcodeValue(code: code) }
                .buttonStyle(LTPrimaryButtonStyle())
            Text("Type in the Nutrition Facts from the package. LeanTrack remembers this barcode, so the next scan finds it instantly.")
                .font(.caption).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            Button("Scan Again") { state = .scanning }.buttonStyle(LTSecondaryButtonStyle())
        }
    }

    private func lookUp(_ raw: String) {
        let code = Barcode.digits(raw)
        guard code.count >= 8, case .scanning = state else { return }
        if let mine = customFoods.first(where: { !$0.barcode.isEmpty && Barcode.same($0.barcode, code) }) {
            state = .found(code)
            path.append(FoodPortion.defaultFor(mine.loggedFood))
            return
        }
        state = .looking(code)
        Task {
            do {
                if let food = try await BrandSearch.lookup(barcode: code, includeOpenFoodFacts: openFoodFactsEnabled) {
                    state = .found(code)
                    path.append(FoodPortion.defaultFor(food))
                } else {
                    state = .notFound(code)
                }
            } catch {
                state = .failed(code, error.localizedDescription)
            }
        }
    }
}
