//
//  CommunicationCard.swift
//  Atlas
//
//  Created by Francesco on 13/05/26.
//

import SwiftUI

struct CommunicationCard: View {
    let title: String
    let subtitle: String
    let message: String
    let dateText: Substring
    let unread: Bool
    let accentColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(accentColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text(dateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
            }
        }
        .padding(14)
        .applyLiquidGlassBackground(cornerRadius: 18)
    }
}
