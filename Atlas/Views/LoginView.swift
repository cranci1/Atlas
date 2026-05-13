//
//  LoginView.swift
//  Atlas
//
//  Created by Francesco on 10/05/26.
//

import SwiftUI

private enum LoginField: Hashable {
    case schoolCode, username, password
}

private struct AuthField: View {
    let placeholder: String
    let text: Binding<String>
    var isSecure: Bool = false
    var autocapitalization: TextInputAutocapitalization = .never
    var focusedField: FocusState<LoginField?>.Binding
    let field: LoginField
    let nextField: LoginField?
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(autocapitalization)
            }
        }
        .font(.system(size: 15, weight: .regular))
        .foregroundStyle(.white)
        .autocorrectionDisabled(true)
        .tint(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            focusedField.wrappedValue == field
                            ? Color.white.opacity(0.4)
                            : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.15), value: focusedField.wrappedValue)
        .focused(focusedField, equals: field)
        .submitLabel(nextField == nil ? .go : .next)
        .onSubmit {
            if let next = nextField { focusedField.wrappedValue = next }
        }
    }
}

struct LoginView: View {
    @EnvironmentObject var client: ArgoClient
    
    @State private var schoolCode = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMsg: String?
    
    @FocusState private var focusedField: LoginField?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()
                
                Circle()
                    .fill(Color.teal.opacity(0.18))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: -80, y: -180)
                    .allowsHitTesting(false)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 72)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.teal)
                                .padding(.bottom, 20)
                            
                            Text("Bentornato.")
                                .font(.system(size: 34, weight: .bold, design: .default))
                                .foregroundStyle(.white)
                            
                            Text("Accedi al tuo account Argo")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.white.opacity(0.45))
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 40)
                        
                        VStack(spacing: 10) {
                            AuthField(
                                placeholder: "Codice Scuola",
                                text: $schoolCode,
                                autocapitalization: .characters,
                                focusedField: $focusedField,
                                field: .schoolCode,
                                nextField: .username
                            )
                            
                            AuthField(
                                placeholder: "Username",
                                text: $username,
                                focusedField: $focusedField,
                                field: .username,
                                nextField: .password
                            )
                            
                            AuthField(
                                placeholder: "Password",
                                text: $password,
                                isSecure: true,
                                focusedField: $focusedField,
                                field: .password,
                                nextField: nil
                            )
                            .onSubmit {
                                if canLogin { Task { await performLogin() } }
                            }
                            
                            if let err = errorMsg {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.footnote)
                                    Text(err)
                                        .font(.footnote)
                                }
                                .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 28)
                        .animation(.easeInOut(duration: 0.2), value: errorMsg)
                        
                        Button {
                            focusedField = nil
                            Task { await performLogin() }
                        } label: {
                            ZStack {
                                Text("Accedi")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.07, green: 0.07, blue: 0.09))
                                    .opacity(isLoading ? 0 : 1)
                                
                                if isLoading {
                                    ProgressView()
                                        .tint(Color(red: 0.07, green: 0.07, blue: 0.09))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                canLogin
                                ? Color.white
                                : Color.white.opacity(0.25)
                            )
                            .cornerRadius(12)
                        }
                        .disabled(!canLogin || isLoading)
                        .padding(.horizontal, 28)
                        .padding(.top, 24)
                        .animation(.easeInOut(duration: 0.15), value: canLogin)
                        
                        Spacer().frame(height: 48)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                Text("Le credenziali vengono usate solo per l'autenticazione ad Argo.\nAtlas non è affiliato con Argo Software Srl.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
            }
        }
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
        
        client.credentials = Credentials(
            schoolCode: schoolCode.trimmingCharacters(in: .whitespaces),
            username: username.trimmingCharacters(in: .whitespaces),
            password: password
        )
        
        do {
            try await client.login()
        } catch {
            errorMsg = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
