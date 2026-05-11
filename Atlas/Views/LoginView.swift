//
//  LoginView.swift
//  Atlas
//
//  Created by Francesco on 10/05/26.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var client: ArgoClient

    @State private var schoolCode = ""
    @State private var username   = ""
    @State private var password   = ""
    @State private var isLoading  = false
    @State private var errorMsg:  String?

    @FocusState private var focused: Field?
    enum Field { case school, user, pass }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: 18) {
                        InputField(
                            icon: "building.2.fill",
                            placeholder: "Codice Scuola",
                            text: $schoolCode,
                            focused: _focused,
                            field: .school,
                            nextField: .user
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)

                        InputField(
                            icon: "person.fill",
                            placeholder: "Username",
                            text: $username,
                            focused: _focused,
                            field: .user,
                            nextField: .pass
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        InputField(
                            icon: "lock.fill",
                            placeholder: "Password",
                            text: $password,
                            focused: _focused,
                            field: .pass,
                            isSecure: true
                        )
                        
                        if let err = errorMsg {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 4)
                        }
                        
                        Button {
                            Task { await performLogin() }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(canLogin ? Color(.systemTeal) : Color.gray.opacity(0.35))
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Accedi")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .disabled(!canLogin || isLoading)
                        .animation(.easeInOut(duration: 0.2), value: canLogin)
                    }
                    .padding(24)
                    .applyLiquidGlassBackground(cornerRadius: 24)
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
        .onTapGesture { focused = nil }
    }

    private var canLogin: Bool {
        !schoolCode.trimmingCharacters(in: .whitespaces).isEmpty &&
        !username.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty
    }

    @MainActor
    private func performLogin() async {
        errorMsg = nil
        isLoading = true
        defer { isLoading = false }
        
        client.setCredentials(Credentials(
            schoolCode: schoolCode.trimmingCharacters(in: .whitespaces),
            username: username.trimmingCharacters(in: .whitespaces),
            password: password
        ))

        do {
            try await client.login()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}

struct InputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    @FocusState var focused: LoginView.Field?
    let field: LoginView.Field
    var nextField: LoginView.Field? = nil
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .focused($focused, equals: field)
            .submitLabel(nextField != nil ? .next : .go)
            .onSubmit { if let next = nextField { focused = next } }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .applyLiquidGlassBackground(cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    focused == field ? Color(.systemTeal) : Color.clear,
                    lineWidth: 2
                )
        )
        .animation(.easeInOut(duration: 0.15), value: focused == field)
    }
}
