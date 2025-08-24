import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nostrService: NostrService
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName: String = ""
    @State private var about: String = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingImageSourceSelection = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // PhotosPicker for iOS 16+
    @State private var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: RunstrSpacing.lg) {
                    // Header
                    headerSection
                    
                    // Profile Image Section
                    profileImageSection
                    
                    // Form Section
                    formSection
                    
                    // Save Button
                    saveButtonSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, RunstrSpacing.md)
                .padding(.top, RunstrSpacing.md)
            }
            .background(Color.runstrBackground)
            .navigationBarHidden(true)
        }
        .onAppear {
            loadCurrentProfile()
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(selectedImage: $selectedImage)
        }
        .confirmationDialog("Select Image Source", isPresented: $showingImageSourceSelection) {
            Button("Camera") {
                showingCamera = true
            }
            Button("Photo Library") {
                showingImagePicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newPhoto in
            if let newPhoto = newPhoto {
                loadSelectedPhoto(newPhoto)
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.runstrWhite)
            }
            
            Spacer()
            
            Text("Edit Profile")
                .font(.runstrTitle)
                .foregroundColor(.runstrWhite)
            
            Spacer()
            
            // Invisible spacer for centering
            Image(systemName: "xmark")
                .font(.title2)
                .foregroundColor(.clear)
        }
    }
    
    private var profileImageSection: some View {
        VStack(spacing: RunstrSpacing.md) {
            // Profile image display
            Button {
                showingImageSourceSelection = true
            } label: {
                ZStack {
                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.runstrGray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.runstrGray)
                            )
                    }
                    
                    // Edit overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.runstrBackground)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.runstrWhite)
                                )
                                .offset(x: -8, y: -8)
                        }
                    }
                }
            }
            .frame(width: 120, height: 120)
            
            Text("Tap to change photo")
                .font(.runstrCaption)
                .foregroundColor(.runstrGray)
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var formSection: some View {
        VStack(spacing: RunstrSpacing.md) {
            HStack {
                Image(systemName: "person")
                    .foregroundColor(.runstrWhite)
                Text("Profile Information")
                    .font(.runstrSubheadline)
                    .foregroundColor(.runstrWhite)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: RunstrSpacing.md) {
                // Display Name Field
                VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                    Text("Display Name")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    
                    TextField("Enter your name", text: $displayName)
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                        .padding(.horizontal, RunstrSpacing.md)
                        .padding(.vertical, RunstrSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.runstrGray.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.runstrGray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // About Field
                VStack(alignment: .leading, spacing: RunstrSpacing.xs) {
                    Text("About (Optional)")
                        .font(.runstrCaption)
                        .foregroundColor(.runstrGray)
                    
                    TextField("Tell others about yourself", text: $about, axis: .vertical)
                        .font(.runstrBody)
                        .foregroundColor(.runstrWhite)
                        .padding(.horizontal, RunstrSpacing.md)
                        .padding(.vertical, RunstrSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.runstrGray.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.runstrGray.opacity(0.3), lineWidth: 1)
                        )
                        .lineLimit(3...6)
                }
            }
        }
        .padding(RunstrSpacing.lg)
        .runstrCard()
    }
    
    private var saveButtonSection: some View {
        Button {
            saveProfile()
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .runstrBackground))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark")
                        .font(.runstrBody)
                }
                
                Text(isLoading ? "Saving..." : "Save Profile")
                    .font(.runstrBody)
                    .fontWeight(.medium)
            }
            .foregroundColor(.runstrBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, RunstrSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.runstrWhite)
            )
        }
        .disabled(isLoading || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity((isLoading || displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.6 : 1.0)
    }
    
    private func loadCurrentProfile() {
        guard let user = authService.currentUser else { return }
        
        displayName = user.profile.displayName
        about = user.profile.about
        
        // Load existing profile picture if available
        if let profilePictureURL = user.profile.profilePicture,
           let url = URL(string: profilePictureURL) {
            loadImageFromURL(url)
        }
    }
    
    private func loadImageFromURL(_ url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                    }
                }
            } catch {
                print("Failed to load profile image: \(error)")
            }
        }
    }
    
    private func loadSelectedPhoto(_ photo: PhotosPickerItem) {
        Task {
            do {
                if let data = try await photo.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load selected image"
                    showingError = true
                }
            }
        }
    }
    
    private func saveProfile() {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Display name is required"
            showingError = true
            return
        }
        
        isLoading = true
        
        Task {
            // Handle image upload/storage
            var pictureURL: String? = nil
            
            if let selectedImage = selectedImage {
                // For now, we'll store the image locally and use a placeholder URL
                // In a production app, you would upload to an image hosting service
                pictureURL = await storeImageLocally(selectedImage)
            }
            
            // Update local profile
            let success = await authService.updateUserProfile(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                about: about.trimmingCharacters(in: .whitespacesAndNewlines),
                profilePicture: pictureURL
            )
            
            if success {
                // Publish to Nostr if connected
                if nostrService.isConnected {
                    let _ = await nostrService.updateUserProfile(
                        name: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                        about: about.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : about.trimmingCharacters(in: .whitespacesAndNewlines),
                        picture: pictureURL
                    )
                }
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } else {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save profile"
                    showingError = true
                }
            }
        }
    }
    
    private func storeImageLocally(_ image: UIImage) async -> String? {
        // Compress and store image locally
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        
        let filename = "profile_\(UUID().uuidString).jpg"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagePath = documentsPath.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: imagePath)
            return imagePath.absoluteString
        } catch {
            print("Failed to save image locally: \(error)")
            return nil
        }
    }
}

#Preview {
    ProfileEditView()
        .environmentObject(AuthenticationService())
        .environmentObject(NostrService())
}